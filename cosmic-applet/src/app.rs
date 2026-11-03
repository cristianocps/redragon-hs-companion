// SPDX-License-Identifier: MIT

//! COSMIC panel applet for Redragon headset volume control.
//!
//! Talks directly to the control daemon's Unix socket
//! (`$XDG_RUNTIME_DIR/redragon-control.sock`), using the same text protocol
//! as the `redragon-volume` CLI and the other desktop widgets:
//!
//! * `status` -> `OK: device=NAME card=N pcm0=N pcm1=N analog=BOOL`
//! * `get`    -> `OK: N`
//! * `set N`  -> `OK: N`
//! * `mute`   -> `OK: muted` / `OK: unmuted N`
//!
//! Muted state is derived from the effective volume being 0, exactly like the
//! GNOME/Cinnamon/Plasma widgets do.

use std::io::{Read, Write};
use std::os::unix::net::UnixStream;
use std::process::Command;
use std::sync::atomic::{AtomicU32, Ordering};
use std::sync::Arc;
use std::time::{Duration, Instant};

use cosmic::applet::{menu_button, padded_control};
use cosmic::cosmic_theme::Spacing;
use cosmic::iced::platform_specific::shell::wayland::commands::popup::{
    destroy_popup, get_popup,
};
use cosmic::iced::widget::{mouse_area, slider};
use cosmic::iced::{window::Id, Alignment, Length, Limits, Subscription};
use cosmic::widget::{button, container, divider, icon, text, Column, Row};
use cosmic::{app, theme, Application, Element, Task};

use crate::i18n;

/// How often the daemon is polled for device/volume changes.
const POLL_INTERVAL: Duration = Duration::from_secs(3);
/// Delay applied before sending slider changes to the daemon (debounce).
const SLIDER_DEBOUNCE: Duration = Duration::from_millis(60);
/// Minimum interval between applied scroll wheel volume changes.
const SCROLL_THROTTLE_MS: u128 = 150;
/// Timeout for reads/writes on the daemon socket.
const SOCKET_TIMEOUT: Duration = Duration::from_secs(2);
/// Sentinel for "no pending slider value" in `AppModel::pending_volume`.
const NO_PENDING: u32 = u32::MAX;

/// The application model stores app-specific state used to describe its
/// interface and drive its logic.
pub struct AppModel {
    /// Application state which is managed by the COSMIC runtime.
    core: app::Core,
    /// The popup id.
    popup: Option<Id>,
    /// Localized strings for the current locale.
    tr: &'static i18n::Strings,
    /// Detected headset name (None = headset not detected).
    device: Option<String>,
    /// Last known effective volume (0..=100). Zero means muted.
    volume: u32,
    /// True when the daemon socket is unreachable.
    daemon_down: bool,
    /// Cached PipeWire sink name for "use as default output".
    sink_name: Option<String>,
    /// Latest slider value not yet sent to the daemon (debounce).
    pending_volume: Arc<AtomicU32>,
    /// Last time a scroll wheel change was applied (throttle).
    last_scroll: Instant,
}

/// Messages emitted by the application and its widgets.
#[derive(Debug, Clone)]
pub enum Message {
    /// No-op (e.g. horizontal wheel motion).
    Ignore,
    /// Periodic poll requested by the timer subscription.
    Tick,
    TogglePopup,
    PopupClosed(Id),
    /// Slider moved; debounced before hitting the daemon.
    SetVolume(u32),
    /// Scroll wheel requested an absolute volume change.
    ScrollVolume(u32),
    ToggleMute,
    UseAsOutput,
}

/// Create a COSMIC application from the app model.
impl Application for AppModel {
    /// The async executor that will be used to run the application's tasks.
    type Executor = cosmic::SingleThreadExecutor;

    /// Data that the application receives to its init method.
    type Flags = ();

    /// Messages which the application and its widgets will emit.
    type Message = Message;

    /// Unique identifier in RDNN (reverse domain name notation) format.
    const APP_ID: &'static str = "com.github.cristianocps.RedragonVolume";

    fn core(&self) -> &app::Core {
        &self.core
    }

    fn core_mut(&mut self) -> &mut app::Core {
        &mut self.core
    }

    /// Initializes the application with any given flags and startup tasks.
    fn init(core: app::Core, _flags: Self::Flags) -> (Self, app::Task<Message>) {
        let app = AppModel {
            core,
            popup: None,
            tr: i18n::strings(),
            device: None,
            volume: 0,
            daemon_down: false,
            sink_name: None,
            pending_volume: Arc::new(AtomicU32::new(NO_PENDING)),
            last_scroll: Instant::now(),
        };

        // Refresh immediately on startup instead of waiting for the first
        // timer interval.
        (app, cosmic::task::message(Message::Tick))
    }

    fn on_close_requested(&self, id: Id) -> Option<Message> {
        Some(Message::PopupClosed(id))
    }

