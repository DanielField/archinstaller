# archinstaller
Arch Linux automated install script. **Do not run this script if you want to dual boot on the same drive. This script will erase everything on your drive.**
This installer will automatically create your partitions. It will have three partitions: EFI (512MB), boot (512MB), and root (remaining space). Feel free to modify the script if you do not like this. :)

## Installation Steps
1. Type `pacman -Syy`
2. Install git with `pacman -S git`
3. Download this repo with `git clone https://github.com/DanielField/archinstaller.git`
4. Type `cd archinstaller`
5. Run the script with `./archinstaller_efi.sh`
6. Follow the prompts.
