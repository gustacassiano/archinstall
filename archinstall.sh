#!/bin/bash

# Função para criar partições
criar_particoes() {
    local disco=$1
    local tem_swap=$2
    local tamanho_ram=$3
    local tipo_sistema=$4

    # Limpar tabela de partições existente
    sgdisk -Z "$disco"

    if [ "$tipo_sistema" = "EFI" ]; then
        # Criar partição EFI (1GB)
        sgdisk -n 1:0:+1G -t 1:ef00 "$disco"
    else
        # Criar partição BIOS boot (1MB)
        sgdisk -n 1:0:+1M -t 1:ef02 "$disco"
    fi

    if [ "$tem_swap" = "sim" ]; then
        # Criar partição de swap
        sgdisk -n 2:0:+"$tamanho_ram"G -t 2:8200 "$disco"
        # Criar partição root com o espaço restante
        sgdisk -n 3:0:0 -t 3:8300 "$disco"
    else
        # Criar partição root com o espaço restante
        sgdisk -n 2:0:0 -t 2:8300 "$disco"
    fi
}

# Função para formatar e montar partições
formatar_montar_particoes() {
    local disco=$1
    local tipo_sistema=$2
    local criar_swap=$3

    if [ "$tipo_sistema" = "EFI" ]; then
        mkfs.fat -F32 "${disco}1"
        mkfs.ext4 "${disco}3"
        mount "${disco}3" /mnt
        mkdir -p /mnt/boot
        mount "${disco}1" /mnt/boot
    else
        mkfs.ext4 "${disco}2"
        mount "${disco}2" /mnt
        mkdir -p /mnt/boot
        mount "${disco}1" /mnt/boot
    fi

    if [ "$criar_swap" = "sim" ]; then
        mkswap "${disco}2"
        swapon "${disco}2"
    fi
}

# Função para verificar se as partições estão montadas
verificar_montagem() {
    if ! mountpoint -q /mnt; then
        echo "/mnt não está montado. Montando partições..."
        formatar_montar_particoes "$disco" "$tipo_sistema" "$criar_swap"
    else
        echo "/mnt está montado corretamente."
    fi

    if ! mountpoint -q /mnt/boot; then
        echo "/mnt/boot não está montado. Montando partições..."
        formatar_montar_particoes "$disco" "$tipo_sistema" "$criar_swap"
    else
        echo "/mnt/boot está montado corretamente."
    fi
}

# Solicitar informações ao usuário
echo "Bem-vindo ao script de instalação do Arch Linux!"
echo "Por favor, forneça as seguintes informações:"

read -p "Digite o caminho do disco a ser particionado (ex: /dev/sda): " disco
read -p "Seu sistema é BIOS ou EFI? " tipo_sistema
read -p "Deseja usar GRUB ou systemd-boot como bootloader? " bootloader
read -p "Deseja criar uma partição de swap? (sim/não): " criar_swap

if [ "$criar_swap" = "sim" ]; then
    ram_total=$(free -g | awk '/^Mem:/{print $2}')
    echo "Tamanho da RAM detectado: ${ram_total}GB"
    read -p "Digite o tamanho da partição swap em GB (recomendado: ${ram_total}GB): " tamanho_swap
else
    tamanho_swap=0
fi

read -p "Digite o nome de usuário: " nome_usuario
read -p "Digite o hostname: " hostname
read -s -p "Digite a senha do usuário: " senha_usuario
echo
read -p "Este usuário deve ser um superusuário? (sim/não): " super_usuario

echo "Selecione o ambiente de desktop (Desktop Environment):"
echo "1) GNOME"
echo "2) KDE"
echo "3) XFCE"
echo "4) Xorg (minimal)"
echo "5) Nenhum"
read -p "Digite o número correspondente à sua escolha: " de_choice

echo "Selecione o driver de áudio:"
echo "1) PulseAudio"
echo "2) PipeWire"
read -p "Digite o número correspondente à sua escolha: " audio_choice

echo "Selecione os drivers de vídeo (separados por espaço):"
echo "1) Intel"
echo "2) AMD"
echo "3) NVIDIA (proprietário)"
echo "4) NVIDIA (open source)"
echo "5) Drivers de vídeo para máquinas virtuais"
read -p "Digite os números correspondentes à sua escolha: " video_choices

# Criar o diretório para armazenar o segundo script
mkdir -p /home/cameiras

# Criar partições
criar_particoes "$disco" "$criar_swap" "$tamanho_swap" "$tipo_sistema"

