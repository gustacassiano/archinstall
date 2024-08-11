#!/bin/bash

# Funções e comandos iniciais
printf '\033c'
echo "

 ██████╗ █████╗ ███╗   ███╗███████╗██╗██████╗  █████╗ ███████╗                            
██╔════╝██╔══██╗████╗ ████║██╔════╝██║██╔══██╗██╔══██╗██╔════╝                            
██║     ███████║██╔████╔██║█████╗  ██║██████╔╝███████║███████╗                            
██║     ██╔══██║██║╚██╔╝██║██╔══╝  ██║██╔══██╗██╔══██║╚════██║                            
╚██████╗██║  ██║██║ ╚═╝ ██║███████╗██║██║  ██║██║  ██║███████║                            
 ╚═════╝╚═╝  ╚═╝╚═╝     ╚═╝╚══════╝╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝                            
                                                                                          
 █████╗ ██████╗  ██████╗██╗  ██╗    ██╗███╗   ██╗███████╗████████╗ █████╗ ██╗     ██╗     
██╔══██╗██╔══██╗██╔════╝██║  ██║    ██║████╗  ██║██╔════╝╚══██╔══╝██╔══██╗██║     ██║     
███████║██████╔╝██║     ███████║    ██║██╔██╗ ██║███████╗   ██║   ███████║██║     ██║     
██╔══██║██╔══██╗██║     ██╔══██║    ██║██║╚██╗██║╚════██║   ██║   ██╔══██║██║     ██║     
██║  ██║██║  ██║╚██████╗██║  ██║    ██║██║ ╚████║███████║   ██║   ██║  ██║███████╗███████╗
╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝    ╚═╝╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚══════╝
                                                                                          

"
echo "Bem-vindo ao instalador do Arch Linux por Gustavo Cameiras"
sed -i "s/^#ParallelDownloads = 5$/ParallelDownloads = 15/" /etc/pacman.conf
pacman --noconfirm -Sy archlinux-keyring
loadkeys abnt-2
timedatectl set-ntp true
lsblk
reflector -a 48 -c $iso -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist

# Verificar e instalar dialog e git
if ! command -v dialog &> /dev/null; then
    pacman -Sy --noconfirm dialog
fi

if ! command -v git &> /dev/null; then
    pacman -Sy --noconfirm git
fi

# Função para obter a lista de discos disponíveis
get_disks() {
    lsblk -d -n -o NAME,SIZE | awk '{print "/dev/" $1 " (" $2 ")"}'
}

# Função para obter a quantidade de RAM em MB
get_ram() {
    free -m | awk '/^Mem:/{print $2}'
}

# Seleção do disco
clear
echo "Discos disponíveis:"
get_disks
read -p "Digite o nome do disco para instalação (ex: /dev/sda): " DISK

# Seleção do tipo de inicialização
clear
echo "Selecione o tipo de inicialização:"
echo "1) BIOS"
echo "2) EFI"
read -p "Digite o número da opção desejada: " BOOT_TYPE

# Seleção do gerenciador de boot
clear
echo "Selecione o gerenciador de boot:"
echo "1) GRUB"
echo "2) SystemD-boot"
read -p "Digite o número da opção desejada: " BOOTLOADER

# Particionamento do disco
clear
echo "Criando tabela de partições..."
parted -s "$DISK" mklabel gpt

echo "Criando partição de boot..."
if [ "$BOOT_TYPE" -eq 2 ]; then
    parted -s "$DISK" mkpart primary fat32 1MiB 1GiB
    parted -s "$DISK" set 1 esp on
    BOOT_PART="${DISK}1"
else
    parted -s "$DISK" mkpart primary ext4 1MiB 1GiB
    parted -s "$DISK" set 1 boot on
    BOOT_PART="${DISK}1"
fi

# Perguntar se o usuário deseja criar uma partição swap
clear
read -p "Deseja criar uma partição swap? (s/n): " CREATE_SWAP
if [[ $CREATE_SWAP =~ ^[Ss]$ ]]; then
    RAM_SIZE=$(get_ram)
    echo "Criando partição swap..."
    parted -s "$DISK" mkpart primary linux-swap 1GiB $((1 + RAM_SIZE))MiB
    SWAP_PART="${DISK}2"
    ROOT_PART="${DISK}3"
else
    ROOT_PART="${DISK}2"
fi

# Criar partição de root
echo "Criando partição de root..."
parted -s "$DISK" mkpart primary ext4 $((1 + RAM_SIZE))MiB 100%

# Formatação das partições
if [ "$BOOT_TYPE" -eq 2 ]; then
    mkfs.fat -F32 "${DISK}1"
else
    mkfs.ext4 "${DISK}1"
fi
mkfs.ext4 "$ROOT_PART"
if [ -n "$SWAP_PART" ]; then
    mkswap "$SWAP_PART"
    swapon "$SWAP_PART"
fi

# Montagem das partições
mount "$ROOT_PART" /mnt
mkdir /mnt/boot
mount "${DISK}1" /mnt/boot

# Instalação do sistema base
pacstrap /mnt base base-devel linux linux-firmware git wget networkmanager

# Gerar fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot no novo sistema
arch-chroot /mnt <<EOF
# Configurações de fuso horário
ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
hwclock --systohc