    /// The applet's button in the panel is drawn using this view method.
    fn view(&self) -> Element<'_, Message> {
        let btn = self
            .core
            .applet
            .icon_button(self.panel_icon())
            .on_press(Message::TogglePopup);

        const WHEEL_STEP: f32 = 5.0; // 5% per wheel event
        mouse_area(btn)
            .on_middle_press(Message::ToggleMute)
            .on_right_press(Message::ToggleMute)
            .on_scroll(move |delta| {
                let step = match delta {
                    cosmic::iced::mouse::ScrollDelta::Lines { y, .. } => y.signum() * WHEEL_STEP,
                    cosmic::iced::mouse::ScrollDelta::Pixels { y, .. } => y.signum() * WHEEL_STEP,
                };

                if !step.is_normal() {
                    return Message::Ignore;
                }

                let volume = (self.volume as f32 + step).clamp(0.0, 100.0) as u32;
                Message::ScrollVolume(volume)
            })
            .into()
    }

    /// The applet's popup window is drawn using this view method.
    fn view_window(&self, _id: Id) -> Element<'_, Message> {
        let Spacing {
            space_xxs, space_s, ..
        } = theme::active().cosmic().spacing;

        let status = if self.daemon_down {
            format!("❌ {}", self.tr.daemon_not_running)
        } else if let Some(device) = &self.device {
            format!("✓ {device}")
        } else {
            format!("❌ {}", self.tr.not_found)
        };

        let volume_row = Row::with_capacity(3)
            .push(
                button::icon(icon::from_name(self.panel_icon()).size(24).symbolic(true))
                    .class(cosmic::theme::Button::Icon)
                    .icon_size(24)
                    .line_height(24)
                    .on_press(Message::ToggleMute),
            )
            .push(slider(0..=100, self.volume, Message::SetVolume).width(Length::FillPortion(5)))
            .push(
                container(text::body(format!("{}%", self.volume)).size(16))
                    .width(Length::FillPortion(1))
                    .align_x(Alignment::End),
            )
            .spacing(12)
            .align_y(Alignment::Center);

        let mut content = Column::with_capacity(4)
            .push(padded_control(text::body(status)))
            .push(padded_control(volume_row))
            .push(padded_control(divider::horizontal::default()).padding([space_xxs, space_s]));

        if self.device.is_some() {
            content = content
                .push(menu_button(text::body(self.tr.use_as_output)).on_press(Message::UseAsOutput));
        }

        let content = content.align_x(Alignment::Start).padding([8, 0]);

        self.core.applet.popup_container(container(content)).into()
    }

    /// Register the timer subscription that polls the daemon.
    fn subscription(&self) -> Subscription<Message> {
        cosmic::iced::time::every(POLL_INTERVAL).map(|_| Message::Tick)
    }

    /// Handles messages emitted by the application and its widgets.
    fn update(&mut self, message: Message) -> app::Task<Message> {
        match message {
            Message::Ignore => {}
            Message::Tick => self.refresh(),
            Message::TogglePopup => {
                return if let Some(p) = self.popup.take() {
                    destroy_popup(p)
                } else {
                    let new_id = Id::unique();
                    self.popup.replace(new_id);
                    let mut popup_settings = self.core.applet.get_popup_settings(
                        self.core.main_window_id().unwrap(),
                        new_id,
                        None,
                        None,
                        None,
                    );
                    popup_settings.positioner.size_limits = Limits::NONE
                        .max_width(372.0)
                        .min_width(300.0)
                        .min_height(200.0)
                        .max_height(1080.0);
                    get_popup(popup_settings)
                };
            }
            Message::PopupClosed(id) => {
                if self.popup.as_ref() == Some(&id) {
                    self.popup = None;
                }
            }
            Message::SetVolume(volume) => {
                self.volume = volume;
                self.pending_volume.store(volume, Ordering::Relaxed);
                let pending = Arc::clone(&self.pending_volume);
                return Task::future(async move {
                    tokio::time::sleep(SLIDER_DEBOUNCE).await;
                    let volume = pending.swap(NO_PENDING, Ordering::Relaxed);
                    if volume != NO_PENDING {
                        let _ = send_command(&format!("set {volume}"));
                    }
                    cosmic::Action::App(Message::Ignore)
                });
            }
            Message::ScrollVolume(volume) => {
                let now = Instant::now();
                if now.duration_since(self.last_scroll).as_millis() < SCROLL_THROTTLE_MS
                    || self.volume == volume
                {
                    return Task::none();
                }

                self.last_scroll = now;
                if self.device.is_some() {
                    self.volume = volume;
                    let _ = send_command(&format!("set {volume}"));
                }
            }
            Message::ToggleMute => {
                if self.device.is_some() {
                    if let Ok(reply) = send_command("mute") {
                        // Reply: `OK: muted` or `OK: unmuted N`.
                        if let Some(rest) = reply.strip_prefix("OK: unmuted") {
                            if let Ok(volume) = rest.trim().parse::<u32>() {
                                self.volume = volume;
                            }
                        } else if reply.starts_with("OK: muted") {
                            self.volume = 0;
                        }
                    }
                }
            }
            Message::UseAsOutput => {
                if let Some(device) = self.device.clone() {
                    if self.sink_name.is_none() {
                        self.sink_name = find_sink();
                    }
                    if let Some(sink) = self.sink_name.clone() {
                        let ok = Command::new("pactl")
                            .arg("set-default-sink")
                            .arg(&sink)
                            .status()
                            .map(|status| status.success())
                            .unwrap_or(false);
                        if ok {
                            let message = self.tr.set_as_default.replace("%s", &device);
                            let _ = Command::new("notify-send")
                                .arg("Redragon Volume")
                                .arg(message)
                                .arg("-i")
                                .arg("audio-headphones")
                                .status();
                        }
                    }
                }
            }
        }
        Task::none()
    }

    fn style(&self) -> Option<cosmic::iced::theme::Style> {
        Some(cosmic::applet::style())
    }
}

