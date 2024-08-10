#!/bin/bash

# Verifica se o script está sendo executado como root
if [ "$EUID" -ne 0 ]; then
    echo "Por favor, execute como root"
    exit 1
fi

# Função para exibir a tela de boas-vindas
welcome_screen() {
    printf '\033c'
    echo "Bem-vindo ao instalador do Arch Linux por Gustavo Cameiras"
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
}

# Função para instalar pacotes essenciais
install_essential_packages() {
    pacman --noconfirm -Sy git dialog archlinux-keyring
    loadkeys br-abnt2
    timedatectl set-ntp true
    lsblk
    reflector -a 48 -c $iso -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist
}

# Função para exibir caixas de diálogo com fundo preto e dicas de teclas
dialog_box() {
    dialog --backtitle "Cameiras Arch Install" --title "$1" --msgbox "$2" 10 50
}

# Função para coletar informações do usuário
collect_user_info() {
    hostname=$(dialog --stdout --backtitle "Cameiras Arch Install" --title "Hostname" --inputbox "Insira seu hostname (Nome da máquina):" 0 0) || exit 1
    : ${hostname:?"O hostname não pode estar vazio"}

    username=$(dialog --stdout --backtitle "Cameiras Arch Install" --title "Nome de Usuário" --inputbox "Insira seu nome de usuário:" 0 0) || exit 1
    : ${username:?"O nome de usuário não pode estar vazio"}

    password=$(dialog --stdout --backtitle "Cameiras Arch Install" --title "Senha" --passwordbox "Insira sua senha:" 0 0) || exit 1
    : ${password:?"Campo de senha não pode estar vazio"}

    password_confirm=$(dialog --stdout --backtitle "Cameiras Arch Install" --title "Confirmação de Senha" --passwordbox "Confirme sua senha:" 0 0) || exit 1
    if [ "$password" != "$password_confirm" ]; then
        dialog --backtitle "Cameiras Arch Install" --msgbox "As senhas não coincidem. Tente novamente." 0 0
        exit 1
    fi

    encrypt_root=$(dialog --stdout --backtitle "Cameiras Arch Install" --title "Criptografia LUKS" --yesno "Deseja criptografar a partição root com LUKS?" 0 0)
    if [ $? -eq 0 ]; then
        luks_passphrase=$(dialog --stdout --backtitle "Cameiras Arch Install" --title "Senha LUKS" --passwordbox "Insira a senha para criptografia LUKS:" 0 0) || exit 1
        luks_autologin=$(dialog --stdout --backtitle "Cameiras Arch Install" --title "Autologin LUKS" --yesno "Deseja ativar autologin após a senha de criptografia?" 0 0)
    fi

    use_swap=$(dialog --stdout --backtitle "Cameiras Arch Install" --title "Partição Swap" --yesno "Deseja criar uma partição swap?" 0 0)

    drivers=$(dialog --stdout --backtitle "Cameiras Arch Install" --title "Drivers Gráficos" --checklist "Selecione os drivers gráficos (Use a barra de espaço para selecionar e Enter para avançar):" 0 0 0 \
        "intel" "Driver Intel" off \
        "amd" "Driver AMD" off \
        "nvidia" "Driver Nvidia (proprietário)" off \
        "nvidia-open" "Driver Nvidia (open source)" off \
        "virtualbox" "Driver VirtualBox" off \
        "qxl" "Driver QXL (para VMs)" off) || exit 1
    drivers=$(echo $drivers | sed 's/\"//g')

    audio_choice=$(dialog --stdout --backtitle "Cameiras Arch Install" --title "Sistema de Áudio" --menu "Escolha o sistema de áudio (Use as setas para cima/baixo para selecionar e Enter para avançar):" 0 0 0 \
        1 "PulseAudio" \
        2 "Pipewire") || exit 1

    desktop_choice=$(dialog --stdout --backtitle "Cameiras Arch Install" --title "Ambiente de Desktop" --menu "Escolha o ambiente de desktop (Use as setas para cima/baixo para selecionar e Enter para avançar):" 0 0 0 \
        1 "GNOME" \
        2 "KDE" \
        3 "XFCE" \
        4 "Xorg (minimal)" \
        5 "Nenhum") || exit 1

    aur_helper=$(dialog --stdout --backtitle "Cameiras Arch Install" --title "AUR Helper" --menu "Deseja instalar um AUR Helper? (Use as setas para cima/baixo para selecionar e Enter para avançar):" 0 0 0 \
        1 "YAY" \
        2 "PARU" \
        3 "Nenhum") || exit 1
}

