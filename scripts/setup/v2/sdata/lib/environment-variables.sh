# Environment variables for niri-caelestia-shell installer
XDG_BIN_HOME=${XDG_BIN_HOME:-$HOME/.local/bin}
XDG_CACHE_HOME=${XDG_CACHE_HOME:-$HOME/.cache}
XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}
XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}
XDG_STATE_HOME=${XDG_STATE_HOME:-$HOME/.local/state}

STY_RED='\e[31m'
STY_GREEN='\e[32m'
STY_YELLOW='\e[33m'
STY_BLUE='\e[34m'
STY_PURPLE='\e[35m'
STY_CYAN='\e[36m'
STY_BOLD='\e[1m'
STY_RST='\e[00m'

# Requested backup location
BACKUP_DIR="$HOME/niri-caelestia-shell.backup"
VENV_DIR="${XDG_STATE_HOME}/quickshell/.venv"
DOTFILES_GIT_DIR="${DOTFILES_GIT_DIR:-$HOME/.dotfiles.git}"
DOTFILES_WORK_TREE="${DOTFILES_WORK_TREE:-$HOME}"
DOTFILES_REF="${DOTFILES_REF:-HEAD}"
DOTFILES_REMOTE_URL="${DOTFILES_REMOTE_URL:-https://github.com/lukasz-sz96/niri-caelestia-dotfiles.git}"
DOTFILES_BACKUP_DIR="${DOTFILES_BACKUP_DIR:-$XDG_STATE_HOME/niri-caelestia-shell/dotfiles-install-backups}"
