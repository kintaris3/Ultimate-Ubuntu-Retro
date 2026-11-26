#!/usr/bin/env bash

# Colors for terminal readability
BOLD='\033[1m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_banner() {
    clear
    cat << "BANNER_EOF"
 _   _ _ _   _                 _       
| | | | | |_(_)_ __ ___   __ _| |_ ___ 
| | | | | __| | '_ ` _ \ / _` | __/ _ \
| |_| | | |_| | | | | | | (_| | ||  __/
 \___/|_|\__|_|_| |_| |_|\__,_|\__\___|
  _   _ _                 _         ____      _             
 | | | | |__  _   _ _ __ | |_ _   _|  _ \ ___| |_ _ __ ___  
 | | | | '_ \| | | | '_ \| __| | | | |_) / _ \ __| '__/ _ \ 
 | |_| | |_) | |_| | | | | |_| |_| |  _ <  __/ |_| | | (_) |
  \___/|_.__/ \__,_|_| |_|\__|\__,_|_| \_\___|\__|_|  \___/ 
                                                            
        /\_/\
       ( o.o )   "Insert coin! Let's build your arcade."
        > ^ <

        Code written by Christopher G. Pitts Jr.
BANNER_EOF
    echo ""
}

pause_prompt() {
    echo ""
    read -p "Press Enter to return to the Retro Menu..."
}

ensure_flatpak() {
    if ! command -v flatpak &> /dev/null; then
        echo -e "${CYAN}--> Installing Flatpak & Flathub support...${NC}"
        sudo apt update && sudo apt install -y flatpak gnome-software-plugin-flatpak
    fi
    sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
}

# Detect hardware specs & suggest an emulation tier
detect_hardware_tier() {
    CPU_CORES=$(nproc)
    RAM_GB=$(free -g | awk '/^Mem:/{print $2}')
    GPU_LINE=$(lspci | grep -iE 'vga|3d|display' | head -n 1 | sed 's/.*: //')

    if echo "$GPU_LINE" | grep -iqE 'nvidia|radeon rx|radeon r9|arc|iris xe'; then
        HAS_GOOD_GPU=1
    else
        HAS_GOOD_GPU=0
    fi

    if [ "$CPU_CORES" -ge 4 ] && [ "$RAM_GB" -ge 7 ] && [ "$HAS_GOOD_GPU" -eq 1 ]; then
        REC_TIER="High Tier (All Systems up to PS2 / GameCube / Wii)"
    elif [ "$CPU_CORES" -ge 4 ] && [ "$RAM_GB" -ge 6 ]; then
        REC_TIER="Mid Tier (8-bit to 64-bit: NES/SNES/GBA + PS1/N64/PSP/DS)"
    else
        REC_TIER="Low Tier (8-bit & 16-bit Classics: NES, SNES, GB/GBA, Genesis)"
    fi
}

