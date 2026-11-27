# KDE native clipboard and snippets evaluation

Status: proposed real-machine acceptance; no package changes.

The [Klipper handbook](https://docs.kde.org/trunk_kf6/en/plasma-workspace/klipper/using-klipper.html)
describes searchable clipboard history and per-item actions. The
[settings guide](https://docs.kde.org/stable_kf6/en/plasma-workspace/klipper/preferences.html)
describes history size, persistence, primary selection and image inclusion.
This makes native history a reasonable candidate, not yet a proven replacement
for CopyQ's scripting and custom workflows.

## Clipboard experiment

1. Quit CopyQ from its tray menu temporarily; keep packages and history intact.
2. Open the Plasma clipboard tray widget with Super+V (observed default).
3. In Configure Clipboard, review history size, persistence and image handling.
   For this test disable save across sessions and inclusion of selected text;
   do not change unrelated settings automatically.
4. Copy harmless distinct text in Brave, Alacritty and Neovim. Search and select
   earlier entries with Super+V, then paste using each application's usual
   shortcut (Ctrl+Shift+V in the terminal). Test Japanese text and multiline code.
5. Test copying an image with Spectacle if that workflow is needed. Test removal
   of individual dummy entries and clipboard behavior after logout/login.
6. Test password-manager exclusion only with dummy credentials. Clipboard
   managers may retain sensitive values; do not assume exclusions are reliable.
7. Decide whether any essential workflow is missing. Restart CopyQ if needed.

If native history is sufficient, separately propose removing CopyQ from the
Fedora-only manifest and making the KDE doctor check native-aware. Do not purge
existing CopyQ data or change LMDE/macOS preferences.

## Snippets are a separate workflow

The shared `dotfiles-snippets` engine already supports `--list`, `--check`,
`--copy NAME` and `--print NAME`; it does not need clipboard history or Rofi
when invoked by name. A native KDE frontend could expose generated per-snippet
user desktop entries to KRunner, analogous to the macOS Spotlight apps. Test a
single benign desktop entry before designing a synchronizer; verify name search,
launch, copy, cancellation and safe ownership of generated files. No automatic
paste on Wayland, no xdotool workaround and no new picker dependency unless
needed. Keep the snippet data and executable behavior in dotfiles.

## Decision gate

Adopt Klipper only after the basic clipboard workflow passes on the actual KDE
session. Keep CopyQ if a demonstrated need justifies it. Choose a snippet
frontend independently of clipboard history.
