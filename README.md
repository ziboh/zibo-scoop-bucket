# Zibo Scoop Bucket

This is a local, Git-managed Scoop bucket for custom package manifests and install
hooks. It can contain more than one package.

## Contents

- `bucket/wezterm-nightly.json`: WezTerm nightly manifest with the post-install hook.
- `bucket/markflowy.json`: MarkFlowy (Tauri portable build) manifest. Settings live
  outside the Scoop app directory, so `scoop update markflowy` keeps them. The optional
  file associations are opt-in: run
  `powershell -ExecutionPolicy Bypass -File "$dir\markflowy-file-assoc.ps1"` after install
  (it prints an undo hint; `-Uninstall` restores the previous associations).
- `scripts/install-conpty.ps1`: Downloads, verifies, and installs the Microsoft-signed
  `OpenConsole.exe` and `conpty.dll` files.
- `scripts/markflowy-file-assoc.ps1`: Registers MarkFlowy as the per-user handler for
  `.md`, `.markdown`, `.json`, and `.txt`. Backs up every value it overwrites and only
  touches the current user's registry hive.

## Updating

Run `scoop update wezterm-nightly`. For an additional build published on the same day,
run `scoop update wezterm-nightly --force`.

Run `scoop update markflowy` to pick up new upstream releases.
