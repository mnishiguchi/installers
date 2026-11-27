# KDE desktop configuration follow-up

- Fedora Asahi bootstrap and dotfiles rerun and managed-state checks passed on
  the configured M1 Pro; installers baseline `9a550fe` and dotfiles `8de2edb`
  were pushed. Fresh-install validation is outstanding.
- Captured selected settings from `kxkbrc`, `kwinrc`, and `kdeglobals` on KDE
  Plasma Wayland. Observed US layout, Caps Lock additional Ctrl, three desktops
  in one row, wraparound, desktop change indicator, disabled slide animation,
  Breeze Dark, and the Fcitx5 service entry.
- Keep the KDE preference script opt-in; do not overwrite complete config files.
- Observed KWin Overview and Present Windows (all desktops) on Ctrl+Alt+Up/Down,
  rather than Grid View and current-desktop windows. KRunner and Spectacle
  intended shortcuts still need live verification; the installed desktop-file
  defaults do not prove the intended active behavior.
- Fcitx5 profile contains keyboard-us and mozc; leave live profile management
  and global shortcut changes manual for now.
- Offline regression test exercises drift reporting, targeted writes,
  preservation of unrelated state, rerun idempotency, and session/dependency
  guards. Live restoration and post-login acceptance are pending.