# --- MODULE 1: BUILD EMULATION FOLDER STRUCTURE ---
setup_folders() {
    print_banner
    echo -e "${BOLD}${CYAN}=== [1] Build Standardized Emulation Folders ===${NC}"
    echo "Creates a clean ~/Emulation folder tree so all your ROMs, BIOS files,"
    echo "and saves stay organized in one easy-to-find place."
    echo ""

    CONSOLES=(gb gbc gba nes snes n64 nds ps1 ps2 psp gamecube wii dreamcast genesis arcade)
    for sys in "${CONSOLES[@]}"; do
        mkdir -p "$HOME/Emulation/ROMs/$sys"
    done
    mkdir -p "$HOME/Emulation/BIOS" "$HOME/Emulation/Saves" "$HOME/Emulation/Screenshots"

    cat << 'README_EOF' > "$HOME/Emulation/BIOS/README_BIOS.txt"
=== EMULATION BIOS & ROM QUICK GUIDE ===

1. LEGAL NOTICE:
   Only use ROMs and BIOS files dumped from consoles and games you legally own.

2. WHICH SYSTEMS NEED BIOS FILES?
   - 8-bit & 16-bit (NES, SNES, GB/GBC/GBA, Genesis): No BIOS needed! Drop ROMs straight into ROMs/<system>.
   - PlayStation 1 (DuckStation / RetroArch): Place scph5501.bin (or region equivalent) directly in this BIOS folder.
   - PlayStation 2 (PCSX2): Place your dumped PS2 BIOS (.bin) directly in this BIOS folder.
   - Dreamcast / Sega CD: Place dc_boot.bin / bios_CD_U.bin in this BIOS folder.
   - GameCube / Wii (Dolphin) & PSP (PPSSPP): Work out of the box without BIOS files!

3. FILE FORMAT TIPS:
   - Keep cartridge ROMs zipped (.zip) or extracted (.nes, .sfc, .gba, .z64).
   - Extract disc games (.iso, .bin/.cue, or .chd) — do NOT leave disc games inside .zip files!
README_EOF

    # Grant Flatpak emulators clean access to ~/Emulation if Flatpak is present
    if command -v flatpak &> /dev/null; then
        flatpak override --user --filesystem="$HOME/Emulation" org.libretro.RetroArch 2>/dev/null || true
        flatpak override --user --filesystem="$HOME/Emulation" net.pcsx2.PCSX2 2>/dev/null || true
        flatpak override --user --filesystem="$HOME/Emulation" org.DolphinEmu.dolphin-emu 2>/dev/null || true
        flatpak override --user --filesystem="$HOME/Emulation" org.duckstation.DuckStation 2>/dev/null || true
        flatpak override --user --filesystem="$HOME/Emulation" org.ppsspp.PPSSPP 2>/dev/null || true
    fi

    echo -e "${GREEN}Folder structure created at: $HOME/Emulation${NC}"
    echo "Check ~/Emulation/BIOS/README_BIOS.txt anytime for a quick setup cheat sheet!"
}

