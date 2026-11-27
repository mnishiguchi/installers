# Native-first KDE integration

- Adopt the shared workstation philosophy in installers and dotfiles.
- Real-machine D-Bus experiments identified KRunner, Spectacle, Alacritty and
  KWin action IDs; all seven target key owners were reported after live writes.
  Alternative bindings were preserved. Physical keys and confirmed logout/login
  persistence still require explicit acceptance.
- Add opt-in shortcut automation using the tested KGlobalAccel calls; offline
  tests cover conflicts, transfer, preservation, drift and idempotency. A fresh
  desktop may need to register Alacritty in System Settings first.
- Evaluate Klipper before changing the Fedora CopyQ manifest or diagnostics.
  Existing LMDE and macOS setup remains untouched. Native KRunner snippet
  discovery is a candidate experiment, not implemented support.
