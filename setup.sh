#!/usr/bin/env bash

# configure a Fedora machine w/ the GNOME desktop to my preferences.

# log stdout, stderr to file
log_to_file=1
log_file="setup.sh.log"

# hostnames by S/N
set_hostname=1

declare -A serial_numbers

serial_numbers["PF570W6B"]="wp14sg5i" # P14s Gen 5 U7 155H A500
serial_numbers["PW00LM1M"]="wp1g4i" # P1 Gen 4 i7-11800H A2000
serial_numbers["PF3873HS"]="wt14g2a" # T14 Gen 2 R7 5850U
serial_numbers["PC1X701X"]="wt14sg1a" # T14s Gen 1 R7 4750U
serial_numbers["PC0Y9G25"]="wt480s" # good old T480s i5-8350U

serial_numbers["MJ09DZNB"]="m920q0" # m920q #1 i5-8600T
serial_numbers["MJ09DZR1"]="m920q1" # m920q #2 i5-8600T
serial_numbers["MJ08LQZS"]="m715q0" # m715q R5 2400GE
serial_numbers["MJ00KMJZ"]="e320" # e32 #1 i7-4790
serial_numbers["MXL9293DBY"]="800g4m0" # elitedesk 800g4 mini i5-8500
serial_numbers["79T6YN2"]="3060t0" # optiplex 3060 tower i5-8500

# flatpak app IDs to be installed
install_flatpaks=1
flatpak_apps=(
    com.spotify.Client # spotify music player
    com.discordapp.Discord # discord chat app
    com.valvesoftware.Steam # steam game launcher
    md.obsidian.Obsidian # obsidian markdown editor
    com.jgraph.drawio.desktop # draw.io diagram editor
)

# rpm packages to be installed with dnf
install_rpm_packages=1
rpm_packages=(
    powertop # power usage overview utility
    btop # fancy top
    fastfetch # the fastfetch vanity thingy
    gh # the github cli utility
    remmina # the remmina remote desktop connection manager
    jetbrains-mono-fonts-all # the jetbrains mono font family
    rsms-inter-fonts # the inter sans-serif font family
    wine # the Wine Windows compatibility layer
    hugo # the Hugo static site generator
    neovim # the neovim text editor
)

# dnf groups to be group installed
install_dnf_groups=1
dnf_groups=(
    development-tools
)

# enable rpmfusion?
enable_rpmfusion=1

# automatically detect graphics hardware (to install appropriate drivers) via lspci?
# overrides below will trigger relevant section regardless of this setting
autodetect_graphics_hardware=1

# install Nvidia driver and media codecs? Depends on RPMFusion
install_nvidia_driver=0

# array of packages to install when Nvidia graphics are detected or Nvidia flag set
# akmod will build the kernel module
# verify it's completed with modinfo -F version nvidia 
# see:
# https://rpmfusion.org/Howto/NVIDIA#Current_GeForce.2FQuadro.2FTesla
# https://rpmfusion.org/Howto/Optimus
# https://www.reddit.com/r/Fedora/comments/18bj1kt/fedora_nvidia_secure_boot/
nvidia_rpm_packages=(
    gcc # dependency
    kernel-headers # dependency
    kernel-devel # dependency
    akmod-nvidia
    xorg-x11-drv-nvidia # driver
    xorg-x11-drv-nvidia-libs # dependency
    xorg-x11-drv-nvidia-libs.i686 # dependency
    libva-nvidia-driver # media accel
)

# install Intel media codecs?
install_intel_driver=0

# array of packages to install when Intel graphics are detected or Intel flag set
intel_rpm_packages=(
    intel-media-driver
)

# install 1password?
install_1password=1

# install vscode from repository?
install_vscode_rpm=1

# set window titlebar button settings?
set_button_layout=1

# set fonts?
set_system_fonts=1

interface_font='Inter 11'
document_font="$interface_font"
monospace_font='JetBrains Mono 11'