# --- MODULE 2: TIERED EMULATOR INSTALLER ---
install_emulators() {
    detect_hardware_tier
    print_banner
    echo -e "${BOLD}${CYAN}=== [2] Install Emulators by Hardware Tier ===${NC}"
    echo -e "${YELLOW}Detected Hardware:${NC} ${CPU_CORES} CPU Threads | ${RAM_GB}GB RAM"
    echo -e "${YELLOW}GPU:${NC} ${GPU_LINE}"
    echo -e "${GREEN}Recommended for your rig:${NC} ${BOLD}${REC_TIER}${NC}"
    echo ""
    echo "  1) Low Tier  — RetroArch (8-bit & 16-bit: NES, SNES, GB/GBA, Genesis, Arcade)"
    echo "  2) Mid Tier  — RetroArch + DuckStation (PS1) + PPSSPP (PSP) + MelonDS (DS)"
    echo "  3) High Tier — Everything in Mid Tier + PCSX2 (PS2) + Dolphin (GameCube/Wii)"
    echo "  4) Custom Pick — Choose individual emulators one by one"
    echo "  5) Return to Main Menu"
    echo ""
    read -p "Select an option [1-5]: " TIER_CHOICE

    case $TIER_CHOICE in
        1)
            sudo -v
            ensure_flatpak
            echo -e "\n${CYAN}--> Installing Low Tier Pack (RetroArch)...${NC}"
            flatpak install -y flathub org.libretro.RetroArch
            flatpak override --user --filesystem="$HOME/Emulation" org.libretro.RetroArch
            echo -e "${GREEN}Low Tier installation complete!${NC}"
            ;;
        2)
            sudo -v
            ensure_flatpak
            echo -e "\n${CYAN}--> Installing Mid Tier Pack (RetroArch, DuckStation, PPSSPP, MelonDS)...${NC}"
            flatpak install -y flathub org.libretro.RetroArch org.duckstation.DuckStation org.ppsspp.PPSSPP net.kuribo64.melonDS
            flatpak override --user --filesystem="$HOME/Emulation" org.libretro.RetroArch
            flatpak override --user --filesystem="$HOME/Emulation" org.duckstation.DuckStation
            flatpak override --user --filesystem="$HOME/Emulation" org.ppsspp.PPSSPP
            echo -e "${GREEN}Mid Tier installation complete!${NC}"
            ;;
        3)
            sudo -v
            ensure_flatpak
            echo -e "\n${CYAN}--> Installing High Tier Pack (All Retro + PS2 + GameCube/Wii)...${NC}"
            flatpak install -y flathub org.libretro.RetroArch org.duckstation.DuckStation org.ppsspp.PPSSPP net.kuribo64.melonDS net.pcsx2.PCSX2 org.DolphinEmu.dolphin-emu
            for app in org.libretro.RetroArch org.duckstation.DuckStation org.ppsspp.PPSSPP net.pcsx2.PCSX2 org.DolphinEmu.dolphin-emu; do
                flatpak override --user --filesystem="$HOME/Emulation" "$app"
            done
            echo -e "${GREEN}High Tier installation complete!${NC}"
            ;;
        4)
            sudo -v
            ensure_flatpak
            echo ""
            read -p "Install RetroArch (Multi-System)? [Y/n]: " P_RA
            read -p "Install DuckStation (PlayStation 1)? [Y/n]: " P_PS1
            read -p "Install PPSSPP (PSP)? [Y/n]: " P_PSP
            read -p "Install MelonDS (Nintendo DS)? [Y/n]: " P_NDS
            read -p "Install PCSX2 (PlayStation 2)? [y/N]: " P_PS2
            read -p "Install Dolphin (GameCube & Wii)? [y/N]: " P_GC

            [[ "${P_RA:-Y}" =~ ^[Yy]$ ]] && flatpak install -y flathub org.libretro.RetroArch && flatpak override --user --filesystem="$HOME/Emulation" org.libretro.RetroArch
            [[ "${P_PS1:-Y}" =~ ^[Yy]$ ]] && flatpak install -y flathub org.duckstation.DuckStation && flatpak override --user --filesystem="$HOME/Emulation" org.duckstation.DuckStation
            [[ "${P_PSP:-Y}" =~ ^[Yy]$ ]] && flatpak install -y flathub org.ppsspp.PPSSPP && flatpak override --user --filesystem="$HOME/Emulation" org.ppsspp.PPSSPP
            [[ "${P_NDS:-Y}" =~ ^[Yy]$ ]] && flatpak install -y flathub net.kuribo64.melonDS
            [[ "${P_PS2:-N}" =~ ^[Yy]$ ]] && flatpak install -y flathub net.pcsx2.PCSX2 && flatpak override --user --filesystem="$HOME/Emulation" net.pcsx2.PCSX2
            [[ "${P_GC:-N}" =~ ^[Yy]$ ]] && flatpak install -y flathub org.DolphinEmu.dolphin-emu && flatpak override --user --filesystem="$HOME/Emulation" org.DolphinEmu.dolphin-emu
            echo -e "${GREEN}Custom emulator selection complete!${NC}"
            ;;
        *)
            return 0
            ;;
    esac
}

# --- MODULE 3: CONTROLLER & GAMEPAD SETUP ---
setup_controllers() {
    print_banner
    echo -e "${BOLD}${CYAN}=== [3] Controller & Gamepad Setup ===${NC}"
    echo "Installs official controller udev rules (PlayStation, Xbox, Switch Pro, 8BitDo)"
    echo "so controllers work via USB and Bluetooth without permission issues, plus a"
    echo "visual button tester (jstest-gtk)."
    echo ""
    sudo -v
    echo -e "${CYAN}--> Installing steam-devices udev rules & jstest-gtk...${NC}"
    sudo apt update && sudo apt install -y steam-devices jstest-gtk
    sudo udevadm control --reload-rules && sudo udevadm trigger

    echo ""
    read -p "Apply Xbox Wireless Bluetooth ERTM fix (helps older Xbox controllers pair)? [Y/n]: " XBOX_FIX
    if [[ "${XBOX_FIX:-Y}" =~ ^[Yy]$ ]]; then
        echo "options bluetooth disable_ertm=Y" | sudo tee /etc/modprobe.d/xbox_bt.conf > /dev/null
        echo -e "${GREEN}Xbox Bluetooth ERTM tweak applied (takes effect on reboot).${NC}"
    fi

    echo -e "\n${GREEN}Controller support ready! Launch 'jstest-gtk' anytime to test buttons.${NC}"
}

