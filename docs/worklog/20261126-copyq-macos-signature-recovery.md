# CopyQ macOS installation and signature recovery

The CopyQ 17.0.0 Apple Silicon DMG passed the official SHA-512 checksum check,
but the installed app failed strict nested code-signature verification in
`Contents/PlugIns/iconengines/libqsvgicon.dylib`. A manually applied upstream
workaround (`xattr -d com.apple.quarantine` followed by
`codesign --force --deep --sign -`) made strict verification pass and allowed
CopyQ to launch on the test MacBook. The resulting signature is ad-hoc, not
Developer ID signed or notarized.

The installer now keeps normal installation conservative: it preserves the
browser quarantine marker, does not alter signatures, and repairs only its own
exact dangling CLI symlink. Its `--check` mode verifies nested code-signature
integrity and identifies ad-hoc signing explicitly.

A separate `repair-signature` mode makes the workaround opt-in. It requires a
browser-downloaded quarantined DMG, verifies its official SHA-512 checksum,
compares the installed app with the app inside that release, refuses to run
while CopyQ is active, and requires an explicit confirmation phrase before
removing the app's quarantine marker and applying an ad-hoc signature. It then
runs strict nested-signature verification. This does not establish publisher
identity or notarization and is not part of bootstrap.

Regression tests cover equivalent `17.0`/`17.0.0` bundle versions, strict
signature checks, exact stale-link recovery, refusal of unrelated dangling
links, checksum-gated repair, content comparison, and the running-process guard.