# Configurações de localidade
echo "pt_BR.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=pt_BR.UTF-8" > /etc/locale.conf
echo "KEYMAP=abnt-2" > /etc/vconsole.conf

# Configuração de rede
echo "archlinux" > /etc/hostname
echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1       localhost" >> /etc/hosts
echo "127.0.1.1 archlinux.localdomain archlinux" >> /etc/hosts

# Instalação do bootloader
if [ "$BOOTLOADER" -eq 1 ]; then
    pacman -S grub efibootmgr --noconfirm
    if [ "$BOOT_TYPE" -eq 2 ]; then
        grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    else
        grub-install --target=i386-pc "$DISK"
    fi
    grub-mkconfig -o /boot/grub/grub.cfg
else
    pacman -S systemd-boot --noconfirm
    bootctl install
    cat <<EOL > /boot/loader/entries/arch.conf
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=PARTUUID=$(blkid -s PARTUUID -o value "$ROOT_PART") rw
EOL
    cat <<EOL > /boot/loader/loader.conf
default arch
timeout 4
editor  no
EOL
fi

# Habilitar NetworkManager
systemctl enable NetworkManager

# Criação de usuário
clear
read -p "Digite o nome do usuário: " USERNAME
useradd -m -G wheel,audio,video -s /bin/bash "$USERNAME"
passwd "$USERNAME"

# Perguntar se o usuário recém-criado é superusuário
clear
read -p "O usuário $USERNAME deve ser superusuário (sudo)? (s/n): " SUDO_USER
if [[ $SUDO_USER =~ ^[Ss]$ ]]; then
    echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers
fi

# Seleção de drivers de vídeo
clear
echo "Selecione os drivers de vídeo (separados por espaço):"
echo "1) Intel"
echo "2) AMD"
echo "3) NVIDIA (proprietário)"
echo "4) NVIDIA (open source)"
echo "5) VirtualBox"
read -p "Digite os números das opções desejadas: " VIDEO_DRIVERS

# Instalação dos drivers de vídeo selecionados
for DRIVER in $VIDEO_DRIVERS; do
    case $DRIVER in
        1) pacman -S --noconfirm xf86-video-intel ;;
        2) pacman -S --noconfirm xf86-video-amdgpu ;;
        3) pacman -S --noconfirm nvidia nvidia-utils ;;
        4) pacman -S --noconfirm xf86-video-nouveau ;;
        5) pacman -S --noconfirm virtualbox-guest-utils ;;
    esac
done

# Seleção de driver de áudio
clear
echo "Selecione o driver de áudio:"
echo "1) Pulseaudio"
echo "2) Pipewire"
read -p "Digite o número da opção desejada: " AUDIO_DRIVER

# Instalação do driver de áudio selecionado
case $AUDIO_DRIVER in
    1) pacman -S --noconfirm pulseaudio pulseaudio-alsa ;;
    2) pacman -S --noconfirm pipewire pipewire-alsa pipewire-pulse ;;
esac

# Seleção de ambiente de desktop
clear
echo "Selecione o ambiente de desktop:"
echo "1) Gnome"
echo "2) KDE"
echo "3) XFCE"
echo "4) Xorg (Minimal)"
echo "5) Nenhum"
read -p "Digite o número da opção desejada: " DESKTOP_ENV

# Instalação do ambiente de desktop selecionado
case $DESKTOP_ENV in
    1) pacman -S --noconfirm gnome gnome-extra firefox ;;
    2) pacman -S --noconfirm plasma kde-applications firefox ;;
    3) pacman -S --noconfirm xfce4 xfce4-goodies firefox ;;
    4) 
        pacman -S --noconfirm xorg xorg-xinit ly gnome-polkit firefox
        systemctl enable ly
        systemctl enable polkit
        ;;
esac

# Seleção de AUR Helper
clear
echo "Deseja instalar um AUR Helper?"
echo "1) Yay"
echo "2) Paru"
echo "3) Nenhum"
read -p "Digite o número da opção desejada: " AUR_HELPER

# Instalação do AUR Helper selecionado
case $AUR_HELPER in
    1)
        pacman -S --noconfirm base-devel
        sudo -u "$USERNAME" git clone https://aur.archlinux.org/yay.git /home/"$USERNAME"/yay
        cd /home/"$USERNAME"/yay
        sudo -u "$USERNAME" makepkg -si --noconfirm
        ;;
    2)
        pacman -S --noconfirm base-devel
        sudo -u "$USERNAME" git clone https://aur.archlinux.org/paru.git /home/"$USERNAME"/paru
        cd /home/"$USERNAME"/paru
        sudo -u "$USERNAME" makepkg -si --noconfirm
        ;;
esac

EOF

# Saída do chroot e desmontagem
umount -R /mnt
if [ -n "$SWAP_PART" ]; then
    swapoff "$SWAP_PART"
fi

# Opção de reinicialização ou chroot
clear
read -p "Instalação concluída! Deseja reiniciar o sistema? (s/n): " REBOOT
if [[ $REBOOT =~ ^[Ss]$ ]]; then
    reboot
else
    arch-chroot /mnt
fi
