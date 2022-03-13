#!/bin/bash

timedatectl set-ntp true 

modprobe dm-crypt
modprobe dm-mod

fdisk -l
read -p "Which device do you want to partition? " TGTDEV

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

if [[ "$TGTDEV" == *"nvme"* ]]; then
	efipart=$TGTDEV"p1"
	bootpart=$TGTDEV"p2"
	rootpart=$TGTDEV"p3"
else
	efipart=$TGTDEV"1"
	bootpart=$TGTDEV"2"
	rootpart=$TGTDEV"3"
fi

echo "EFI partition = $efipart, boot partition = $bootpart, root partition = $rootpart"

echo "Setting up encryption with luksFormat..."
cryptsetup luksFormat -v -s 512 -h sha512 $rootpart
cryptsetup open $rootpart luks_root

mkfs.vfat -n "EFI" $efipart
mkfs.ext4 -L boot $bootpart
mkfs.ext4 -L root /dev/mapper/luks_root

mount /dev/mapper/luks_root /mnt
mkdir /mnt/boot
mount $bootpart /mnt/boot
mkdir /mnt/boot/efi
mount $efipart /mnt/boot/efi

echo "How big would you like your swap file (in MB)? "
read swapsize
dd if=/dev/zero of=/mnt/swap bs=1M count=$swapsize
mkswap /mnt/swap
swapon /mnt/swap
chmod 0600 /mnt/swap

echo "Installing packages..."
echo "Which kernel would you like? (e.g. linux, linux-lts, linux-zen, etc.) "
read kernelpackage
pacman -Syy
pacstrap /mnt base base-devel efibootmgr grub $kernelpackage linux-firmware networkmanager sudo vi vim bash-completion nano wget ufw git pulseaudio pavucontrol network-manager-applet archlinux-keyring
arch-chroot /mnt systemctl enable NetworkManager.service
arch-chroot /mnt systemctl enable ufw
arch-chroot /mnt ufw enable

echo "generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

echo "Setting timezone..."
arch-chroot /mnt /bin/bash << "EOT"
ln -sf /usr/share/zoneinfo/Australia/Brisbane /etc/localtime
hwclock --systohc
echo "Setting locale to Australia..."
echo -e "en_AU.UTF-8 UTF-8\nen_AU ISO-8859-1" > /etc/locale.gen
locale-gen
echo 'LANG=en_AU.UTF-8' > /etc/locale.conf
echo 'KEYMAP=US' > /etc/vconsole.conf
EOT

echo "What do you want your hostname to be?"
read myhostname
arch-chroot /mnt /bin/bash -c "echo $myhostname > /etc/hostname"
arch-chroot /mnt rm /etc/hosts
arch-chroot /mnt touch /etc/hosts
arch-chroot /mnt /bin/bash -c "echo -e \"127.0.0.1 localhost\n::1 localhost\n127.0.1.1 $myhostname.localdomain $myhostname\" > /etc/hosts"

echo "Setting up grub to work with LUKS..."
arch-chroot /mnt sed -i "s/GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"cryptdevice=${rootpart//\//\\/}:luks_root\"/" /etc/default/grub

echo "Generating initramfs..."
arch-chroot /mnt sed -i "s/HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)/HOOKS=(base udev autodetect modconf block encrypt filesystems keyboard fsck)/" /etc/mkinitcpio.conf
arch-chroot /mnt mkinitcpio -P

echo "Set the root password:"
arch-chroot /mnt passwd

echo "Setting up grub..."
arch-chroot /mnt grub-install --boot-directory=/boot --efi-directory=/boot/efi $bootpart
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
arch-chroot /mnt grub-mkconfig -o /boot/efi/EFI/arch/grub.cfg

echo "Making a new user..."
echo "Enter a new username:"
read myusername
arch-chroot /mnt useradd -m -G wheel $myusername
arch-chroot /mnt passwd $myusername

echo "%wheel ALL=(ALL) ALL" >> /mnt/etc/sudoers

echo "Which CPU microcode would you like?"
echo "1. intel-ucode"
echo "2. amd-ucode"
echo "3. Skip"
read ucodepackage
case "$ucodepackage" in
        "1")
                pacstrap /mnt intel-ucode
        ;;
        "2")
                pacstrap /mnt amd-ucode
        ;;
		"3")
                echo "Skipped CPU microcode installation."
        ;;
		*)
                echo "Invalid. Skipped CPU microcode installation."
        ;;
esac
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

echo "Installing yay and it's dependencies..."
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

# Enable multilib
sed -i "/\[multilib\]/,/Include/"'s/^#//' /mnt/etc/pacman.conf

# Enable parallel downloads
sed -i "s/#ParallelDownloads = 5/ParallelDownloads = 5/" /mnt/etc/pacman.conf

pacman --noconfirm -S archlinux-keyring

./desktop-env-install.sh

echo -e "\n\nArch has been installed, reboot when you are ready. Have fun!"