# change font antialiasing from default (greyscale)
# to rgba (subpixel)? Subpixel looks better on RGB LCDs
set_font_antialiasing=1

# swap ffmpeg-free for full-fat ffmpeg?
swap_ffmpeg=1

# call grubby to disable the pretty splash screen?
disable_quiet_boot=1

# disable mouse acceleration?
disable_mouse_accel=1

# wrapper to set key and print new state to console
set_gsettings_key() {

    local path=$1
    local key=$2
    local new_value=$3

    local path_abbreviation=$(echo "$path" | sed -E 's/\b([a-z])[a-z]*\.?/\1./g' | sed -E 's/\.$//')

    local current_value=$(gsettings get "$path" "$key" | sed "s/'//g")

    if [[ "$current_value" != "$new_value" ]]; then

        echo -e "\e[93mExisting ${path_abbreviation} property '${key}' is '${current_value}'"
        echo -e "Not requested value '${new_value}'.\e[0m"

        echo "Setting ${path_abbreviation} property '${key}' to '${new_value}'"

        gsettings set "$path" \
            "$key" "$new_value"

        echo "${path_abbreviation} property '${key}' is now:"

        gsettings get "$path" "$key"

    else

        echo "Existing ${path_abbreviation} property '${key}' is '${current_value}'."

        echo -e "\e[32m${key} matches requested '${new_value}'. No changes will be made.\e[0m"

    fi

}

echo "Beginning setup.sh."

if [[ "$log_to_file" -eq 1 ]]; then

    echo "This script's output will be written to ${log_file}."

    exec > >(tee -a "$log_file") 2>&1

    echo

fi

if [[ "$set_hostname" -eq 1 ]]; then

    echo "Setting system hostname."

    existing_hostname=$(hostname)

    system_serial=$(sudo dmidecode -s chassis-serial-number)

    hostname=${serial_numbers["$system_serial"]}

    if [[ "$existing_hostname" = "$hostname" ]]; then

        echo -e "\e[32mDesired hostname ${existing_hostname} is already set. No changes were made.\e[0m"

    elif [[ ! "$hostname" ]]; then

        echo -e "\e[91mDesired hostname not found in hashtable by S/N ${system_serial}. No changes will be made.\e[0m"

    else

        echo -e "\e[93mChanging system hostname from '${existing_hostname}' to desired '${hostname}'.\e[0m"

        sudo hostnamectl set-hostname "$hostname"

        echo "System hostname set to: $(hostname)"

    fi

    echo

fi

# enable rpmfusion repositories
# https://docs.fedoraproject.org/en-US/quick-docs/rpmfusion-setup/
if [[ "$enable_rpmfusion" -eq 1 ]]; then

    echo "Enabling rpmfusion free and nonfree repos..."

    # enable the rpmfusion 'free' repo
    sudo dnf install -y \
      https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm

    echo "Enabled rpmfusion 'free' repo."

    # enable the rpmfusion 'nonfree' repo
    sudo dnf install -y \
      https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
    
    echo "Enabled rpmfusion 'nonfree' repo."

    echo

fi

# install 1Password, my preferred password manager
# todo: do only if needed
if [[ "$install_1password" -eq 1 ]]; then

    echo "Adding 1Password repo..."
    
    # add key for the yum repo
    sudo rpm --import https://downloads.1password.com/linux/keys/1password.asc

    # add the 1PW repo
    sudo echo -e "[1password]\nname=1Password Stable Channel\nbaseurl=https://downloads.1password.com/linux/rpm/stable/\$basearch\nenabled=1\ngpgcheck=1\nrepo_gpgcheck=1\ngpgkey=\"https://downloads.1password.com/linux/keys/1password.asc\"" \
    | sudo tee /etc/yum.repos.d/1password.repo
    
    echo "Installing 1Password RPM..."

    # install 1PW
    sudo dnf install -y 1password
    
    echo "Done installing 1Password."
    
    echo

