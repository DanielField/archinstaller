#!/bin/bash

timedatectl set-ntp true 

# Install dialog for TUI
pacman -Syy dialog

modprobe dm-crypt
modprobe dm-mod
modprobe dm-thin-pool

# List available devices and allow user to select one for partitioning
devices=$(lsblk -dno NAME,SIZE | awk '{print $1 " " $2 " off"}')
TGTDEV=$(dialog --title "Select Device for Partitioning" --radiolist "Choose a device:" 15 60 4 $devices 3>&1 1>&2 2>&3 3>&-)
TGTDEV="/dev/$TGTDEV"
clear

# Prompt for hostname
myhostname=$(dialog --title "Hostname" --inputbox "Enter a hostname for your system:" 8 40 3>&1 1>&2 2>&3 3>&-)
clear

# Prompt for root password
rootpassword=$(dialog --title "Root Password" --passwordbox "Create a root password:" 8 40 3>&1 1>&2 2>&3 3>&-)
clear

# Prompt for username
myusername=$(dialog --title "User Account" --inputbox "What would you like your username to be?" 8 40 3>&1 1>&2 2>&3 3>&-)
clear

# Prompt for user password
mypassword=$(dialog --title "User Password" --passwordbox "Create a password for $myusername:" 8 40 3>&1 1>&2 2>&3 3>&-)
clear

# Prompt for LVM usage
use_lvm=$(dialog --title "Use LVM" --yesno "Would you like to use LVM (Logical Volume Manager)?" 7 60 3>&1 1>&2 2>&3 3>&-)
use_lvm=$([ "$?" == "0" ] && echo "y" || echo "n")
clear

# Kernel selection using dialog
kernelpackage=$(dialog --title "Kernel Selection" --checklist "Choose your desired kernels:" 15 60 6 \
1 "linux (Standard Kernel)" on \
2 "linux-lts (Long Term Support Kernel)" off \
3 "linux-hardened (Security-focused Kernel)" off \
4 "linux-zen (Optimized for Desktop)" off \
5 "linux-rt (Real-Time Kernel)" off \
6 "linux-rt-lts (Real-Time Long Term Support Kernel)" off 3>&1 1>&2 2>&3 3>&-)
clear

# Convert selected options to actual package names
IFS=' ' read -r -a selected_kernels <<< "$kernelpackage"
kernelpackage=""
for kernel in "${selected_kernels[@]}"; do
    case $kernel in
        1) kernelpackage+="linux " ;;
        2) kernelpackage+="linux-lts " ;;
        3) kernelpackage+="linux-hardened " ;;
        4) kernelpackage+="linux-zen " ;;
        5) kernelpackage+="linux-rt " ;;
        6) kernelpackage+="linux-rt-lts " ;;
    esac
done

# CPU microcode installation choice
ucodepackage=$(dialog --title "CPU Microcode Installation" --menu "Choose the CPU microcode to install:" 10 60 3 \
1 "Intel microcode (intel-ucode)" \
2 "AMD microcode (amd-ucode)" \
3 "Skip microcode installation" 3>&1 1>&2 2>&3 3>&-)
clear

# Xorg installation choice
xorgchoice=$(dialog --title "Xorg Installation" --menu "Choose if you want to install Xorg:" 15 60 3 \
1 "Install Xorg" \
2 "Do not install Xorg" 3>&1 1>&2 2>&3 3>&-)
clear

# Video driver selection
videodriver=$(dialog --title "Video Driver Selection" --menu "Choose your video driver:" 15 60 6 \
1 "NVIDIA" \
2 "AMD" \
3 "Intel" \
4 "VESA (generic)" \
5 "VMware" \
6 "VirtualBox" 3>&1 1>&2 2>&3 3>&-)
clear

# Desktop environment selection
desktopenv=$(dialog --title "Desktop Environment" --menu "Select a desktop environment:" 15 60 8 \
1 "XFCE" \
2 "GNOME" \
3 "KDE Plasma" \
4 "Budgie" \
5 "Cinnamon" \
6 "LXQT" \
7 "MATE" \
8 "None" 3>&1 1>&2 2>&3 3>&-)
clear

