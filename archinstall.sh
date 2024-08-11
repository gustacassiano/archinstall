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

# Tela de boas-vindas
dialog --colors --backtitle "\Zb\Z0" --msgbox "Bem-vindo ao script de instalação do Arch Linux!" 10 50

# Função para obter a lista de discos disponíveis
get_disks() {
    lsblk -d -n -o NAME,SIZE | awk '{print "/dev/" $1 " (" $2 ")"}'
}

# Função para obter a quantidade de RAM em MB
get_ram() {
    free -m | awk '/^Mem:/{print $2}'
}

# Seleção do disco
DISK=$(dialog --colors --backtitle "\Zb\Z0" --stdout --menu "Selecione o disco para instalação:" 0 0 0 $(get_disks))
if [ -z "$DISK" ]; then
    echo "Nenhum disco selecionado. Saindo..."
    exit 1
fi

# Seleção do tipo de inicialização
BOOT_TYPE=$(dialog --colors --backtitle "\Zb\Z0" --stdout --menu "Selecione o tipo de inicialização:" 10 50 2 \
    1 "BIOS" \
    2 "EFI")

# Seleção do gerenciador de boot
BOOTLOADER=$(dialog --colors --backtitle "\Zb\Z0" --stdout --menu "Selecione o gerenciador de boot:" 10 50 2 \
    1 "GRUB" \
    2 "SystemD-boot")

# Particionamento do disco
(
echo "Criando tabela de partições..."
parted -s "$DISK" mklabel gpt

echo "Criando partição de boot..."
if [ "$BOOT_TYPE" -eq 2 ]; then
    parted -s "$DISK" mkpart primary fat32 1MiB 1GiB
    parted -s "$DISK" set 1 esp on
else
    parted -s "$DISK" mkpart primary ext4 1MiB 1GiB
    parted -s "$DISK" set 1 boot on
fi

echo "Criando partição root..."
parted -s "$DISK" mkpart primary ext4 1GiB 100%
) | dialog --colors --backtitle "\Zb\Z0" --progressbox "Particionando o disco..." 20 60

# Perguntar se o usuário deseja criar uma partição swap
dialog --colors --backtitle "\Zb\Z0" --yesno "Deseja criar uma partição swap?" 7 40
if [ $? -eq 0 ]; then
    RAM_SIZE=$(get_ram)
    (
    echo "Criando partição swap..."
    parted -s "$DISK" mkpart primary linux-swap 1GiB $((1 + RAM_SIZE))MiB
    ) | dialog --colors --backtitle "\Zb\Z0" --progressbox "Criando partição swap..." 20 60
    SWAP_PART="${DISK}2"
    ROOT_PART="${DISK}3"
else
    ROOT_PART="${DISK}2"
fi

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
ln -sf /usr/share/zoneinfo/Region/City /etc/localtime
hwclock --systohc

# Configurações de localidade
echo "pt_BR.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=pt_BR.UTF-8" > /etc/locale.conf

# Configurações de rede
echo "archlinux" > /etc/hostname
echo "127.0.0.1   localhost" >> /etc/hosts
echo "::1         localhost" >> /etc/hosts
echo "127.0.1.1   archlinux.localdomain archlinux" >> /etc/hosts


# Configuração do root
echo "Defina a senha do root"
passwd

# Instalação do gerenciador de boot
if [ "$BOOTLOADER" -eq 1 ]; then
    pacman -S grub --noconfirm
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

# Criação de usuário
USERNAME=$(dialog --colors --backtitle "\Zb\Z0" --stdout --inputbox "Digite o nome do usuário:" 10 50)
if [ -z "$USERNAME" ]; then
    echo "Nenhum nome de usuário fornecido. Saindo..."
    exit 1
fi

while true; do
    PASSWORD=$(dialog --colors --backtitle "\Zb\Z0" --stdout --passwordbox "Digite a senha do usuário:" 10 50)
    PASSWORD_CONFIRM=$(dialog --colors --backtitle "\Zb\Z0" --stdout --passwordbox "Confirme a senha do usuário:" 10 50)
    if [ "$PASSWORD" == "$PASSWORD_CONFIRM" ]; then
        break
    else
        dialog --colors --backtitle "\Zb\Z0" --msgbox "As senhas não coincidem. Tente novamente." 10 50
    fi
done



useradd -m -G wheel,audio,video -s /bin/bash "$USERNAME"
echo "$USERNAME:$PASSWORD" | chpasswd

# Perguntar se o usuário recém-criado é superusuário
dialog --colors --backtitle "\Zb\Z0" --yesno "O usuário $USERNAME deve ser superusuário (sudo)?" 7 40
if [ $? -eq 0 ]; then
    echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers
fi

# Seleção de drivers de vídeo
VIDEO_DRIVERS=$(dialog --colors --backtitle "\Zb\Z0" --stdout --checklist "Selecione os drivers de vídeo:" 15 50 5 \
    1 "Intel" off \
    2 "AMD" off \
    3 "NVIDIA (proprietário)" off \
    4 "NVIDIA (open source)" off \
    5 "VirtualBox" off)

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
AUDIO_DRIVER=$(dialog --colors --backtitle "\Zb\Z0" --stdout --menu "Selecione o driver de áudio:" 10 50 2 \
    1 "Pulseaudio" \
    2 "Pipewire")

# Instalação do driver de áudio selecionado
case $AUDIO_DRIVER in
    1) pacman -S --noconfirm pulseaudio pulseaudio-alsa ;;
    2) pacman -S --noconfirm pipewire pipewire-alsa pipewire-pulse ;;
esac

# Seleção de ambiente de desktop
DESKTOP_ENV=$(dialog --colors --backtitle "\Zb\Z0" --stdout --menu "Selecione o ambiente de desktop:" 15 50 5 \
    1 "Gnome" \
    2 "KDE" \
    3 "XFCE" \
    4 "Xorg (Minimal)" \
    5 "Nenhum")

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


# Habilitar NetworkManager
systemctl enable NetworkManager

# Seleção de AUR Helper
AUR_HELPER=$(dialog --colors --backtitle "\Zb\Z0" --stdout --menu "Deseja instalar um AUR Helper?" 10 50 3 \
    1 "Yay" \
    2 "Paru" \
    3 "Nenhum")

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
if [ -n "$SWAP_PART" ]; então
    swapoff "$SWAP_PART"
fi

# Opção de reinicialização ou chroot
dialog --colors --backtitle "\Zb\Z0" --yesno "Instalação concluída! Deseja reiniciar o sistema?" 7 50
if [ $? -eq 0 ]; então
    reboot
else
    arch-chroot /mnt
fi
