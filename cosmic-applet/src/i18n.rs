// SPDX-License-Identifier: MIT

//! Simple runtime translations, mirroring the strings used by the GNOME
//! extension, Cinnamon applet and Plasma widget (English, Portuguese,
//! Spanish). Language is resolved once from `LANGUAGE`/`LANG` at startup.

pub struct Strings {
    pub not_found: &'static str,
    pub daemon_not_running: &'static str,
    pub use_as_output: &'static str,
    /// Contains a `%s` placeholder replaced by the device name.
    pub set_as_default: &'static str,
}

const EN: Strings = Strings {
    not_found: "Not found",
    daemon_not_running: "Daemon not running",
    use_as_output: "Use as audio output",
    set_as_default: "%s set as default output",
};

const PT: Strings = Strings {
    not_found: "Não encontrado",
    daemon_not_running: "Daemon não está em execução",
    use_as_output: "Usar como saída de áudio",
    set_as_default: "%s definido como saída padrão",
};

const ES: Strings = Strings {
    not_found: "No encontrado",
    daemon_not_running: "El demonio no está en ejecución",
    use_as_output: "Usar como salida de audio",
    set_as_default: "%s establecido como salida predeterminada",
};

/// Returns the string table for the current locale (fallback: English).
pub fn strings() -> &'static Strings {
    // LANGUAGE (gettext, may be a colon-separated list) takes precedence.
    let lang = std::env::var("LANGUAGE")
        .ok()
        .filter(|value| !value.is_empty())
        .or_else(|| std::env::var("LANG").ok())
        .unwrap_or_default();

    let code = lang
        .split([':', '_', '.'])
        .next()
        .unwrap_or_default()
        .to_lowercase();

    match code.as_str() {
        "pt" => &PT,
        "es" => &ES,
        _ => &EN,
    }
}