# Machine type selection
machine_type=$(dialog --title "Machine Type" --menu "Select the type of machine:" 15 60 5 \
1 "Physical Computer" \
2 "QEMU/KVM" \
3 "VMware" \
4 "VirtualBox" \
5 "Other VM or unknown" 3>&1 1>&2 2>&3 3>&-)
clear

# Prompt user to install yay
install_yay=$(dialog --title "Install Yay" --yesno "Do you want to install Yay? This allows you to easily install packages from the AUR." 7 60 3>&1 1>&2 2>&3 3>&-)
clear

# Timezone selection
TIMEZONE=$(dialog --title "Timezone Selection" --inputbox "Enter your timezone:" 8 40 "Australia/Brisbane" 3>&1 1>&2 2>&3 3>&-)
clear

# Locale selection
LOCALE=$(dialog --title "Locale Selection" --inputbox "Enter your locale:" 8 40 "en_AU.UTF-8" 3>&1 1>&2 2>&3 3>&-)
clear

# Charset selection
CHARSET=$(dialog --title "Charset Selection" --inputbox "Enter your charset:" 8 40 "UTF-8" 3>&1 1>&2 2>&3 3>&-)
clear

# Keymap selection
KEYMAP=$(dialog --title "Keymap Selection" --inputbox "Enter your keymap:" 8 40 "us" 3>&1 1>&2 2>&3 3>&-)
clear

# Function to round to the nearest power of two
round_to_nearest_power_of_two() {
    local x=$1
    local p=1
    while [ $x -gt $p ]; do
        p=$(( p * 2 ))
    done
    if (( p - x < x - p/2 )); then
        echo $p
    else
        echo $(( p / 2 ))
    fi
}

# Calculate swap size as half of the total RAM and round it to the nearest power of two
total_ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}') # Total RAM in KB
half_ram_mb=$((total_ram_kb / 2048)) # Convert KB to MB and divide by 2 for half
swapsize=$(round_to_nearest_power_of_two $half_ram_mb)

sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | fdisk ${TGTDEV}
  g # create GPT partition table
  n # new partition
  1 # partition number 1
    # default - start at beginning of disk 
  +512M # 512 MB efi parttion
  t # set partition type
  1 # set the type to EFI
  n # new partition
  2 # partition number 2
    # default 
  +512M # 512 MB boot parttion
  n # new partition
  3 # partion number 3
    # default, start immediately after preceding partition 
    # default, extend partition to end of disk 
  p # print the in-memory partition table
  w # write the partition table
EOF

echo "Finished creating partitions!"
fdisk -l

if [[ "$TGTDEV" == *"nvme"* || "$TGTDEV" == *"mmcblk"* ]]
then
	efipart=$TGTDEV"p1"
	bootpart=$TGTDEV"p2"
	rootpart=$TGTDEV"p3"
else
	efipart=$TGTDEV"1"
	bootpart=$TGTDEV"2"
	rootpart=$TGTDEV"3"
fi

echo "EFI partition = $efipart, boot partition = $bootpart, root partition = $rootpart"

mkfs.vfat -F32 -n "EFI" $efipart
mkfs.ext4 -L boot $bootpart

if [[ "$use_lvm" == "y" || "$use_lvm" == "Y" ]]
then
    pvcreate $rootpart
    vgcreate vg0 $rootpart
    lvcreate -L ${swapsize}M -n swap vg0
    lvcreate -l 100%FREE -n root vg0
    mkswap /dev/vg0/swap
    mkfs.ext4 -L root /dev/vg0/root
    mount /dev/vg0/root /mnt
else
    mkfs.ext4 -L root $rootpart
    mount $rootpart /mnt
fi

mkdir /mnt/boot
mount $bootpart /mnt/boot
mkdir -p /mnt/boot/efi
mount $efipart /mnt/boot/efi

if [[ "$use_lvm" == "y" || "$use_lvm" == "Y" ]]
then
    swapon /dev/vg0/swap
    chmod 0600 /dev/vg0/swap