# Função para configurar o sistema
configure_system() {
    # Configurações iniciais
    sed -i "s/^#ParallelDownloads = 5$/ParallelDownloads = 15/" /etc/pacman.conf
    pacman --noconfirm -Sy archlinux-keyring
    loadkeys abnt-2
    timedatectl set-ntp true
    reflector -a 48 -c $iso -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist

    # Particionamento
    devicelist=$(lsblk -dplnx size -o name,size | grep -Ev "boot|rpmb|loop" | tac)
    device=$(dialog --stdout --backtitle "Cameiras Arch Install" --title "Disco de Instalação" --menu "Selecione o disco de instalação (Use as setas para cima/baixo para selecionar e Enter para avançar):" 0 0 0 ${devicelist}) || exit 1

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
    if [ "$use_swap" -eq 0 ]; then
        ram_size=$(free --mebi | awk '/Mem:/ { print $2 }') # Tamanho em MiB
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
    else
        if [ "$encrypt_root" -eq 0 ]; then
            parted $device mkpart primary 1GiB 100%
            root_partition="${device}2"
            cryptsetup luksFormat $root_partition
            cryptsetup open $root_partition cryptroot
            mkfs.ext4 /dev/mapper/cryptroot
            root_partition="/dev/mapper/cryptroot"
        else
            parted $device mkpart primary ext4 1GiB 100%
            root_partition="${device}2"
        fi
    fi

    if [ "$firmware_choice" -eq 1 ]; then
        mkfs.fat -F32 $boot_partition
    else
        mkfs.ext4 $boot_partition
    fi

    # Montagem
    mount $root_partition /mnt
    mkdir /mnt/boot
    mount $boot_partition /mnt/boot

    if [ "$use_swap" -eq 0 ]; then
        mkswap $swap_partition
        swapon $swap_partition
    fi

    # Instalação dos pacotes base
    pacstrap /mnt base linux linux-firmware base-devel git wget vim

    # Instalação de drivers gráficos
    pacstrap /mnt $drivers

    # Instalação de ambiente desktop (opcional)
    case $desktop_choice in
        1) pacstrap /mnt gnome gdm ;;
        2) pacstrap /mnt plasma kde-applications sddm ;;
        3) pacstrap /mnt xfce4 xfce4-goodies lightdm ;;
        4) pacstrap /mnt xorg ly ;;
    esac

    # Instalação do sistema de áudio
    case $audio_choice in
        1) pacstrap /mnt pulseaudio ;;
        2) pacstrap /mnt pipewire ;;
    esac

    # Configuração do sistema
    genfstab -U /mnt >> /mnt/etc/fstab

    arch-chroot /mnt /bin/bash <<EOF
    # Configurações básicas
    ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
    hwclock --systohc

    echo "LANG=pt_BR.UTF-8" > /etc/locale.conf
    echo "$hostname" > /etc/hostname

    echo "127.0.0.1 localhost" >> /etc/hosts
    echo "::1       localhost" >> /etc/hosts
    echo "127.0.1.1 $hostname.localdomain $hostname" >> /etc/hosts

    echo "Criando o usuário..."
    useradd -m -G wheel,audio,video $username
    echo "$username:$password" | chpasswd

    # Adiciona o usuário ao sudoers
    echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

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
        bootctl install
        echo "title Arch Linux" > /boot/loader/entries/arch.conf
        echo "linux /vmlinuz-linux" >> /boot/loader/entries/arch.conf
        echo "initrd /initramfs-linux.img" >> /boot/loader/entries/arch.conf
        echo "options root=PARTUUID=$(blkid -s PARTUUID -o value $root_partition) rw" >> /boot/loader/entries/arch.conf
    fi

    # Instalação e ativação do NetworkManager
    pacman -S networkmanager --noconfirm
    systemctl enable NetworkManager

    # Habilitação do polkit
    systemctl enable polkit

    # Configuração do autologin (opcional)
    if [ "$luks_autologin" -eq 0 ]; then
        case $desktop_choice in
            1) 
                mkdir -p /etc/gdm
                echo "[daemon]" > /etc/gdm/custom.conf
                echo "AutomaticLoginEnable=True" >> /etc/gdm/custom.conf
                echo "AutomaticLogin=$username" >> /etc/gdm/custom.conf
                ;;
            2) 
                mkdir -p /etc/sddm.conf.d
                echo "[Autologin]" > /etc/sddm.conf.d/autologin.conf
                echo "User=$username" >> /etc/sddm.conf.d/autologin.conf
                echo "Session=plasma.desktop" >> /etc/sddm.conf.d/autologin.conf
                ;;
            3) 
                mkdir -p /etc/lightdm
                echo "[Seat:*]" > /etc/lightdm/lightdm.conf
                echo "autologin-user=$username" >> /etc/lightdm/lightdm.conf
                ;;
            4) 
                systemctl enable ly
                ;;
        esac
    fi

    # Instalação do AUR Helper
    case $aur_helper in
        1)
            git clone https://aur.archlinux.org/yay.git /home/$username/yay
            chown -R $username:$username /home/$username/yay
            cd /home/$username/yay
            sudo -u $username makepkg -si --noconfirm
            ;;
        2)
            git clone https://aur.archlinux.org/paru.git /home/$username/paru
            chown -R $username:$username /home/$username/paru
            cd /home/$username/paru
            sudo -u $username makepkg -si --noconfirm
            ;;
    esac

EOF

    # Finaliza a instalação
    echo "Instalação concluída. Desmonte as partições e reinicie."
    umount -R /mnt
    reboot
}

# Execução do script
welcome_screen
install_essential_packages
collect_user_info
configure_system