impl AppModel {
    /// Panel/popup icon for the current volume (zero volume = muted).
    fn panel_icon(&self) -> &'static str {
        if self.daemon_down || self.device.is_none() || self.volume == 0 {
            "audio-volume-muted-symbolic"
        } else if self.volume < 33 {
            "audio-volume-low-symbolic"
        } else if self.volume < 66 {
            "audio-volume-medium-symbolic"
        } else {
            "audio-volume-high-symbolic"
        }
    }

    /// Polls the daemon for the current device and volume. Socket calls are
    /// blocking but local and fast; timeouts only trigger when the daemon is
    /// unresponsive.
    fn refresh(&mut self) {
        match send_command("status") {
            Ok(reply) => match parse_status(&reply) {
                Some(device) => {
                    self.daemon_down = false;
                    if self.device.as_deref() != Some(device.as_str()) {
                        // Device changed or was just detected: sink may differ.
                        self.sink_name = None;
                    }
                    self.device = Some(device);
                    if self.sink_name.is_none() {
                        self.sink_name = find_sink();
                    }
                    if let Ok(get_reply) = send_command("get") {
                        if let Some(volume) = parse_ok_value(&get_reply) {
                            // Do not fight the user while the slider is being
                            // dragged (a debounced write is still in flight).
                            if self.pending_volume.load(Ordering::Relaxed) == NO_PENDING {
                                self.volume = volume;
                            }
                        }
                    }
                }
                None => {
                    self.daemon_down = false;
                    self.device = None;
                    self.sink_name = None;
                }
            },
            Err(_) => {
                self.daemon_down = true;
                self.device = None;
                self.sink_name = None;
            }
        }
    }
}

/// Sends a command to the control daemon and returns its reply.
///
/// Framing matches the `redragon-volume` client: the command is written
/// without a newline, the write side is shut down, and the reply is read
/// until EOF (the daemon closes the connection after responding).
fn send_command(command: &str) -> std::io::Result<String> {
    let runtime_dir = std::env::var_os("XDG_RUNTIME_DIR")
        .map(std::path::PathBuf::from)
        .unwrap_or_else(|| std::path::PathBuf::from("/tmp"));
    let mut stream = UnixStream::connect(runtime_dir.join("redragon-control.sock"))?;
    stream.set_read_timeout(Some(SOCKET_TIMEOUT))?;
    stream.set_write_timeout(Some(SOCKET_TIMEOUT))?;
    stream.write_all(command.as_bytes())?;
    let _ = stream.shutdown(std::net::Shutdown::Write);
    let mut reply = String::new();
    stream.read_to_string(&mut reply)?;
    Ok(reply.trim().to_string())
}

/// Parses `OK: device=NAME card=N ...` into the device name.
fn parse_status(reply: &str) -> Option<String> {
    let body = reply.strip_prefix("OK: ")?;
    let start = body.find("device=")? + "device=".len();
    let rest = &body[start..];
    let end = rest.find(" card=")?;
    let device = rest[..end].trim();
    if device.is_empty() {
        None
    } else {
        Some(device.to_string())
    }
}

/// Parses `OK: N` into a volume percentage.
fn parse_ok_value(reply: &str) -> Option<u32> {
    reply.strip_prefix("OK: ")?.trim().parse().ok()
}

/// Finds the PipeWire sink name of the headset by scanning `pactl` output for
/// the known vendor/product strings (same heuristic as the other widgets).
fn find_sink() -> Option<String> {
    let output = Command::new("pactl")
        .args(["list", "sinks", "short"])
        .output()
        .ok()?;
    if !output.status.success() {
        return None;
    }
    let stdout = String::from_utf8_lossy(&output.stdout);
    for line in stdout.lines() {
        if line.contains("XiiSound")
            || line.contains("Weltrend")
            || line.contains("Redragon")
            || line.contains("H878")
        {
            // Format: ID  NAME  MODULE  ...
            if let Some(name) = line.split_whitespace().nth(1) {
                return Some(name.to_string());
            }
        }
    }
    None
}