else
    dd if=/dev/zero of=/mnt/swap bs=1M count=$swapsize
    mkswap /mnt/swap
    swapon /mnt/swap
    chmod 0600 /mnt/swap
fi

# Add lvm2 to HOOKS in mkinitcpio.conf
arch-chroot /mnt /bin/bash -c "sed -i '/^HOOKS=/ s/block/block lvm2/' /etc/mkinitcpio.conf"

# Regenerate initramfs
arch-chroot /mnt mkinitcpio -P

# Enable parallel downloads in the installer
sed -i "s/#ParallelDownloads = 5/ParallelDownloads = 5/" /etc/pacman.conf

echo "Installing packages..."
pacman -Syy
pacstrap /mnt base base-devel efibootmgr grub $kernelpackage linux-firmware networkmanager sudo vi vim bash-completion nano wget ufw git pulseaudio pavucontrol gvfs network-manager-applet archlinux-keyring
arch-chroot /mnt systemctl enable NetworkManager.service
arch-chroot /mnt systemctl enable ufw
arch-chroot /mnt ufw enable

echo "generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

echo "Setting timezone and locale..."
arch-chroot /mnt /bin/bash <<EOT
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc
echo "Locale set to $LOCALE with charset $CHARSET."
echo "$LOCALE $CHARSET" > /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf
echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf
EOT

arch-chroot /mnt /bin/bash -c "echo $myhostname > /etc/hostname"
arch-chroot /mnt rm /etc/hosts
arch-chroot /mnt touch /etc/hosts
arch-chroot /mnt /bin/bash -c "echo -e \"127.0.0.1 localhost\n::1 localhost\n127.0.1.1 $myhostname.localdomain $myhostname\" > /etc/hosts"

# Bind mount the EFI partition inside the chroot environment
mount --bind /mnt/boot/efi /mnt/boot/efi

echo "Setting up grub..."
arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

echo "Set the root password:"
echo "root":$rootpassword | arch-chroot /mnt chpasswd
unset rootpassword

echo "Making a new user..."

echo "Enter a new username:"
arch-chroot /mnt useradd -m -G wheel $myusername
echo $myusername:$mypassword | arch-chroot /mnt chpasswd
unset mypassword

echo "%wheel ALL=(ALL) ALL" >> /mnt/etc/sudoers


case "$ucodepackage" in
        "1")
                pacstrap /mnt intel-ucode
                echo "Intel microcode installed."
        ;;
        "2")
                pacstrap /mnt amd-ucode
                echo "AMD microcode installed."
        ;;
		"3")
                echo "CPU microcode installation skipped."
        ;;
		*)
                echo "Invalid. CPU microcode installation skipped."
        ;;
esac
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