fi

# install VSCode
if [[ "$install_vscode_rpm" -eq 1 ]]; then

    echo "Adding VSCode repo..."

    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
    echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\nautorefresh=1\ntype=rpm-md\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/vscode.repo > /dev/null
    
    echo "Installing VSCode..."

    dnf check-update
    sudo dnf install -y code # or code-insiders
    
    echo "Done installing VSCode."

    echo

fi

# install flatpaks
if [[ "$install_flatpaks" -eq 1 ]]; then

    echo "beginning to install flatpaks ${flatpak_apps[@]}"
    # determine what is already installed - just for fun

    mapfile -t installed_apps < <(flatpak list --app --columns=application)
    apps_to_install=()

    for app in "${flatpak_apps[@]}"; do
        
        if [[ "${installed_apps[@]}" =~ "$app" ]]; then
            echo "flatpak $app is already present"
        else
            apps_to_install+=("$app")
        fi
        
    done
    
    if [[ "${apps_to_install[@]}" ]]; then

        echo -e "\e[93mflatpak(s) ${apps_to_install[@]} need to be installed. Working...\e[0m"

        # install missing flatpaks
        flatpak install -y "${apps_to_install[@]}"
    
        echo "Done installing flatpaks."

    else
        
        echo -e "\e[32mNo flatpaks are pending installation.\e[0m No changes were made."

    fi

    echo

fi

# install individual RPMs with dnf - just let dnf handle stuff that's already here
if [[ "$install_rpm_packages" -eq 1 ]]; then

    sudo dnf install -y "${rpm_packages[@]}"

    echo
    
fi

if [[ "$autodetect_graphics_hardware" -eq 1 ]]; then

    graphics=$(lspci | grep -i vga)

    case "$graphics" in
        *NVIDIA*)
            echo "\e[32mDetected Nvidia graphics\e[0m devices in this system."
            install_nvidia_driver=1
            ;;
        *AMD*   )
            echo -e "\e[31mDetected AMD graphics\e[0m devices in this system."
            install_amd_driver=1
            ;;
        *Intel* )
            echo -e "\e[34mDetected Intel graphics\e[0m devices in this system."
            install_intel_driver=1
            ;;
        *)
            echo -e "\e[35mUnhandled graphics hardware detected\e[0m - no changes will be made."
            ;;
    esac

    echo

fi

if [[ "$install_nvidia_driver" -eq 1 ]]; then

    echo "Installing Nvidia driver & media codec packages..."

    sudo dnf install -y "${nvidia_driver_packages[@]}"

    echo   

fi

if [[ "$install_intel_driver" -eq 1 ]]; then

    echo "Installing Intel driver & media codec packages..."

    sudo dnf install -y "${intel_driver_packages[@]}"

    echo

fi

# swap ffmpeg-free for full-fat ffmpeg
if [[ "$swap_ffmpeg" -eq 1 ]]; then

    echo "Replacing ffmpeg-free package with normal ffmpeg..."

    sudo dnf swap ffmpeg-free ffmpeg --allowerasing -y
    
    sudo dnf update @multimedia --setopt="install_weak_deps=False" --exclude=PackageKit-gstreamer-plugin -y

    echo "Done replacing ffmpeg."

    echo
    
fi

# use the gsettings utility to set Gnome registry keys for my preferred interface fonts
if [[ "$set_system_fonts" -eq 1 ]]; then

    echo "Setting system fonts..."
    
    # wrapper for set_gsettings_key with constant path
    set_font() {

        local key=$1
        local value=$2

        set_gsettings_key "org.gnome.desktop.interface" "$1" "$2"

    }

    for key in font-name document-font-name; do

        set_font "$key" "$interface_font"

    done;

    set_font monospace-font-name "$monospace_font"
    
    echo "Done modifying system fonts."

    echo
 
fi

