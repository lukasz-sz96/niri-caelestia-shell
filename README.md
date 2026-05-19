# Niri Caelestia Shell

This is my personal Niri desktop shell setup. It started as a fork of
[jutraim's niri-caelestia-shell](https://github.com/jutraim/niri-caelestia-shell),
which is a Niri adaptation of [Caelestia Shell](https://github.com/caelestia-dots/shell).

I use this repo for the shell, installer, SDDM theme, scripts, and the pieces
that make the desktop work. My personal user config lives in a separate
dotfiles repo:

```text
https://github.com/lukasz-sz96/niri-caelestia-dotfiles
```

This is not a clean upstream-style package. It is my daily desktop, kept in Git
so I can install it again, fix it when I break it, and keep the shell separate
from generated theme state.

## Showcase

<video src="./out.mp4" controls width="100%"></video>

## What This Includes

- Quickshell shell for Niri
- Bar, launcher, dashboard, session menu, notifications, OSD, lock UI, and IPC
- Niri-oriented bindings and service integration
- Wallpaper-driven Material You colors through Matugen
- Optional SDDM theme under `themes/niri-caelestia-sddm`
- A v2 installer that can bootstrap the shell and install my dotfiles from a
  public bare Git repo

The shell repo does not ship personal dotfiles anymore. Dotfiles are installed
from the separate bare repo into `$HOME`, and generated files stay writable on
the live system.

## Repo Layout

```text
components/                 shared QML components
config/                     shell configuration schema/defaults
modules/                    shell modules and surfaces
services/                   system, Niri, media, color, and network services
scripts/colors/             wallpaper and color-generation pipeline
scripts/setup/v2/           current staged installer
themes/niri-caelestia-sddm/ optional SDDM theme
THEME.md                    theming notes
```

Important runtime paths:

```text
~/.config/quickshell/niri-caelestia-shell   installed shell checkout
~/.config/niri_caelestia/shell.json         persisted shell settings
~/.dotfiles.git                             bare dotfiles repo
~/.local/state/quickshell/user/generated    generated color/theme state
```

## Install

This setup targets Arch Linux. The installer uses `pacman`, `yay`, `uv`,
`cmake`, and `ninja`.

```sh
git clone https://github.com/lukasz-sz96/niri-caelestia-shell
cd niri-caelestia-shell
./scripts/setup/v2/setup install
```

The full install runs these stages:

```text
install-deps    install system dependencies
install-setups  configure groups, services, and runtime state
install-files   install dotfiles, build the shell, copy bundled assets
install-sddm    install and configure the SDDM theme
```

You can run stages independently:

```sh
./scripts/setup/v2/setup install-deps
./scripts/setup/v2/setup install-setups
./scripts/setup/v2/setup install-files
./scripts/setup/v2/setup install-sddm
```

## Dotfiles

The installer clones or updates this public bare repo:

```text
https://github.com/lukasz-sz96/niri-caelestia-dotfiles.git
```

Defaults:

```text
DOTFILES_REMOTE_URL=https://github.com/lukasz-sz96/niri-caelestia-dotfiles.git
DOTFILES_GIT_DIR=$HOME/.dotfiles.git
DOTFILES_WORK_TREE=$HOME
DOTFILES_REF=HEAD
```

Existing target files are backed up before checkout:

```text
~/.local/state/niri-caelestia-shell/dotfiles-install-backups/
```

Skip the dotfiles step when testing shell-only changes:

```sh
SKIP_DOTFILES=true ./scripts/setup/v2/setup install-files
```

Manual dotfiles install:

```sh
git clone --bare https://github.com/lukasz-sz96/niri-caelestia-dotfiles.git "$HOME/.dotfiles.git"
git --git-dir="$HOME/.dotfiles.git" --work-tree="$HOME" checkout -f main
git --git-dir="$HOME/.dotfiles.git" --work-tree="$HOME" config status.showUntrackedFiles no
```

After install, use the `dots` helper from the dotfiles repo:

```sh
dots status
dots add ~/.config/niri/niri/input.kdl
dots commit -m "Update niri input config"
dots push
```

## Manual Build

If you only want to build the shell:

```sh
cd ~/.config/quickshell
git clone https://github.com/lukasz-sz96/niri-caelestia-shell
cd niri-caelestia-shell

cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/
cmake --build build
sudo cmake --install build
```

Start it with:

```sh
quickshell -c niri-caelestia-shell -n
```

or:

```sh
qs -c niri-caelestia-shell -n
```

## Niri Integration

Typical startup entry:

```kdl
spawn-at-startup "quickshell" "-c" "niri-caelestia-shell" "-n"
```

Backdrop rule for overview blur:

```kdl
layer-rule {
    match namespace="quickshell:Backdrop"
    place-within-backdrop true
    opacity 1.0
}
```

Useful IPC examples:

```sh
qs -c niri-caelestia-shell ipc show
qs -c niri-caelestia-shell ipc call drawers toggle launcher
qs -c niri-caelestia-shell ipc call clipboard open
qs -c niri-caelestia-shell ipc call picker open
qs -c niri-caelestia-shell ipc call lock lock
qs -c niri-caelestia-shell ipc call wallpaper list
```

Example binds:

```kdl
Mod+Space repeat=false {
    spawn-sh "qs -c niri-caelestia-shell ipc call drawers toggle launcher"
}

Mod+V repeat=false {
    spawn-sh "qs -c niri-caelestia-shell ipc call clipboard open"
}

Mod+Shift+S {
    spawn-sh "qs -c niri-caelestia-shell ipc call picker open"
}

Mod+L {
    spawn-sh "qs -c niri-caelestia-shell ipc call lock lock"
}
```

## Theming

The color pipeline is wallpaper-driven:

```sh
bash scripts/colors/switchwall.sh --mode dark /path/to/wallpaper.jpg
```

Matugen templates live in the dotfiles repo under:

```text
~/.config/matugen/
```

Shell-generated state goes under:

```text
~/.local/state/quickshell/user/generated/
```

More detailed notes are in [THEME.md](THEME.md).

## SDDM Theme

The optional login theme lives outside dotfiles:

```sh
bash themes/niri-caelestia-sddm/setup.sh
```

During setup, option `1` syncs colors directly with the shell.

## Updating

Shell:

```sh
cd ~/.config/quickshell/niri-caelestia-shell
git pull
./scripts/setup/v2/setup install-files
```

Dotfiles:

```sh
dots pull
```

If you changed live config and want to commit it:

```sh
dots status
dots add ~/.config/path/to/file
dots commit -m "Describe the change"
dots push
```

## Dependencies

The installer is the source of truth, but the rough dependency set is:

```text
quickshell-git networkmanager networkmanager-qt fish glibc qt6-declarative
gcc-libs cava libcava aubio libpipewire ddcutil brightnessctl grim swappy
app2unit libqalculate wl-clipboard cliphist tesseract tesseract-data-eng
curl cmake ninja uv matugen kitty starship eza fuzzel
```

`caelestia-cli` is not required for this Niri setup.

## Current Rough Edges

- This is a personal setup, not a polished generic distribution.
- The installer is Arch-focused.
- Some Quickshell behavior depends on upstream Niri/Quickshell focus handling.
- The task manager GPU stats are aimed at my hardware and are not universal.
- Generated theme files should stay out of Git unless there is a specific reason
  to inspect them.

## Credits

- [Quickshell](https://github.com/quickshell/quickshell)
- [Caelestia Shell](https://github.com/caelestia-dots/shell)
- [jutraim/niri-caelestia-shell](https://github.com/jutraim/niri-caelestia-shell)
- [Niri](https://github.com/YaLTeR/niri)
- [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland)
