#!/bin/bash
#
# k9-say - Make a Linux box speak like Doctor Who's K9
#
# Usage:
#   k9-say "Affirmative, master"
#   k9-say -p alarm "Danger! Danger!"
#   k9-say -p alert "Scanning for hostiles"
#   k9-say -p calm "Correct, mistress"
#
# Requires: espeak-ng, sox (with play support), aplay (or use sox 'play' directly)
#   sudo apt install espeak-ng sox alsa-utils

set -e

PRESET="normal"

# --- Parse -p/--preset flag ---
if [[ "$1" == "-p" || "$1" == "--preset" ]]; then
    PRESET="$2"
    shift 2
fi

TEXT="$*"

if [[ -z "$TEXT" ]]; then
    echo "Usage: k9-say [-p normal|calm|alert|alarm] \"text to speak\""
    exit 1
fi

# --- Preset definitions ---
# SPEED = words per minute, PITCH = espeak pitch (0-99), AMP = amplitude
# OVERDRIVE = grit amount, TREMOLO_F/TREMOLO_D = buzz frequency/depth, PSHIFT = sox pitch shift (cents)
case "$PRESET" in
    calm)
        SPEED=150; PITCH=15; AMP=180
        OVERDRIVE=5; TREMOLO_F=25; TREMOLO_D=12; PSHIFT=-60
        ;;
    alert)
        SPEED=185; PITCH=22; AMP=210
        OVERDRIVE=10; TREMOLO_F=45; TREMOLO_D=22; PSHIFT=-70
        ;;
    alarm)
        SPEED=210; PITCH=30; AMP=230
        OVERDRIVE=16; TREMOLO_F=60; TREMOLO_D=35; PSHIFT=-40
        ;;
    normal|*)
        SPEED=175; PITCH=18; AMP=200
        OVERDRIVE=8; TREMOLO_F=35; TREMOLO_D=15; PSHIFT=-80
        ;;
esac

espeak-ng -s "$SPEED" -p "$PITCH" -a "$AMP" --stdout "$TEXT" | \
sox -t wav - -t wav - \
    overdrive "$OVERDRIVE" \
    tremolo "$TREMOLO_F" "$TREMOLO_D" \
    pitch "$PSHIFT" \
    2>/dev/null | \
aplay -q 2>/dev/null
