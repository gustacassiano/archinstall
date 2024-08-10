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
██║     ███╔══██║██║╚██╔╝██║██╔══╝  ██║██╔══██╗██╔══██║╚════██║                            
╚██████╗██��  ██║██║ ╚═╝ ██║███████╗██║██║  ██║██║  ██║███████║                            
 ╚═════╝╚═╝  ╚═╝╚═╝     ╚═╝╚══════╝╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝                            
                                                                                          
 █████╗ ██████╗  ██████╗██╗  ██╗    ██╗███╗   ██╗███████╗████████╗ █████╗ ██╗     ██╗     
██╔══██╗██╔══██╗██╔════╝██║  ██║    ██║████╗  ██║██╔════╝╚══██╔══╝██╔══██╗██║     ██║     
███████║██████╔╝██║     ███████║    ██║██╔██╗ ██║███████╗   ██║   ███████║██║     ██║     
██╔══██║██╔══██╗██║     ██╔══██║    ██║██║╚██╗██║╚════██║   ██║   ██╔══██║██║     ██║     
██║  ██║██║  ██║╚██████╗██║  ██║    ██║██║ ╚████║███████║   ██║   ██║  ██║███████╗███████╗
╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝    ╚═╝╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚══════╝
                                                                                          

}

# Função para instalar pacotes iniciais
install_initial_packages() {
    pacman --noconfirm -Sy git dialog
}

# Função para configurações iniciais
initial_setup() {
    pacman --noconfirm -Sy archlinux-keyring
    loadkeys abnt-2
    timedatectl set-ntp true
    lsblk
    reflector -a 48 -c $iso -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist
    mkdir /mnt &>/dev/null
}

# Função para obter informações do usuário
get_user_info() {
    dialog --backtitle "Cameiras Arch Install" --title "Configuração do Usuário" --inputbox "Digite o nome de usuário:" 10 60 2>username.txt
    dialog --backtitle "Cameiras Arch Install" --title "Configuração do Usuário" --passwordbox "Digite a senha:" 10 60 2>password.txt
    dialog --backtitle "Cameiras Arch Install" --title "Configuração do Hostname" --inputbox "Digite o nome da máquina (hostname):" 10 60 2>hostname.txt
}

# Fun��ão para escolher opções de instalação
choose_install_options() {
    dialog --backtitle "Cameiras Arch Install" --title "Opções de Instalação" --menu "Escolha uma opção de encriptação LUKS:" 15 60 2 \
    1 "Sim" \
    2 "Não" 2>encryption.txt

    dialog --backtitle "Cameiras Arch Install" --title "Drivers de Vídeo" --checklist "Escolha os drivers de vídeo:" 15 60 5 \
    1 "Intel" off \
    2 "AMD" off \
    3 "NVIDIA Proprietário" off \
    4 "NVIDIA Open Source" off \
    5 "Máquinas Virtuais" off 2>video_drivers.txt

    dialog --backtitle "Cameiras Arch Install" --title "Drivers de Áudio" --menu "Escolha um driver de áudio:" 15 60 2 \
    1 "Pulseaudio" \
    2 "Pipewire" 2>audio_driver.txt

    dialog --backtitle "Cameiras Arch Install" --title "Tipo de Boot" --menu "Escolha o tipo de Boot:" 15 60 2 \
    1 "EFI" \
    2 "BIOS" 2>boot_type.txt

    dialog --backtitle "Cameiras Arch Install" --title "Gerenciador de Boot" --menu "Escolha um gerenciador de Boot:" 15 60 2 \
    1 "GRUB" \
    2 "SystemD" 2>boot_manager.txt

    dialog --backtitle "Cameiras Arch Install" --title "Ambiente de Desktop" --menu "Escolha um ambiente de desktop:" 15 60 5 \
    1 "Gnome" \
    2 "KDE" \
    3 "XFCE" \
    4 "Xorg (minimal)" \
    5 "Nenhum (servidores)" 2>desktop_environment.txt

    dialog --backtitle "Cameiras Arch Install" --title "AUR Helper" --menu "Escolha um AUR helper:" 15 60 3 \
    1 "YAY" \
    2 "Paru" \
    3 "Nenhum" 2>aur_helper.txt
}

