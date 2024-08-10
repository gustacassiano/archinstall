#!/bin/bash

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
# Configurações iniciais
sed -i "s/^#ParallelDownloads = 5$/ParallelDownloads = 15/" /etc/pacman.conf
pacman --noconfirm -Sy archlinux-keyring
loadkeys abnt-2
timedatectl set-ntp true
reflector -a 48 -c $iso -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist


# Garantindo que o pacote dialog está instalado
if ! command -v dialog &> /dev/null; then
    echo "O pacote 'dialog' não está instalado. Instalando..."
    pacman --noconfirm -Sy dialog
fi

# Limpa a tela e exibe a tela inicial
printf '\033c'
dialog --title "Bem-vindo" --msgbox "Bem-vindo ao instalador do Arch Linux por Gustavo Cameiras" 10 50

## Coleta de informações usando dialog
hostname=$(dialog --stdout --inputbox "Insira seu hostname" 0 0) || exit 1
: ${hostname:?"O hostname não pode estar vazio"}

username=$(dialog --stdout --inputbox "Insira seu nome de usuário:" 0 0) || exit 1
: ${username:?"O nome de usuário não pode estar vazio"}

password=$(dialog --stdout --passwordbox "Insira sua senha:" 0 0) || exit 1
: ${password:?"Campo de senha não pode estar vazio"}

password_confirm=$(dialog --stdout --passwordbox "Confirme sua senha:" 0 0) || exit 1
if [ "$password" != "$password_confirm" ]; then
    dialog --msgbox "As senhas não coincidem. Tente novamente." 0 0
    exit 1
fi

# Seleção do disco de instalação
devicelist=$(lsblk -dplnx size -o name,size | grep -Ev "boot|rpmb|loop" | tac)
device=$(dialog --stdout --menu "Selecione o disco de instalação" 0 0 0 ${devicelist}) || exit 1

# Escolha do sistema de boot
boot_choice=$(dialog --stdout --menu "Escolha o sistema de boot:" 0 0 0 \
    1 "GRUB" \
    2 "Systemd-boot") || exit 1

# Escolha do tipo de firmware
firmware_choice=$(dialog --stdout --menu "Escolha o tipo de firmware:" 0 0 0 \
    1 "EFI" \
    2 "BIOS") || exit 1

# Obtém o tamanho da RAM disponível
ram_size=$(free --mebi | awk '/Mem:/ { print $2 }') # Tamanho em MiB


# Particionamento
echo -ne "
-------------------------------------------------------------------------
		         Formatando Disco                    
-------------------------------------------------------------------------
"
if [ "$firmware_choice" -eq 1 ]; then
    # Partição EFI (mínimo 1GiB)
    parted $device mklabel gpt
    parted $device mkpart primary fat32 1MiB 1GiB
    parted $device set 1 esp on
    boot_partition="${device}1"
else
    # Partição BIOS
    parted $device mklabel msdos
    parted $device mkpart primary ext4 1MiB 1GiB
    boot_partition="${device}1"
fi

# Swap e root
parted $device mkpart primary linux-swap 1GiB $((1 + ram_size))MiB
swap_partition="${device}2"
parted $device mkpart primary ext4 $((1 + ram_size))MiB 100%
root_partition="${device}3"

# Formatação
mkfs.ext4 $root_partition
mkswap $swap_partition
swapon $swap_partition

if [ "$firmware_choice" -eq 1 ]; then
    mkfs.fat -F32 $boot_partition
else
    mkfs.ext4 $boot_partition
fi

# Montagem
mount $root_partition /mnt
mkdir /mnt/boot
mount $boot_partition /mnt/boot

# Instalação dos pacotes base
pacstrap /mnt base linux linux-firmware

# Configuração do sistema
genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt /bin/bash <<EOF
# Configurações básicas
ln -sf /usr/share/zoneinfo/$(curl -s http://ip-api.com/line?fields=timezone) /etc/localtime
hwclock --systohc

echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "$hostname" > /etc/hostname

echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1       localhost" >> /etc/hosts
echo "127.0.1.1 $hostname.localdomain $hostname" >> /etc/hosts

echo "Criando o usuário..."
useradd -m $username
echo "$username:$password" | chpasswd

echo "Instalando e configurando o sistema de boot..."
if [ "$boot_choice" -eq 1 ]; then
    pacman -S grub --noconfirm
    if [ "$firmware_choice" -eq 1 ]; then
        pacman -S efibootmgr --noconfirm
        grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    else
        grub-install --target=i386-pc $device
    fi
    grub-mkconfig -o /boot/grub/grub.cfg
else
    pacman -S systemd-boot --noconfirm
    bootctl install
    echo "title Arch Linux" > /boot/loader/entries/arch.conf
    echo "linux /vmlinuz-linux" >> /boot/loader/entries/arch.conf
    echo "initrd /initramfs-linux.img" >> /boot/loader/entries/arch.conf
    echo "options root=PARTUUID=$(blkid -s PARTUUID -o value $root_partition) rw" >> /boot/loader/entries/arch.conf
fi

exit
EOF

echo "Instalação concluída! Desmonte as partições e reinicie o sistema."

# Desmontagem e reboot
umount -R /mnt
swapoff -a
reboot