if [[ "$disable_mouse_accel" -eq 1 ]]; then

    echo "Setting mouse acceleration profile to 'flat'..."

    set_gsettings_key \
        "org.gnome.desktop.peripherals.mouse" \
        "accel-profile" \
        "flat"
    
    echo

fi

# use the gsettings utility to set Gnome registry key for window control buttons
if [[ "$set_button_layout" -eq 1 ]]; then

    echo "Setting GNOME window titlebar button layout..."

    set_gsettings_key \
        "org.gnome.desktop.wm.preferences" \
        "button-layout" \
        "appmenu:minimize,maximize,close"

    echo
    
fi

if [[ "$set_font_antialiasing" -eq 1 ]]; then

    echo "Enabling subpixel antialiasing..."

    set_gsettings_key \
        "org.gnome.desktop.interface" \
        "font-antialiasing" \
        "rgba"

    echo

fi

if [[ "$disable_quiet_boot" -eq 1 ]]; then
    
    quiet_boot_args_set=$(sudo grubby --info=ALL | grep -i quiet)

    rhgb_boot_args_set=$(sudo grubby --info=ALL | grep -i rhgb)

    if [[ "$quiet_boot_args_set" != '' ]]; then
    
        echo -e "\e[93mQuiet boot is set. Disabling quiet boot...\e[0m"

        echo "Existing kernel args:"

        sudo grubby --info=ALL | grep -oP 'args="\K[^"]+'

        sudo grubby --update-kernel=ALL --remove-args='quiet'

        echo "New kernel args:"

        sudo grubby --info=ALL | grep -oP 'args="\K[^"]+'

        echo "\e[32mDone disabling quiet boot.\e[0m"

    else

        echo -e "\e[32mQuiet boot is already disabled - no action required.\e[0m Kernel args are:"

        sudo grubby --info=ALL | grep -oP 'args="\K[^"]+'

    fi

    if [[ "$rhgb_boot_args_set" != '' ]]; then

        echo -e "\e[93mRHGB is set. Disabling RHGB...\e[0m"

        echo "Existing kernel args:"

        sudo grubby --info=ALL | grep -oP 'args="\K[^"]+'

        sudo grubby --update-kernel=ALL --remove-args='rhgb'

        echo "New kernel args:"

        sudo grubby --info=ALL | grep -oP 'args="\K[^"]+'

        echo "\e[32mDone disabling RHGB.\e[0m"

    else

        echo -e "\e[32mRHGB is already disabled - no action required.\e[0m Kernel args are:"

        sudo grubby --info=ALL | grep -oP 'args="\K[^"]+'

    fi

    echo
   
fi

# disable systemd-resolved
# https://wporter.org/disabling-systemd-resolved-and-letting-networkmanager-control-/etc/resolv.conf-on-fedora-40/

if [[ "$disable_resolved" -eq 1 ]]; then

    echo "Disabling systemd-resolved..."
        
    echo "Masking resolved service..."
    
    # disable resolved
    sudo systemctl stop systemd-resolved
    sudo systemctl mask systemd-resolved
    
    echo "Editing NetworkManager.conf to enable it to manage DNS..."

    # remove anything ^dns= then
    # insert the "dns=default" line in [main] section
    sudo sed -i -e '/^dns=/d' \
        -e '/\[main\]/a dns=default' \
        /etc/NetworkManager/NetworkManager.conf
    
    echo "Removing resolv.conf and restarting NetworkManager..."
    
    # clean out resolv config so NM will edit it
    sudo rm /etc/resolv.conf
    # restart NM to make it reread config
    sudo systemctl restart NetworkManager
    
    echo "Done! Resolved has been disabled."

    echo
    
fi

# TODO stop this from trying to install when already installed
if [[ "$install_dnf_groups" -eq 1 ]]; then

    for group in "${dnf_groups[@]}"; do

        echo "Installing dnf group $group..."
        
        sudo dnf group install "$group" -y

        echo
        
    done

fi

echo "setup.sh completed."
