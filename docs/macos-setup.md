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
The bootstrap checks this requirement but does not modify the application.

## 3. Restore the development environment

From the installers checkout:

```bash
./macos-bootstrap.sh --check
./macos-bootstrap.sh
./macos-bootstrap.sh --check
```

A check reporting missing components exits with status 1. The restore creates
XDG directories, installs packages from `manifests/Brewfile`, applies dotfiles
with conflict backups, installs Neovim/Yazi through Mise, checks Alacritty and
sets Fish as the login shell. It never upgrades all packages, removes unlisted
packages, overwrites existing repository changes or changes SSH keys.
Homebrew may upgrade dependencies required to install packages.

The dotfiles checkout defaults to `../dotfiles`; set `DOTFILES_DIR` for another
location. Ensure that checkout contains the cross-platform terminal launcher
and macOS shell changes before restoring. The bootstrap does not pull updates
into an existing checkout.

Log out and back in after changing the login shell. If an existing tmux server
still uses an older shell, start a fresh session or server after saving your work.

## 4. Selective restore

```bash
./macos-bootstrap.sh --only brew
./macos-bootstrap.sh --only dotfiles,mise
./macos-bootstrap.sh --only alacritty --check
./macos-bootstrap.sh --skip-shell-change
```

For language development, explicitly opt into the runtime section:

```bash
./macos-bootstrap.sh --only runtimes
./macos-bootstrap.sh --only runtimes --check
```

This installs selected LMDE-equivalent language versions through Mise; it may
change the configured global versions for those tools. It does not aim to
install every Linux-specific embedded development or virtualization tool.
Native runtime builds may need additional dependencies. Nerves system builds
remain a Linux workflow; use a suitable Linux environment.

## 5. Verify and troubleshoot

```bash
command -v fish tmux mise
mise ls --global
mise exec -- nvim --version
mise exec -- yazi --version
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

## Repository boundary

`installers` owns package and runtime installation. `dotfiles` owns application
configuration. Use this repository's Brewfile as the authoritative list; the
initial macOS support patch in dotfiles included a temporary Brewfile which
should be removed in a separate dotfiles commit. Do not run both manifests.
On macOS use Homebrew for the font and Mise for Neovim; the older Linux binary
and font installation helpers are not part of the macOS bootstrap.

This first pass covers terminal development, not a full macOS desktop restore.
Docker, GUI applications, embedded tooling and OS preferences remain optional
follow-up work. Existing LMDE scripts and manifests are unchanged.
