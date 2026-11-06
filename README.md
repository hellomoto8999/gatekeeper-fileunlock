# Gatekeeper File Unlock

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![Platform: macOS](https://img.shields.io/badge/platform-macOS%2011%2B-lightgrey.svg)

A small, dependency-free macOS utility that adds **Unlock app (Gatekeeper)** to the Finder right-click menu.

It removes the `com.apple.quarantine` extended attribute from apps, disk images and other files downloaded from the internet, so macOS stops refusing to open them with messages such as:

> “Some App” cannot be opened because the developer cannot be verified.
>
> “Some App” is damaged and can't be opened. You should move it to the Trash.

<p align="center">
  <em>Finder → right-click → Quick Actions → Unlock app (Gatekeeper)</em>
</p>

## Features

- Adds a native item to the Finder context menu (Quick Actions / Services).
- Works on apps, `.dmg`, `.pkg`, archives and any other file or folder.
- Handles multiple selected items at once.
- Can also run from the Terminal, from a pipe, or with a file picker.
- Removes quarantine recursively, including inside app bundles.
- Verifies the code signature afterwards and applies an ad-hoc signature only if it is broken.
- Asks for an administrator password only when the file is outside your home folder.
- Logs every operation to `~/Library/Logs/GatekeeperFileUnlock.log`.
- No dependencies beyond the tools bundled with macOS. Intel and Apple Silicon.

## Requirements

- macOS 11 Big Sur or later (tested on macOS 26/27).
- Bash, `xattr`, `codesign` and `osascript` — all included with macOS.
- No `sudo` needed for a normal installation.

## Installation

```bash
git clone https://github.com/hellomoto8999/gatekeeper-fileunlock.git
cd gatekeeper-fileunlock
./install-finder-service.sh
```

If you prefer not to use Git, download the repository as a ZIP from GitHub, unzip it, open Terminal in the extracted folder and run:

```bash
./install-finder-service.sh
```

The installer:

1. copies `unlock-gatekeeper.sh` to `~/Library/Application Support/GatekeeperFileUnlock/`;
2. creates the Quick Action in `~/Library/Services/Unlock app.workflow`;
3. asks macOS to reload the Services menu.

No files outside your home folder are touched.

### Enabling the menu item

On recent macOS versions, open:

**System Settings → General → Login Items & Extensions → Finder**

and make sure **Unlock app** is enabled. If the item does not show up, restart Finder:

```bash
killall Finder
```

## Usage

### Finder

1. Right-click an app or file (or select several items).
2. Choose **Quick Actions → Unlock app (Gatekeeper)**.
   On older macOS versions the submenu is called **Services**.
3. If the file needs administrator rights, macOS asks for your password.
4. The quarantine is removed and, when the selection is an app, it is opened.

### Keyboard shortcut

You can assign one in:

**System Settings → Keyboard → Keyboard Shortcuts → Services → General → Unlock app (Gatekeeper)**

### Terminal

```bash
# Unlock one or more items
./unlock-gatekeeper.sh "/Applications/Some App.app"
./unlock-gatekeeper.sh ~/Downloads/App.dmg ~/Downloads/Tool.pkg

# Open a file picker
./unlock-gatekeeper.sh

# Read paths from stdin
printf '%s\n' "/Applications/Some App.app" | ./unlock-gatekeeper.sh

# Unlock without opening the app
./unlock-gatekeeper.sh --no-open "/Applications/Some App.app"
```

### Double-click

After running the installer, you can also double-click **Unlock App.command**. It opens a file picker and unlocks what you select, without using the context menu.

> If macOS blocks the `.command` file itself, right-click it and choose **Open**, or run the scripts from Terminal.

## Options

| Option | Description |
| --- | --- |
| `-n`, `--no-open` | Do not open the app after unlocking it. |
| `-q`, `--quiet` | Do not show notifications or alerts; only write to the log. |
| `-h`, `--help` | Show the help. |
| `-V`, `--version` | Show the version. |

Equivalent environment variables:

| Variable | Description |
| --- | --- |
| `UNLOCK_OPEN=0` | Same as `--no-open`. |
| `UNLOCK_QUIET=1` | Same as `--quiet`. |

## What it does

1. Removes `com.apple.quarantine` recursively with `xattr -dr`.
2. If some attributes remain because of permissions, retries with administrator rights.
3. Checks the code signature of `.app` bundles and, only if it is invalid, re-signs the bundle ad-hoc so it can launch.
4. Opens the app, unless `--no-open` is used.
5. Writes the result to `~/Library/Logs/GatekeeperFileUnlock.log`.

## Troubleshooting

**The menu item is missing**
Open **System Settings → General → Login Items & Extensions → Finder** and enable **Unlock app**, then run `killall Finder`. The item appears under **Quick Actions** (or **Services** on older systems).

**It asks for a password**
The item is in a location you cannot write to, such as `/Applications` for a standard user. Approve the administrator prompt, or move the file to a folder you own.

**“Operation not permitted”**
Some protected locations cannot be modified even by the script. Copy the app to `/Applications` or `~/Applications` and try again.

**The app is on a mounted DMG**
Disk images are read-only. Copy the app to `/Applications` first, then unlock it there.

**“App is damaged”**
That message is usually a quarantine or signature problem. Unlock the app and check the log. If the signature was broken, the script re-signs it ad-hoc; the app will open, but it will no longer match the original developer signature.

**The quarantine comes back**
macOS re-adds it if the file is downloaded again. Run the unlock after the download, not before.

**Where are the logs?**
`~/Library/Logs/GatekeeperFileUnlock.log`

## Uninstall

```bash
./uninstall-finder-service.sh
```

This removes the Quick Action and the helper script. To also delete the log:

```bash
./uninstall-finder-service.sh --purge
```

Then restart Finder:

```bash
killall Finder
```

## Security notice

Gatekeeper is a macOS security feature: it warns you before opening software from unidentified developers. This tool deliberately removes one of those checks.

**Only unlock software you trust and that comes from a source you trust.** When possible, prefer the built-in alternatives:

- right-click the app → **Open** the first time;
- **System Settings → Privacy & Security → Open Anyway**;
- ask the developer to sign and notarize the app.

The script never downloads anything and never sends data anywhere. It runs locally and only modifies extended attributes on the files you select.

## Project layout

```
.
├── unlock-gatekeeper.sh          # main script
├── install-finder-service.sh     # installs the Quick Action
├── uninstall-finder-service.sh   # removes it
├── Unlock App.command            # double-click launcher
└── quick-action/
    ├── Info.plist                # Quick Action metadata
    └── workflow.json             # Automator workflow
```

## Credits

This utility started as a helper inside [Commander for macOS](https://github.com/hellomoto8999/commander-macos) and is now maintained as a standalone project.

## License

[MIT](LICENSE) © 2026 hellomoto8999
