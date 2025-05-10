#!/bin/bash

# configure a Fedora machine w/ the GNOME desktop to my preferences.

# log stdout, stderr to file
log_to_file=1
log_file="setup.sh.log"

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

# swap ffmpeg-free for full-fat ffmpeg?
swap_ffmpeg=1

# call grubby to disable the pretty splash screen?
disable_quiet_boot=1

# disable mouse acceleration?
disable_mouse_accel=1

echo "beginning setup.sh."

if [[ "$log_to_file" ]]; then
    echo "this script's output will be logged to $log_file."
    exec > >(tee -a "$log_file") 2>&1
fi

# enable rpmfusion repositories
# https://docs.fedoraproject.org/en-US/quick-docs/rpmfusion-setup/
if [[ "$enable_rpmfusion" ]]; then

    echo "enabling rpmfusion free & nonfree repos..."

    # enable the rpmfusion 'free' repo
    sudo dnf install -y \
      https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm

    echo "Enabled rpmfusion 'free' repo."

    # enable the rpmfusion 'nonfree' repo
    sudo dnf install -y \
      https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
    
    echo "Enabled rpmfusion 'nonfree' repo."

fi

echo

# install 1Password, my preferred password manager
# todo: do only if needed
if [[ "$install_1password" ]]; then

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

fi

echo

# install VSCode
if [[ "$install_vscode_rpm" ]]; then

    echo "Adding VSCode repo..."

    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
    echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\nautorefresh=1\ntype=rpm-md\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/vscode.repo > /dev/null
    
    echo "Installing VSCode..."

    dnf check-update
    sudo dnf install code # or code-insiders
    
    echo "Done installing VSCode."

fi

echo

# install flatpaks
if [[ "$install_flatpaks" ]]; then

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

        echo "flatpaks ${apps_to_install[@]} need to be installed. Working..."

        # install missing flatpaks
        flatpak install -y "${apps_to_install[@]}"
    
        echo "Done installing Flatpaks."

    else
        
        echo "No Flatpaks are pending installation. No changes were made."

    fi

fi

# install individual RPMs with dnf - just let dnf handle stuff that's already here
if [[ "$install_rpm_packages" ]]; then

    sudo dnf install -y "${rpm_packages[@]}"
    
fi

if [[ "$install_nvidia_driver" ]]; then

    sudo dnf install -y "${nvidia_driver_packages[@]}"    

fi

if [[ "$install_intel_driver" ]]; then

    sudo dnf install -y "${intel_driver_packages[@]}"

fi

# swap ffmpeg-free for full-fat ffmpeg
if [[ "$swap_ffmpeg" ]]; then

    sudo dnf swap ffmpeg-free ffmpeg --allowerasing -y
    
    sudo dnf update @multimedia --setopt="install_weak_deps=False" --exclude=PackageKit-gstreamer-plugin -y
    
fi

# use the gsettings utility to set Gnome registry keys for my preferred interface fonts
if [[ "$set_system_fonts" ]]; then

    echo "Setting system fonts..."
    
    for key in font-name document-font-name; do
	
	echo "Setting o.g.d.i key ${key} to font ${interface_font}"

        gsettings set org.gnome.desktop.interface \
            "$key" "$interface_font"

	echo "o.g.d.i key ${key} is now:"
	gsettings get org.gnome.desktop.interface "$key"	

    done;

    echo "Setting o.g.d.i key monospace-font-name to font ${monospace_font}"
    
    gsettings set org.gnome.desktop.interface \
        monospace-font-name "$monospace_font"

    echo "o.g.d.i key monospace-font-name is now set to:"
    
    gsettings get org.gnome.desktop.interface monospace-font-name
    
    echo "Done modifying system fonts."
 
fi

if [[ "$disable_mouse_accel" ]]; then

    echo "Setting mouse acceleration profile to 'flat'..."
    
    gsettings set org.gnome.desktop.peripherals.mouse \
        accel-profile 'flat'

    echo "Set mouse acceleration profile to:"

    gsettings get org.gnome.desktop.peripherals.mouse accel-profile
        
fi

# use the gsettings utility to set Gnome registry key for window control buttons
if [[ "$set_button_layout" ]]; then

    echo "Setting GNOME window titlebar buttons..."

    gsettings set org.gnome.desktop.wm.preferences \
        button-layout "appmenu:minimize,maximize,close"
    
    echo "Set GNOME window titlebar button layout to:"

    gsettings get org.gnome.desktop.wm.preferences button-layout
    
fi

if [[ "$disable_quiet_boot" ]]; then
    
    echo "Disabling quiet boot..."
    
    sudo grubby --update-kernel=ALL --remove-args='quiet'

    echo "New kernel args:"

    sudo grubby --info=ALL | grep -oP 'args="\K[^"]+' 
    
fi

# disable systemd-resolved
# https://wporter.org/disabling-systemd-resolved-and-letting-networkmanager-control-/etc/resolv.conf-on-fedora-40/

if [[ "$disable_resolved" ]]; then

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
    
fi

# TODO stop this from trying to install when already installed
if [[ "$install_dnf_groups" ]]; then

    for group in "${dnf_groups[@]}"; do

        echo "Installing dnf group $group..."
        
        sudo dnf group install "$group" -y
        
    done

fi

echo "setup.sh completed."