if [[ "$install_yay" == "0" ]]; then
    echo "Installing yay and its dependencies..."
    pacstrap /mnt go
    arch-chroot /mnt /bin/bash << "EOT"
    useradd -m tempuser
    su tempuser
    cd ~
    git clone https://aur.archlinux.org/yay-git.git
    cd yay-git
    makepkg
    exit
    pacman --noconfirm -U /home/tempuser/yay-git/*.zst
    userdel tempuser
    rm -rf /home/tempuser
EOT
fi

# Enable multilib
sed -i "/\[multilib\]/,/Include/"'s/^#//' /mnt/etc/pacman.conf

# Enable parallel downloads
sed -i "s/#ParallelDownloads = 5/ParallelDownloads = 5/" /mnt/etc/pacman.conf

pacman --noconfirm -S archlinux-keyring

# Handle Xorg installation based on user choice
if [[ "$xorgchoice" -eq 1 ]]; then
    pacstrap /mnt xorg xorg-server xorg-apps
fi

# Handle video driver installation
case "$videodriver" in
    1) pacstrap /mnt nvidia nvidia-utils ;;
    2) pacstrap /mnt xf86-video-amdgpu ;;
    3) pacstrap /mnt xf86-video-intel ;;
    4) pacstrap /mnt xf86-video-vesa ;;
    5) pacstrap /mnt xf86-video-vmware ;;
    6) pacstrap /mnt virtualbox-guest-utils ;;
esac

# Handle desktop environment installation
case "$desktopenv" in
        "1")
                echo "Installing xfce4..."
                pacstrap /mnt xfce4 xfce4-goodies
                pacstrap /mnt lightdm lightdm-gtk-greeter
                arch-chroot /mnt systemctl enable lightdm
                echo "Done."
        ;;
        "2")
                echo "Installing gnome..."
				pacstrap /mnt gnome gnome-extra gnome-tweaks
				arch-chroot /mnt systemctl enable gdm.service
                echo "Done."
        ;;
        "3")
                echo "Installing KDE Plasma..."
				pacstrap /mnt plasma plasma-wayland-session kde-applications sddm
				arch-chroot /mnt systemctl enable sddm.service
                echo "Done."
        ;;
        "4")
                echo "Installing Budgie..."
				pacstrap /mnt budgie-desktop sddm gnome-terminal gnome-control-center nomacs
				arch-chroot /mnt systemctl enable sddm.service
                echo "Done."
        ;;
        "5")
                echo "Installing Cinnamon..."
				pacstrap /mnt cinnamon gnome-terminal
				pacstrap /mnt lightdm lightdm-gtk-greeter
				arch-chroot /mnt systemctl enable lightdm
                echo "Done."
        ;;
        "6")
                echo "Installing LXQT..."
                pacstrap /mnt lxqt sddm oxygen-icons lxqt-panel network-manager-applet
                arch-chroot /mnt systemctl enable sddm.service
                echo "Done."
        ;;
		"7")
                echo "Installing MATE..."
                pacstrap /mnt mate mate-extra
				pacstrap /mnt lightdm lightdm-gtk-greeter
                arch-chroot /mnt systemctl enable lightdm
                echo "Done."
        ;;
		"8")
                echo "Skipped desktop environment installation."
        ;;
        *)
                echo "Invalid option."
                echo "Skipped desktop environment installation."
        ;;
esac

case "$machine_type" in 
	"1")
			echo "Physical computer installation, no additional agents required."
	;;
	"2")
			echo "Installing Spice agent for QEMU/KVM..."
			pacstrap /mnt spice-vdagent
	;;
	"3")
			echo "Installing open-vm-tools for VMware..."
			pacstrap /mnt open-vm-tools
			arch-chroot /mnt systemctl enable vmtoolsd
	;;
	"4")
			echo "Installing VirtualBox Guest Additions..."
			pacstrap /mnt virtualbox-guest-utils
			arch-chroot /mnt systemctl enable vboxservice
	;;
	"5")
			echo "Other virtual machine or unknown type, no specific agent installed."
	;;
	*)
			echo "Invalid option. No specific agent installed."
	;;
esac

# Optional packages installation
optional_packages=$(dialog --title "Optional Packages Installation" --checklist "Select additional packages to install:" 20 70 12 \
1 "Firefox" off \
2 "Chromium" off \
3 "Google Chrome" off \
4 "Vim" off \
5 "Emacs" off \
6 "Nano" off \
7 "Steam" off \
8 "Wine" off \
9 "Lutris" off \
10 "VLC Media Player" off \
11 "MPV Media Player" off \
12 "Neofetch" off 3>&1 1>&2 2>&3 3>&-)
clear

# Install selected optional packages
IFS=' ' read -r -a selected_packages <<< "$optional_packages"
for package in "${selected_packages[@]}"; do
    case $package in
        1) pacstrap /mnt firefox ;;
        2) pacstrap /mnt chromium ;;
        3) pacstrap /mnt google-chrome ;;
        4) pacstrap /mnt vim ;;
        5) pacstrap /mnt emacs ;;
        6) pacstrap /mnt nano ;;
        7) pacstrap /mnt steam ;;
        8) pacstrap /mnt wine ;;
        9) pacstrap /mnt lutris ;;
        10) pacstrap /mnt vlc ;;
        11) pacstrap /mnt mpv ;;
        12) pacstrap /mnt neofetch ;;
    esac
done

echo -e "\n\nArch has been installed, reboot when you are ready. Have fun!"
