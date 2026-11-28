# Fedora Asahi desktop applications

- The workstation hostname was changed to `asahi`; hostname remains a local
  choice, not a managed installer setting.
- Brave 158.1.100.59 ran on aarch64 with 16 KiB kernel pages. PipeWire,
  PulseAudio compatibility, WirePlumber, XDG Desktop Portal and
  `plasma-xdg-desktop-portal-kde.service` were all active. `wpctl status`
  reported audio devices, Asahi processing filters and the FaceTime HD camera.
- Slack sign-in, Brave web app installation, KRunner launch and explicit dark
  mode were confirmed by the user. Discord was installed using the same web
  app procedure and KRunner launch was reported successful.
- 1Password installation was reported successful; exact package origin and
  installation commands are still unrecorded.
- Prefer the vendor web apps in the existing native browser for now. No new
  browser, emulation layer, unofficial client, or package manifest change.
- Notifications, Japanese input, calls, microphone/speakers, camera, sharing
  and session/suspend recovery remain to be tested for both applications.
- Document the manual restore procedure in
  [Fedora Asahi desktop applications](../fedora-asahi-applications.md).
  Account authentication and browser registration are intentionally not
  automated. LMDE and macOS behavior is unchanged.