echo "Particionamento concluído!"
echo "Partições criadas:"
sgdisk -p "$disco"

# Verificar e montar partições
verificar_montagem

# Criar o segundo script para instalação
cat <<EOF > /home/cameiras/part2.sh
#!/bin/bash

# Instalação do sistema base
pacstrap /mnt base base-devel linux linux-firmware

# Geração do fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Configuração do sistema, bootloader, locale, fuso horário, usuário e rede
arch-chroot /mnt <<EOC
# Configuração do locale
echo "pt_BR.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=pt_BR.UTF-8" > /etc/locale.conf

# Configuração do fuso horário
ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
hwclock --systohc

# Configuração do hostname
echo "$hostname" > /etc/hostname

# Criação do usuário
useradd -m $nome_usuario
echo "$nome_usuario:$senha_usuario" | chpasswd
usermod -aG wheel,audio,video $nome_usuario
if [ "$super_usuario" = "sim" ]; then
    echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers
fi

# Instalação e configuração do NetworkManager
pacman -S --noconfirm networkmanager

# Instalação dos programas adicionais
pacman -S --noconfirm git vim wget

# Habilitação dos serviços
systemctl enable NetworkManager

# Instalação do ambiente de desktop
case $de_choice in
    1)
        pacman -S --noconfirm gnome gnome-extra gdm
        systemctl enable gdm
        ;;
    2)
        pacman -S --noconfirm plasma kde-applications sddm
        systemctl enable sddm
        ;;
    3)
        pacman -S --noconfirm xfce4 xfce4-goodies lightdm lightdm-gtk-greeter
        systemctl enable lightdm
        ;;
    4)
        pacman -S --noconfirm xorg xorg-xinit ly polkit-gnome
        systemctl enable ly
        ;;
    5)
        echo "Nenhum ambiente de desktop será instalado."
        ;;
    *)
        echo "Opção inválida. Nenhum ambiente de desktop será instalado."
        ;;
esac

# Instalação do driver de áudio
case $audio_choice in
    1)
        pacman -S --noconfirm pulseaudio
        ;;
    2)
        pacman -S --noconfirm pipewire pipewire-pulse
        ;;
    *)
        echo "Opção inválida. Nenhum driver de áudio será instalado."
        ;;
esac

# Instalação dos drivers de vídeo
for choice in $video_choices; do
    case \$choice in
        1)
            pacman -S --noconfirm xf86-video-intel
            ;;
        2)
            pacman -S --noconfirm xf86-video-amdgpu
            ;;
        3)
            pacman -S --noconfirm nvidia nvidia-utils
            ;;
        4)
            pacman -S --noconfirm xf86-video-nouveau
            ;;
        5)
            pacman -S --noconfirm xf86-video-vesa xf86-video-vmware
            ;;
        *)
            echo "Opção inválida. Nenhum driver de vídeo será instalado."
            ;;
    esac
done

# Configuração do bootloader
if [ "$bootloader" = "GRUB" ]; then
    pacman -S --noconfirm grub
    if [ "$tipo_sistema" = "EFI" ]; then
        pacman -S --noconfirm efibootmgr
        grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    else
        grub-install --target=i386-pc $disco
    fi
    grub-mkconfig -o /boot/grub/grub.cfg
else
    bootctl install
    echo "default arch" > /boot/loader/loader.conf
    echo "timeout 3" >> /boot/loader/loader.conf
    echo "editor 0" >> /boot/loader/loader.conf
    echo "title Arch Linux" > /boot/loader/entries/arch.conf
    echo "linux /vmlinuz-linux" >> /boot/loader/entries/arch.conf
    echo "initrd /initramfs-linux.img" >> /boot/loader/entries/arch.conf
    echo "options root=PARTUUID=\$(blkid -s PARTUUID -o value ${disco}3) rw" >> /boot/loader/entries/arch.conf
fi
EOC

echo "Instalação básica concluída!"
echo "O sistema está configurado com locale pt_BR.UTF-8 e fuso horário America/Sao_Paulo."
echo "Um usuário foi criado com o nome $nome_usuario."
echo "O hostname foi definido como $hostname."
echo "O NetworkManager foi instalado e habilitado para iniciar com o sistema."
echo "Os programas git, vim e wget foram instalados."
echo "Reinicie o sistema e conecte-se à rede usando 'nmcli' ou 'nmtui'."
EOF

# Tornar o segundo script executável
chmod +x /home/cameiras/part2.sh

# Executar o segundo script
/home/cameiras/part2.sh
