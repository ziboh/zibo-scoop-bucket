# WezTerm ConPTY Scoop Bucket

This local Scoop bucket installs the current WezTerm nightly build and then replaces
its bundled Windows ConPTY runtime with the matched Microsoft ConPTY 1.24.260402001
pair. This avoids the known OpenCode exit crash caused by WezTerm's older bundled
ConPTY files.

## Contents

- `bucket/wezterm-nightly.json`: Scoop manifest with the post-install hook.
- `scripts/install-conpty.ps1`: Downloads, verifies, and installs the Microsoft-signed
  `OpenConsole.exe` and `conpty.dll` files.

## Updating

Run `scoop update wezterm-nightly`. For an additional build published on the same day,
run `scoop update wezterm-nightly --force`.
