# Zibo Scoop Bucket

This is a local, Git-managed Scoop bucket for custom package manifests and install
hooks. It can contain more than one package.

## Contents

- `bucket/wezterm-nightly.json`: WezTerm nightly manifest with the post-install hook.
- `scripts/install-conpty.ps1`: Downloads, verifies, and installs the Microsoft-signed
  `OpenConsole.exe` and `conpty.dll` files.

## Updating

Run `scoop update wezterm-nightly`. For an additional build published on the same day,
run `scoop update wezterm-nightly --force`.