# --- MODULE 4: GRAPHICS, VULKAN & PERFORMANCE CHECK ---
check_graphics() {
    print_banner
    echo -e "${BOLD}${CYAN}=== [4] Graphics, Vulkan & GameMode Check ===${NC}"
    sudo -v
    echo -e "${CYAN}--> Installing Vulkan diagnostic tools & Feral GameMode...${NC}"
    sudo apt update && sudo apt install -y vulkan-tools gamemode

    echo -e "\n${YELLOW}--- GPU & Vulkan Summary ---${NC}"
    if command -v vulkaninfo &> /dev/null; then
        vulkaninfo --summary 2>/dev/null | grep -E "deviceName|driverName|apiVersion" || echo "Vulkan summary unavailable on this GPU (OpenGL will be used)."
    fi

    echo -e "\n${YELLOW}--- GameMode Status ---${NC}"
    if systemctl --user is-active --quiet gamemoded 2>/dev/null || command -v gamemoderun &> /dev/null; then
        echo -e "${GREEN}GameMode is installed and ready!${NC}"
    fi
}

# --- MODULE 5: OPTIONAL PC GAME LAUNCHERS ---
install_launchers() {
    print_banner
    echo -e "${BOLD}${CYAN}=== [5] Optional PC Gaming Launchers ===${NC}"
    echo "Want modern PC games alongside your retro library? Pick any launchers to add:"
    echo ""
    read -p "Install Steam? [y/N]: " L_STEAM
    read -p "Install Heroic Games Launcher (Epic, GOG, Amazon)? [y/N]: " L_HEROIC
    read -p "Install Lutris (Windows & Classic PC Games)? [y/N]: " L_LUTRIS
    read -p "Install ProtonUp-Qt (Easy Proton-GE manager)? [y/N]: " L_PROTON

    sudo -v
    if [[ "$L_STEAM" =~ ^[Yy]$ ]]; then
        sudo dpkg --add-architecture i386
        sudo apt update && sudo apt install -y steam-installer
    fi

    if [[ "$L_HEROIC" =~ ^[Yy]$ ]] || [[ "$L_LUTRIS" =~ ^[Yy]$ ]] || [[ "$L_PROTON" =~ ^[Yy]$ ]]; then
        ensure_flatpak
        [[ "$L_HEROIC" =~ ^[Yy]$ ]] && flatpak install -y flathub com.heroicgameslauncher.hgl
        [[ "$L_LUTRIS" =~ ^[Yy]$ ]] && flatpak install -y flathub net.lutris.Lutris
        [[ "$L_PROTON" =~ ^[Yy]$ ]] && flatpak install -y flathub net.davidotek.pupgui2
    fi

    echo -e "\n${GREEN}PC gaming launcher setup complete!${NC}"
}

# --- MAIN MENU LOOP ---
while true; do
    print_banner
    echo -e "${BOLD}${CYAN}Select an Ultimate Ubuntu Retro Module:${NC}"
    echo "  1) Build Standardized ~/Emulation Folders & BIOS Guide"
    echo "  2) Install Emulators (Auto-Detects Specs -> Low / Mid / High Tiers)"
    echo "  3) Controller & Gamepad Setup (USB/Bluetooth Rules & Tester)"
    echo "  4) Graphics, Vulkan & Performance Check (GameMode)"
    echo "  5) Optional PC Gaming Launchers (Steam, Heroic, Lutris, ProtonUp-Qt)"
    echo "  6) Exit"
    echo ""
    read -p "Enter your choice [1-6]: " CHOICE

    case $CHOICE in
        1) setup_folders; pause_prompt ;;
        2) install_emulators; pause_prompt ;;
        3) setup_controllers; pause_prompt ;;
        4) check_graphics; pause_prompt ;;
        5) install_launchers; pause_prompt ;;
        6)
            echo "Exiting Ultimate Ubuntu Retro. Game on!"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option. Please enter 1-6.${NC}"
            sleep 1
            ;;
    esac
done
