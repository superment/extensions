# FineTune Raycast Extension

Control [FineTune](https://github.com/ronitsingh10/FineTune) (per-app volume on macOS) from Raycast.

Requires the FineTune app to be installed (e.g. `brew install --cask finetune`).

## Commands

- **Output Devices** — List apps and output devices; set volume, mute, reset, and route apps to devices.
- **Reset All to 100%** — Reset all apps to 100% volume and unmute (no view).

## App list: Core Audio (same as FineTune)

The extension prefers the **Core Audio** process list so you only see apps that have active audio (like FineTune’s UI). That uses a small Swift CLI in `scripts/finetune-audio-apps.swift`.
