#!/bin/bash

# Enable multilib
sudo sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf

# Update everything and install archlinux-keyring
sudo pacman -Syu
sudo pacman -S archlinux-keyring

# Install packages (including AUR packages)
yay -S brave-bin timeshift gufw vlc qbittorrent vscode wine steam pinta neofetch

# Add neofetch to .bashrc (because why not)
echo "neofetch" >> .bashrc
source .bashrc