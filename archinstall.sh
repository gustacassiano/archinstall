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


#!/bin/bash

# Garantindo que o pacote dialog está instalado
if ! command -v dialog &> /dev/null; then
    echo "O pacote 'dialog' não está instalado. Instalando..."
    pacman --noconfirm -Sy dialog
fi

# Limpa a tela e exibe a tela inicial
printf '\033c'
dialog --title "Bem-vindo" --msgbox "Bem-vindo ao instalador do Arch Linux por Gustavo Cameiras" 10 50

# Configurações iniciais
sed -i "s/^#ParallelDownloads = 5$/ParallelDownloads = 15/" /etc/pacman.conf
pacman --noconfirm -Sy archlinux-keyring
loadkeys abnt-2
timedatectl set-ntp true
reflector -a 48 -c $iso -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist

# Coleta de informações usando dialog
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

# Opção para criptografar a partição root com LUKS
encrypt_root=$(dialog --stdout --yesno "Deseja criptografar a partição root com LUKS?" 0 0)
if [ $? -eq 0 ]; then
    luks_passphrase=$(dialog --stdout --passwordbox "Insira a senha para criptografia LUKS:" 0 0) || exit 1
    luks_autologin=$(dialog --stdout --yesno "Deseja ativar autologin após a senha de criptografia?" 0 0)
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

# Seleção de pacotes essenciais
packages=$(dialog --stdout --checklist "Selecione os pacotes essenciais:" 0 0 0 \
    "git" "Sistema de controle de versão" off \
    "wget" "Utilitário para download via linha de comando" off \
    "vim" "Editor de texto" off \
    "sudo" "Permite o uso de privilégios elevados" off) || exit 1

# Seleção de drivers gráficos
drivers=$(dialog --stdout --checklist "Selecione os drivers gráficos:" 0 0 0 \
    "intel" "Driver Intel" off \
    "amd" "Driver AMD" off \
    "nvidia" "Driver Nvidia (proprietário)" off \
    "nvidia-open" "Driver Nvidia (open source)" off \
    "virtualbox" "Driver VirtualBox" off \
    "qxl" "Driver QXL (para VMs)" off) || exit 1

# Escolha do ambiente de desktop
desktop_choice=$(dialog --stdout --menu "Escolha o ambiente de desktop:" 0 0 0 \
    1 "GNOME" \
    2 "KDE" \
    3 "XFCE" \
    4 "Xorg (minimal)" \
    5 "Nenhum") || exit 1

# Escolha do AUR Helper
aur_helper=$(dialog --stdout --menu "Deseja instalar um AUR Helper?" 0 0 0 \
    1 "YAY" \
    2 "PARU" \
    3 "Nenhum") || exit 1

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
if [ "$encrypt_root" -eq 0 ]; then
    parted $device mkpart primary 1 $((1 + ram_size))MiB 100%
    root_partition="${device}3"
    cryptsetup luksFormat $root_partition
    cryptsetup open $root_partition cryptroot
    mkfs.ext4 /dev/mapper/cryptroot
    root_partition="/dev/mapper/cryptroot"
else
    parted $device mkpart primary ext4 $((1 + ram_size))MiB 100%
    root_partition="${device}3"
fi

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
pacstrap /mnt base linux linux-firmware base-devel $packages

# Instalação de drivers gráficos
pacstrap /mnt $drivers

# Instalação de ambiente desktop (opcional)
case $desktop_choice in
    1) pacstrap /mnt gnome gdm ;;
    2) pacstrap /mnt plasma kde-applications sddm ;;
    3) pacstrap /mnt xfce4 xfce4-goodies lightdm ;;
    4) pacstrap /mnt xorg ;;
esac

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

# Instalação e ativação do NetworkManager
pacman -S networkmanager --noconfirm
systemctl enable NetworkManager

# Configuração do autologin (opcional)
if [ "$luks_autologin" -eq 0 ]; then
    # Configurar o autologin aqui
fi

EOF

# Finaliza a instalação
echo "Instalação concluída. Desmonte as partições e reinicie."
umount -R /mnt
reboot
