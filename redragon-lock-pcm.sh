#!/bin/bash
#
# Redragon/XiiSound wireless headset - force hardware PCM volume to 100%.
# The dongle mutes one channel below 100%; the real volume is handled by the
# PipeWire soft-mixer (see wireplumber/99-redragon-headset-fix.conf).
#
# Runs from:
#   - restore-headset.service (systemd user, with --retry): exits 1 so
#     systemd retries until the card is ready (boot race)
#   - manually: idempotent, safe to run any time
#
# Adapted from the MIT-licensed github.com/cleisonsantos/havit-fuxi-h3-linux-fix

export PATH=/usr/sbin:/usr/bin:/sbin:/bin

sleep 2

CARD=$(grep -iE 'H878|H848|H510|Fuxi|XiiSound|Weltrend|Redragon|Wireless headset|2\.4G' /proc/asound/cards 2>/dev/null | head -1 | awk '{print $1}')
if [ -z "$CARD" ]; then
    echo "No Redragon/XiiSound headset card found"
    [ "${1:-}" = "--retry" ] && exit 1
    exit 0
fi

# PCM,0: stereo volume (Front Left/Right)
amixer -c "$CARD" sset 'PCM',0 100%,100% > /dev/null 2>&1
# PCM,1: mute switch on some firmwares, volume on others - cover both
amixer -c "$CARD" sset 'PCM',1 100% > /dev/null 2>&1
amixer -c "$CARD" sset 'PCM',1 on > /dev/null 2>&1

exit 0
