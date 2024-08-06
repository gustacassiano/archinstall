#!/usr/bin/env bash

echo "Defina a partição de EFI: (exemplo /dev/sda1 ou /dev/nvme0n1p1)"

read EFI

echo "Defina partição de SWAP (exemplo /dev/sda2 ...)"

read SWAP

echo "Defina a partição de Root(/): (exemplo /dev/sda3)"

read ROOT

echo "Defina um username"

read USER

echo "Defina uma senha"

read PASSWORD

echo "Escolha um desktop Environment"
echo "1. GNOME"
echo "2. KDE"
echo "3. XFCE"
echo "4. NoDesktop"

read DESKTOP

# Criando sistema de arquivos

echo -e "\nCriando Sistema de Arquivos...\n"

mkfs.vfat -F32 -n "EFISYSTEM" "${EFI}"
mkswap "${SWAP}"
swapon "${SWAP}"
mkfs.ext4 -L "ROOT" "${ROOT}"

# Montando alvos

mount -t ext4 "${ROOT}" /mnt
mkdir /mnt/boot
mount -t vfat "${EFI}" /mnt/boot/

echo "---------------------------------------------------------"
echo "-------INSTALANDO ARCH LINUX NO DRIVE SELECIONADO--------"	
echo "---------------------------------------------------------"


pacstrap /mnt base base-devel --noconfirm --needed

# KERNEL 


pacstrap /mnt linux linux-firmware --noconfirm --needed


echo "-------------------------------------"
echo "--------AJUSTANDO DEPENDENCIAS-------"	
echo "-------------------------------------"


pacstrap /mnt networkmanager network-manager-applet wireless_tools vim nano intel-ucode git --noconfirm --needed

#FSTAB

genfstab -U /mnt >> /mnt/etc/fstab


echo "-------------------------------------"
echo "-------INSTALANDO BOOTLOADER---------"	
echo "-------------------------------------"

bootctl install --path /mnt/boot
echo "default arch.conf" >> /mnt/boot/loader/loader.conf
cat <<EOF > /mnt/boot/loader/entries/arch.conf
title Arch Linux /vmlinuz-linux
initrd /initramfs-linux.img
options root=${ROOT} rw
EOF

cat <<REALEND > /mnt/next.sh

useradd -m $USER
usermod -aG wheel,storage,power,audio $USER
echo $USER:$PASSWORD | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
echo "------------------------------------------------"
echo "Definindo idioma para PT-BR e definindo 'locale'"
echo "------------------------------------------------"
sed -i 's/^#pt_BR.UTF-8 UTF-8/pt_BR.UTF-8 UTF=8' /etc/locale.gen
locale-gen
echo "LANG=pt_BR.UTF-8" >> /etc/locale.conf

ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
hwclock --systohc

echo "arch" > /etc/hostname
cat <<EOF > /etc/hosts
127.0.0.1   localhost
EOF

echo "-----------------------------------------------------"
echo "-------------DISPLAY E DRIVERS DE AUDIO--------------"
echo "-----------------------------------------------------"

pacman -S xorg pulseaudio --noconfirm --needed

systemctl enable NetworkManager

#DESKTOP
if [[ $DESKTOP == '1']]
then
    pacman -S gnome gdm --noconfirm --needed

elif [[ $DESKTOP == '2']]
then
    pacman -S plasma sddm kde-applications --noconfirm --needed

elif [[ $DESKTOP == '3']]
then
    pacman -S xfce4 xfce4-goodies lightdm lightdm-gtk-greeter --noconfirm -needed

elif [[ $DESKTOP == '4']]
then
    echo "Faça a instalação você mesmo"
fi

echo "-------------------------------------------------------"
echo "---------INSTALAÇÃO COMPLETA - FAÇA UM REBOOT----------"
echo "-------------------------------------------------------"

REALEND

arch-chroot /mnt sh next.sh && git clone https://aur.archlinux.org/paru.git && cd paru && makepkg -si && cd
