# Common functions for niri-caelestia-shell installer
function try { "$@" || sleep 0; }
function v(){
  echo -e "${STY_CYAN}[next]: $*${STY_RST}"
  local execute=true
  if $ask; then
    read -p "Execute? [Y/n/s/all]: " p
    case $p in
      [nNsS]) execute=false ;;
      "all") ask=false ;;
      *) execute=true ;;
    esac
  fi
  if $execute; then x "$@"; fi
}
function x(){
  if "$@"; then return 0; else
    echo -e "${STY_RED}Failed: $*${STY_RST}"
    read -p "[R]etry, [i]gnore, [e]xit: " p
    case $p in
      [iI]) return 0 ;;
      [eE]) exit 1 ;;
      *) x "$@" ;;
    esac
  fi
}
function showfun() {
  echo -e "${STY_BLUE}The definition of function \"$1\" is as follows:${STY_RST}"
  echo -e "${STY_GREEN}"
  type -a "$1"
  echo -e "${STY_RST}"
}
function pause(){
  if [[ "$ask" != "false" ]]; then
    read -p "(Enter to continue, Ctrl-C to abort)"
  fi
}
function prevent_sudo_or_root(){
  if [[ $EUID -eq 0 ]]; then
    echo -e "${STY_RED}Do not run as root.${STY_RST}"; exit 1
  fi
}
declare -g SUDO_KEEPALIVE_PID=""
function sudo_init_keepalive(){
  sudo -v
  ( while true; do sudo -n true; sleep 60; done ) &
  SUDO_KEEPALIVE_PID=$!
}
function sudo_stop_keepalive(){
  [[ -n "$SUDO_KEEPALIVE_PID" ]] && kill "$SUDO_KEEPALIVE_PID" 2>/dev/null
}

# Smart Backup Function: Preserves existing files that clash with the new ones
function backup_clashing_configs(){
  local source_dir="$1"
  local target_dir="$2"
  local backup_path="$3"
  
  if [[ ! -d "$source_dir" ]]; then return 0; fi
  
  echo -e "${STY_BLUE}Checking for clashing configs in $(basename "$target_dir")...${STY_RST}"
  
  # Create a timestamped subfolder for this backup session
  local session_backup="${backup_path}/$(date +%Y%m%d_%H%M%S)"
  local clash_found=false

  # Find top-level items in the source folder
  for item in $(ls -A "$source_dir"); do
    if [[ -e "${target_dir}/${item}" ]]; then
      if ! $clash_found; then
        mkdir -p "$session_backup"
        clash_found=true
      fi
      echo -e "  ${STY_DIM}Preserving: $item${STY_RST}"
      cp -rf "${target_dir}/${item}" "${session_backup}/"
    fi
  done

  if $clash_found; then
    echo -e "${STY_GREEN}Backup saved to: $session_backup${STY_RST}"
  fi
}

function install_bare_dotfiles(){
  if [[ "${SKIP_DOTFILES:-false}" == true ]]; then
    echo -e "${STY_YELLOW}Skipping dotfiles install (SKIP_DOTFILES=true).${STY_RST}"
    return 0
  fi

  if [[ ! -d "$DOTFILES_GIT_DIR" ]]; then
    if [[ -z "$DOTFILES_REMOTE_URL" ]]; then
      echo -e "${STY_YELLOW}Dotfiles repo not found at $DOTFILES_GIT_DIR and DOTFILES_REMOTE_URL is empty; skipping dotfiles install.${STY_RST}"
      return 0
    fi

    echo -e "${STY_BLUE}Cloning dotfiles from $DOTFILES_REMOTE_URL to $DOTFILES_GIT_DIR...${STY_RST}"
    mkdir -p "$(dirname "$DOTFILES_GIT_DIR")"
    git clone --bare "$DOTFILES_REMOTE_URL" "$DOTFILES_GIT_DIR"
  fi

  if ! git --git-dir="$DOTFILES_GIT_DIR" rev-parse --is-bare-repository >/dev/null 2>&1; then
    echo -e "${STY_RED}$DOTFILES_GIT_DIR is not a bare Git repository.${STY_RST}"
    return 1
  fi

  if [[ -n "$DOTFILES_REMOTE_URL" ]] && ! git --git-dir="$DOTFILES_GIT_DIR" remote get-url origin >/dev/null 2>&1; then
    git --git-dir="$DOTFILES_GIT_DIR" remote add origin "$DOTFILES_REMOTE_URL"
  fi

  local checkout_ref="$DOTFILES_REF"
  if [[ "$checkout_ref" == "HEAD" ]]; then
    checkout_ref="$(git --git-dir="$DOTFILES_GIT_DIR" symbolic-ref --quiet --short HEAD 2>/dev/null || printf "HEAD")"
  fi

  local tracked_paths=()
  mapfile -t tracked_paths < <(git --git-dir="$DOTFILES_GIT_DIR" ls-tree -r --name-only "$checkout_ref")
  if [[ ${#tracked_paths[@]} -eq 0 ]]; then
    echo -e "${STY_YELLOW}No tracked dotfiles found in $DOTFILES_GIT_DIR at $checkout_ref.${STY_RST}"
    return 0
  fi

  echo -e "${STY_BLUE}Applying dotfiles from $DOTFILES_GIT_DIR ($checkout_ref) to $DOTFILES_WORK_TREE...${STY_RST}"

  local session_backup="$DOTFILES_BACKUP_DIR/$(date +%Y%m%d_%H%M%S)"
  local backed_up=false
  local rel target backup_target

  for rel in "${tracked_paths[@]}"; do
    if [[ "$rel" == /* || "$rel" == *".."* ]]; then
      echo -e "${STY_RED}Refusing unsafe dotfiles path: $rel${STY_RST}"
      return 1
    fi

    target="$DOTFILES_WORK_TREE/$rel"
    if [[ -e "$target" || -L "$target" ]]; then
      backup_target="$session_backup/$rel"
      mkdir -p "$(dirname "$backup_target")"
      cp -a "$target" "$backup_target"
      backed_up=true
    fi
  done

  if $backed_up; then
    echo -e "${STY_GREEN}Existing dotfiles backup saved to: $session_backup${STY_RST}"
  fi

  mkdir -p "$DOTFILES_WORK_TREE"
  git --git-dir="$DOTFILES_GIT_DIR" --work-tree="$DOTFILES_WORK_TREE" checkout -f "$checkout_ref"
  git --git-dir="$DOTFILES_GIT_DIR" --work-tree="$DOTFILES_WORK_TREE" config status.showUntrackedFiles no

  echo -e "${STY_GREEN}Dotfiles installed from $DOTFILES_GIT_DIR.${STY_RST}"
}
