# macOS development environment

Restore a terminal-based development environment similar to LMDE without
installing Linux desktop software. The bootstrap supports native Apple Silicon
and Intel Homebrew prefixes, but Apple Silicon is the primary target. The
script is compatible with macOS system Bash 3.2.

## 1. Prepare macOS

Back up important data. Check the [Homebrew support tiers](https://docs.brew.sh/Support-Tiers)
for your macOS release. Sonoma 14 may require unsupported source builds; prefer
a currently supported macOS release when possible. If dual-booting Linux,
check the Linux installer's firmware and macOS requirements before upgrading.

In Apple's Terminal (not a broken Alacritty instance):

```bash
uname -m                   # arm64 on a native Apple Silicon terminal
xcode-select -p
```

If the command line tools are missing, run `xcode-select --install` and finish
the installation. Install Homebrew using the command published on
[brew.sh](https://brew.sh/), or skip that step if it is already present.
On Apple Silicon, initialize the current shell with:

```bash
eval "$(/opt/homebrew/bin/brew shellenv)"
brew --version
```

For Intel use `/usr/local/bin/brew` instead. The bootstrap discovers the native
prefix itself. Do not run it using `sudo` or under Rosetta.

## 2. Install or update Alacritty

The Alacritty Homebrew cask is disabled. Use the official macOS DMG from
[alacritty.org](https://alacritty.org/) and copy Alacritty.app into Applications.
Do not disable Gatekeeper or remove quarantine attributes automatically.

```bash
/Applications/Alacritty.app/Contents/MacOS/alacritty --version
```

The shared dotfiles require at least Alacritty 0.14 (the `terminal.shell`
configuration table). Use a recent version compatible with your macOS release.
The bootstrap checks this requirement before package installation and again at
verification time; it does not modify the application. If Gatekeeper blocks a
verified upstream download, use System Settings > Privacy & Security > Open
Anyway for that application only.

## 3. Restore the development environment

From the installers checkout:

```bash
./macos-bootstrap.sh --only preflight
./macos-bootstrap.sh --check
./macos-bootstrap.sh
./macos-bootstrap.sh --check
```

A check reporting missing components exits with status 1. Preflight reports
macOS support, developer-tool health, Homebrew permissions and lock files.
Recognized blocking failures stop package installation; other doctor warnings
are advisory. Checks may refresh local Homebrew metadata but do not install
packages. Executable verification also starts an isolated interactive Fish
login shell; normal Fish startup can update its own caches or universal
variables. The restore creates
XDG directories, installs essential packages from `manifests/Brewfile`, applies dotfiles
with conflict backups, installs Neovim/Yazi through Mise, checks Alacritty and
sets Fish as the login shell and smoke-tests core executables. It never upgrades all packages, removes unlisted
packages, overwrites existing repository changes or changes SSH keys.
Homebrew may upgrade dependencies required to install packages.

## Spotlight snippet applications

The macOS dotfiles use the built-in Spotlight launcher for applications and
individual snippet applications. After applying the dotfiles `bin` section,
generate or refresh the snippet applications with:

```bash
dotfiles-macos-snippets-sync --check
dotfiles-macos-snippets-sync
dotfiles-macos-snippets-sync --verify
```

Press Cmd+Space and search for a result such as `Snippet cmd uuid`. See the
dotfiles [Spotlight snippet guide](https://github.com/mnishiguchi/dotfiles/blob/main/macos/spotlight-snippets.md)
for details.

After confirming the generated applications work, remove the old dmenu-mac
cask explicitly if it is still installed:

```bash
brew uninstall --cask dmenu-mac
```

The cask is no longer in `manifests/Brewfile`, but Homebrew Bundle does not
uninstall packages merely because they are absent from a manifest. This
migration does not automatically remove the application or its preferences.

The bootstrap discovers the active dotfiles checkout from managed shell and
launcher links. If no active checkout is found, it looks beside installers and
in `~/Projects/dotfiles`, `~/Code/dotfiles`, and `~/.dotfiles`. Symlink aliases
are resolved to physical paths, so they are not counted as separate checkouts.
If no checkout exists, the default clone destination is `../dotfiles`.
Conflicting active links or multiple candidates without an active checkout
require an explicit selection, for example:

```bash
DOTFILES_DIR="$HOME/Projects/dotfiles" ./macos-bootstrap.sh --only dotfiles --check
```

Use a dotfiles revision supporting `install.sh --verify` (exit 0 ready, 3 drift,
1 error). Ready links are left alone; drift is reconciled with backups and
verified again. Other verification errors stop replacement. The bootstrap
never pulls, merges, moves or deletes existing checkouts. Prefer one checkout
per machine; `~/Projects` is a convenient convention, not a requirement.

Log out and back in after changing the login shell. If an existing tmux server
still uses an older shell, use `./macos-bootstrap.sh --only shell --update-tmux`
to update its global default without killing any panes. Existing panes do not
change; open a new tmux window.

## 4. Selective restore

```bash
./macos-bootstrap.sh --only brew
./macos-bootstrap.sh --only dotfiles,mise
./macos-bootstrap.sh --only alacritty --check
./macos-bootstrap.sh --skip-shell-change
```

CopyQ is an optional desktop application because the upstream macOS app is
not signed/notarized and the official Homebrew cask is disabled. Install it only
after reviewing the Gatekeeper caveat and accepting the manual approval step:

```bash
./macos-bootstrap.sh --only copyq
./macos-bootstrap.sh --only copyq --check
```

Normal installation verifies the official upstream DMG checksum, preserves
quarantine, and does not ad-hoc sign or launch the app. If strict nested
signature verification fails, the separate `repair-signature` mode is an
explicit application-specific security exception; review its risks first. See
[CopyQ on LMDE and macOS](copyq.md).

For optional Docker development without Docker Desktop:

```bash
./macos-bootstrap.sh --only colima
./macos-bootstrap.sh --only colima --check
```

The section configures CLI tools without starting a VM. See [Colima](colima.md)
for the first start, Docker context selection and smoke tests.

For language development, explicitly opt into the runtime section:

```bash
./macos-bootstrap.sh --only optional
./macos-bootstrap.sh --only build,runtimes
./macos-bootstrap.sh --only runtimes --check
```

Optional utilities (`ffmpeg`, `fastfetch`, `zk`) and native build dependencies
are separate manifests so failures cannot block basic terminal setup. The
`runtimes` section installs selected LMDE-equivalent language versions through Mise; it may
change the configured global versions for those tools. It does not aim to
install every Linux-specific embedded development or virtualization tool.
Already configured and installed Mise tool selections are retained, rather
than running `mise use` repeatedly. Restore runs `mise reshim` and checks the
requested versions again. Native runtime builds may need additional dependencies. Nerves system builds
remain a Linux workflow; use a suitable Linux environment.

## 5. Verify and troubleshoot

```bash
./macos-bootstrap.sh --only verify
dotfiles-doctor
command -v fish tmux mise
mise ls --global
mise which nvim
mise which yazi
fish -lic 'type -a nvim yazi; nvim --version; yazi --version'
ssh -T git@github.com
```

If SSH is already working, leave the key unchanged. Otherwise the optional
`user/github-ssh-setup.sh` helper supports native macOS clipboard and Keychain
integration. For passphrase persistence, configure `UseKeychain yes` in your
SSH configuration as needed.

For Alacritty startup problems, isolate the terminal from tmux:

```bash
/Applications/Alacritty.app/Contents/MacOS/alacritty -vv -e /bin/zsh -l
```

## Troubleshooting an existing Mac

- If Homebrew cannot write a lock or log, inspect ownership and active Brew
  processes. Repair only the affected files as the machine owner; never use
  `sudo brew` or automatically transfer another user's files.
- If `brew doctor` reports outdated CLT or Xcode, use Software Update or remove
  obsolete full Xcode manually after checking you do not need it. Install the
  latest CLT compatible with your current OS. Do not hardcode an update label.
- If `dyld` reports missing libraries, run `brew missing` and optionally
  `./macos-bootstrap.sh --only linkage`. Homebrew may enable developer mode;
  use `brew developer off` if you did not previously use it. Reinstall the
  affected formula/dependency, then retest the executable. Do not manufacture
  symlinks or force-link keg-only OpenSSL versions. A `brew list` entry alone
  is not proof that a program runs.
- If `pkgconf` conflicts with legacy `pkg-config`, inspect the link owner and
  unlink the legacy formula before linking the replacement. Never blindly
  overwrite links. Preserve existing databases before retiring PostgreSQL.
- Review `~/.tool-versions` if Mise reports unexpected runtime versions. Archive
  only after checking its contents and deciding which runtimes to keep, then
  run `mise reshim` and `mise doctor`. The bootstrap never deletes that file.
  Protect
  an owned regular `~/.netrc` with mode 0600; never print credentials.
- `dotfiles-doctor` checks the current shell's PATH. Open a new Fish login shell
  and test `ls`, `zi`, Neovim, Yazi, clipboard and font rendering from Alacritty.
  Bootstrap verification compares the actual Neovim and Yazi executables in a
  fresh Fish login shell with the paths reported by Mise (including symlink
  equivalence). GUI acceptance is manual; smoke tests cannot prove it.

## Repository boundary

`installers` owns package and runtime installation. `dotfiles` owns application
configuration. Use this repository's Brewfiles as the authoritative manifests.
The duplicate manifest in dotfiles has been removed.
On macOS use Homebrew for the font and Mise for Neovim; the older Linux binary
and font installation helpers are not part of the macOS bootstrap.

This setup covers terminal development, not a full macOS desktop restore.
Docker and CopyQ are opt-in; other GUI applications, embedded tooling and OS
preferences remain optional follow-up work. Existing LMDE scripts and manifests are unchanged.
