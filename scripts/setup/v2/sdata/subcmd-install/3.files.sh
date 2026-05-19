# Shell installation for niri-caelestia-shell
echo -e "${STY_CYAN}Building and installing the shell...${STY_RST}"

# 1. Ensure Target Directories
mkdir -p "$XDG_CONFIG_HOME/quickshell/niri-caelestia-shell"
mkdir -p "$XDG_STATE_HOME/quickshell/user/generated/terminal"
mkdir -p "$XDG_STATE_HOME/quickshell/user/generated/wallpaper"
mkdir -p "$HOME/Pictures/Wallpapers"

# 2. Install & Build Shell Code
echo -e "${STY_BLUE}Building and installing shell...${STY_RST}"
TARGET_DIR="$XDG_CONFIG_HOME/quickshell/niri-caelestia-shell"

# Copy local repository files to target directory
cp -rf "$REPO_ROOT"/* "$TARGET_DIR/"

# Move into target directory for the build
cd "$TARGET_DIR"

# Build process
echo -e "  ${STY_DIM}Configuring with CMake (Ninja)...${STY_RST}"
v cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/

echo -e "  ${STY_DIM}Compiling...${STY_RST}"
v cmake --build build

echo -e "  ${STY_DIM}Installing to system...${STY_RST}"
v sudo cmake --install build

# 3. Copy Wallpapers
echo -e "${STY_BLUE}Copying wallpapers to ~/Pictures/Wallpapers/...${STY_RST}"
if [[ -d "$TARGET_DIR/images/Wallpapers" ]]; then
  cp -rf "$TARGET_DIR/images/Wallpapers"/* "$HOME/Pictures/Wallpapers/"
fi

# 4. Specialized Font Installer (Google Sans Flex)
install_google_sans_flex(){
  local src_url="https://github.com/end-4/google-sans-flex"
  local target_dir="${XDG_DATA_HOME}/fonts/google-sans-flex"
  if fc-list | grep -qi "Google Sans Flex"; then return; fi
  
  echo -e "${STY_CYAN}Downloading Google Sans Flex...${STY_RST}"
  local tmp=$(mktemp -d)
  git clone --depth 1 "$src_url" "$tmp"
  mkdir -p "$target_dir"
  cp -rf "$tmp"/* "$target_dir/"
  fc-cache -f "$target_dir"
  rm -rf "$tmp"
}
install_google_sans_flex

# Return to the original setup directory
cd - > /dev/null

echo -e "${STY_GREEN}Shell installation complete!${STY_RST}"