# Função para selecionar o disco e criar partições
partition_disk() {
    disks=$(lsblk -dn -o NAME,SIZE | awk '{print "/dev/" $1 " (" $2 ")"}')
    dialog --backtitle "Cameiras Arch Install" --title "Seleção de Disco" --menu "Escolha o disco para particionar:" 15 60 4 ${disks} 2>disk.txt
    disk=$(cat disk.txt)

    dialog --backtitle "Cameiras Arch Install" --title "Partição Swap" --yesno "Deseja criar uma partição de swap?" 10 60
    swap_choice=$?

    # Tamanho da memória RAM em MiB
    ram_size=$(grep MemTotal /proc/meminfo | awk '{print $2 / 1024}')

    # Criar partições
    parted -s $disk mklabel gpt
    parted -s $disk mkpart primary ext4 1MiB 1GiB
    parted -s $disk name 1 boot
    parted -s $disk set 1 boot on

    if [ $swap_choice -eq 0 ]; then
        parted -s $disk mkpart primary linux-swap 1GiB $(echo "1GiB + ${ram_size}MiB" | bc)
        parted -s $disk name 2 swap
        swap_end=$(echo "1GiB + ${ram_size}MiB" | bc)
    else
        swap_end="1GiB"
    fi

    parted -s $disk mkpart primary ext4 ${swap_end} 100%
    parted -s $disk name 3 root

    # Formatar partições
    mkfs.ext4 ${disk}1
    if [ $swap_choice -eq 0 ]; then
        mkswap ${disk}2
        swapon ${disk}2
    fi
    mkfs.ext4 ${disk}3

    # Montar partições
    mount ${disk}3 /mnt
    mkdir /mnt/boot
    mount ${disk}1 /mnt/boot
}

# Função para instalar pacotes essenciais
install_essential_packages() {
    pacman --noconfirm -S git wget vim
}

# Função para configurar o sistema
configure_system() {
    # Adicionar usuário aos grupos necessários
    useradd -m -G wheel,audio,video -s /bin/bash $(cat username.txt)
    echo "$(cat username.txt):$(cat password.txt)" | chpasswd

    # Configurar sudoers
    echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

    # Ativar serviços
    systemctl enable ly
    systemctl enable NetworkManager
    systemctl enable polkit

    # Instalar e configurar o polkit
    case $(cat desktop_environment.txt) in
        1) pacman --noconfirm -S gnome-polkit ;;
        2) pacman --noconfirm -S kde-polkit ;;
        3) pacman --noconfirm -S xfce-polkit ;;
        4) pacman --noconfirm -S gnome-polkit ;;
    esac

    # Instalar e configurar o login manager
    if [ $(cat desktop_environment.txt) -eq 4 ]; then
        pacman --noconfirm -S ly
    fi

    # Instalar e configurar o network manager
    pacman --noconfirm -S networkmanager
    systemctl enable NetworkManager

    # Instalar navegador Firefox se um desktop environment foi selecionado
    if [ $(cat desktop_environment.txt) -ne 5 ]; then
        pacman --noconfirm -S firefox
    fi

    # Instalar AUR helper se selecionado
    case $(cat aur_helper.txt) in
        1) git clone https://aur.archlinux.org/yay.git 
             cd yay
             makepkg -si
             cd ;;
        2) git clone https://aur.archlinux.org/paru.git
             cd paru
             makepkg -si
             cd ;;
            
    esac
}

# Função para finalizar a instalação
finalize_installation() {
    dialog --backtitle "Cameiras Arch Install" --title "Instalação Completa" --yesno "A instalação do Arch Linux foi concluída com sucesso! Deseja reiniciar o sistema agora?" 10 60
    if [ $? -eq 0 ]; then
        reboot
    else
        dialog --backtitle "Cameiras Arch Install" --title "Continuar para chroot" --msgbox "Você pode continuar para o chroot para realizar configurações adicionais." 10 60
        arch-chroot /mnt
    fi
}

# Função para exibir mensagens de erro
show_errors() {
    if [ -s /tmp/install_errors.log ]; then
        dialog --backtitle "Cameiras Arch Install" --title "Erros de Instalação" --textbox /tmp/install_errors.log 20 60
    fi
}

# Função principal
main() {
    welcome_screen
    install_initial_packages
    initial_setup
    get_user_info
    choose_install_options
    partition_disk
    install_essential_packages
    configure_system
    show_errors
    finalize_installation
}

main



