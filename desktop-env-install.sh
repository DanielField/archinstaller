#!/bin/bash

read -p "Would you like to install xorg (y/n)?" choice
case "$choice" in 
	y|Y) 
			echo "Installing xorg..."
			pacstrap /mnt xorg xorg-server xorg-apps
	;;
	n|N) 
			echo "Skipped xorg installation."
	;;
	*) 
			echo "invalid. Skipped."
	;;
esac

echo -e "\nChoose a video driver:"
echo "1. NVIDIA"
echo "2. AMD"
echo "3. VMWare"
echo "4. Skip video driver installation"

read videodriver

case "$videodriver" in
        "1")
                pacstrap /mnt nvidia nvidia-utils
        ;;
        "2")
                pacstrap /mnt xf86-video-amdgpu
        ;;
        "3")
                pacstrap /mnt xf86-video-vmware spice-vdagent
        ;;
		"4")
                echo "Skipped video driver installation."
        ;;
		*)
                echo "Invalid. Skipped video driver installation."
        ;;
esac

echo -e "\nChoose a desktop environment:"
echo "1. XFCE4"
echo "2. GNOME"
echo "3. KDE Plasma"
echo "4. Budgie"
echo "5. Cinnamon"
echo "6. LXDE"
echo "7. No desktop environment (skips this step)"

read desktopenv

case "$desktopenv" in
        "1")
                echo "Installing xfce4..."
                pacstrap -i /mnt xfce4 xfce4-goodies
                pacstrap -i /mnt lightdm lightdm-gtk-greeter
                arch-chroot /mnt systemctl enable lightdm
                echo "Done."
        ;;
        "2")
                echo "Installing gnome..."
				pacstrap -i /mnt gnome gnome-extra gnome-tweaks firefox vlc
				arch-chroot /mnt systemctl enable gdm.service
                echo "Done."
        ;;
        "3")
                echo "Installing KDE Plasma..."
				pacstrap -i /mnt plasma plasma-wayland-session kde-applications sddm
				arch-chroot /mnt systemctl enable sddm.service
                echo "Done."
        ;;
        "4")
                echo "Installing Budgie..."
				pacstrap -i /mnt budgie-desktop sddm gnome-terminal firefox vlc gnome-control-center nomacs
				arch-chroot /mnt systemctl enable sddm.service
                echo "Done."
        ;;
        "5")
                echo "Installing Cinnamon..."
				pacstrap -i /mnt cinnamon gnome-terminal
				pacstrap -i /mnt lightdm lightdm-gtk-greeter
				arch-chroot /mnt systemctl enable lightdm
                echo "Done."
        ;;
        "6")
                echo "Installing LXDE..."
                pacstrap -i /mnt lxde lxdm leafpad network-manager-applet opera
                arch-chroot /mnt systemctl enable lxdm.service
                echo "Done."
        ;;
        "7")
                echo "Skipped desktop environment installation."
        ;;
        *)
                echo "Invalid option."
                echo "Skipped desktop environment installation."
        ;;
esac