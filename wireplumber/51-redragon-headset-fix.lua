-- Redragon/XiiSound wireless headset fix (USB dongle family, Weltrend chipset)
-- Forces PipeWire software mixer, locks hardware volume at 100% and hides the
-- phantom digital interface. Fixes channel imbalance/mute-below-100% bug.
--
-- Covers the 040b:0897 rebrand family (Redragon H878, H848, H510-PRO Wireless,
-- Havit Fuxi-H3, etc.) plus name-based fallbacks for related dongles.
--
-- Lua format for WirePlumber 0.4 (main.lua.d). WirePlumber 0.5+ uses the
-- equivalent 99-redragon-headset-fix.conf fragment instead; both can be
-- installed side by side, each version ignores the other's format.
--
-- Based on findings from issue #6 and the MIT-licensed reference
-- github.com/cleisonsantos/havit-fuxi-h3-linux-fix

alsa_monitor.rules = {
  {
    matches = {
      {
        { "device.name", "matches", "alsa_card.usb-*XiiSound*" },
      },
      {
        { "device.name", "matches", "alsa_card.usb-*Weltrend*" },
      },
      {
        { "device.name", "matches", "alsa_card.usb-*H878*" },
      },
      {
        { "device.name", "matches", "alsa_card.usb-*H848*" },
      },
      {
        { "device.name", "matches", "alsa_card.usb-*H510*" },
      },
      {
        { "device.name", "matches", "alsa_card.usb-*Fuxi*" },
      },
      {
        { "device.name", "matches", "alsa_card.usb-*Redragon*" },
      },
      {
        { "device.name", "matches", "alsa_card.usb-*Wireless*headset*" },
      },
    },
    apply_properties = {
      ["api.alsa.soft-mixer"] = true,
      ["api.alsa.ignore-dB"] = true,
      ["api.alsa.disable-longname"] = true,
    },
  },
  {
    matches = {
      {
        { "node.name", "matches", "alsa_output.usb-*XiiSound*" },
      },
      {
        { "node.name", "matches", "alsa_output.usb-*Weltrend*" },
      },
      {
        { "node.name", "matches", "alsa_output.usb-*H878*" },
      },
      {
        { "node.name", "matches", "alsa_output.usb-*H848*" },
      },
      {
        { "node.name", "matches", "alsa_output.usb-*H510*" },
      },
      {
        { "node.name", "matches", "alsa_output.usb-*Fuxi*" },
      },
      {
        { "node.name", "matches", "alsa_output.usb-*Redragon*" },
      },
      {
        { "node.name", "matches", "alsa_output.usb-*Wireless*headset*" },
      },
    },
    apply_properties = {
      ["api.alsa.soft-mixer"] = true,
      ["api.alsa.ignore-dB"] = true,
      ["api.alsa.enable-hw-volume"] = false,
    },
  },
}