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

  if [[ -n "$DOTFILES_REMOTE_URL" ]]; then
    local current_remote=""
    current_remote="$(git --git-dir="$DOTFILES_GIT_DIR" remote get-url origin 2>/dev/null || true)"

    if [[ -z "$current_remote" ]]; then
      git --git-dir="$DOTFILES_GIT_DIR" remote add origin "$DOTFILES_REMOTE_URL"
    elif [[ "$current_remote" != "$DOTFILES_REMOTE_URL" ]]; then
      echo -e "${STY_BLUE}Updating dotfiles origin from $current_remote to $DOTFILES_REMOTE_URL...${STY_RST}"
      git --git-dir="$DOTFILES_GIT_DIR" remote set-url origin "$DOTFILES_REMOTE_URL"
    fi

    echo -e "${STY_BLUE}Fetching latest dotfiles from origin...${STY_RST}"
    git --git-dir="$DOTFILES_GIT_DIR" fetch --prune origin
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
  prepare_dotfiles_generated_paths

  echo -e "${STY_GREEN}Dotfiles installed from $DOTFILES_GIT_DIR.${STY_RST}"
}

function prepare_dotfiles_generated_paths(){
  local generated_dir="$DOTFILES_WORK_TREE/.local/state/quickshell/user/generated"
  local btop_theme="$DOTFILES_WORK_TREE/.config/btop/themes/niri_caelestia.theme"
  local niri_colors="$DOTFILES_WORK_TREE/.config/niri/colors.kdl"
  local kitty_theme="$generated_dir/terminal/kitty-theme.conf"
  local fish_sequences="$generated_dir/terminal/sequences.txt"
  local kvantum_dir="$DOTFILES_WORK_TREE/.config/Kvantum"
  local kvantum_generated_dir="$kvantum_dir/MaterialAdw"

  mkdir -p \
    "$DOTFILES_WORK_TREE/.config/gtk-3.0" \
    "$DOTFILES_WORK_TREE/.config/gtk-4.0" \
    "$DOTFILES_WORK_TREE/.config/btop/themes" \
    "$DOTFILES_WORK_TREE/.config/mpv/script-opts" \
    "$kvantum_generated_dir" \
    "$generated_dir/terminal" \
    "$generated_dir/wallpaper"

  if [[ ! -e "$niri_colors" ]]; then
    printf '// Generated by matugen. Kept untracked so fresh installs validate before the first wallpaper sync.\n' > "$niri_colors"
  fi

  if [[ ! -e "$kitty_theme" ]]; then
    : > "$kitty_theme"
  fi

  if [[ ! -e "$fish_sequences" ]]; then
    : > "$fish_sequences"
  fi

  if [[ ! -e "$btop_theme" ]]; then
    cat > "$btop_theme" <<'EOF'
theme[main_bg]=""
theme[main_fg]="#cdd6f4"
theme[title]="#cdd6f4"
theme[hi_fg]="#89b4fa"
theme[selected_bg]="#313244"
theme[selected_fg]="#cdd6f4"
theme[inactive_fg]="#7f849c"
theme[graph_text]="#bac2de"
theme[meter_bg]="#313244"
theme[proc_misc]="#cba6f7"
theme[cpu_box]="#45475a"
theme[mem_box]="#45475a"
theme[net_box]="#45475a"
theme[proc_box]="#45475a"
theme[div_line]="#45475a"
theme[temp_start]="#a6e3a1"
theme[temp_mid]="#f9e2af"
theme[temp_end]="#f38ba8"
theme[cpu_start]="#a6e3a1"
theme[cpu_mid]="#f9e2af"
theme[cpu_end]="#f38ba8"
theme[free_start]="#a6e3a1"
theme[free_mid]="#94e2d5"
theme[free_end]="#89b4fa"
theme[cached_start]="#89b4fa"
theme[cached_mid]="#b4befe"
theme[cached_end]="#cba6f7"
theme[available_start]="#a6e3a1"
theme[available_mid]="#94e2d5"
theme[available_end]="#89b4fa"
theme[used_start]="#f9e2af"
theme[used_mid]="#fab387"
theme[used_end]="#f38ba8"
theme[download_start]="#a6e3a1"
theme[download_mid]="#94e2d5"
theme[download_end]="#89b4fa"
theme[upload_start]="#f9e2af"
theme[upload_mid]="#fab387"
theme[upload_end]="#f38ba8"
theme[process_start]="#89b4fa"
theme[process_mid]="#b4befe"
theme[process_end]="#cba6f7"
EOF
  fi

  if [[ ! -e "$kvantum_generated_dir/MaterialAdw.kvconfig" && -e "$kvantum_dir/Colloid/Colloid.kvconfig" ]]; then
    cp "$kvantum_dir/Colloid/Colloid.kvconfig" "$kvantum_generated_dir/MaterialAdw.kvconfig"
  fi

  if [[ ! -e "$kvantum_generated_dir/MaterialAdw.svg" && -e "$kvantum_dir/Colloid/Colloid.svg" ]]; then
    cp "$kvantum_dir/Colloid/Colloid.svg" "$kvantum_generated_dir/MaterialAdw.svg"
  fi
}
