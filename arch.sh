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

while true; do
    echo "Escolha um Bootloader"
    echo "1. Systemdboot"
    echo "2. GRUB"
    read BOOT

    # Check if input is either 1 or 2
    if [[ $BOOT == 1 || $BOOT == 2 ]]; then
        break
    else
        echo "Invalid input. Please enter either 1 or 2."
    fi
done

# Criando sistema de arquivos

echo -e "\nCriando Sistema de Arquivos...\n"

existing_fs=$(blkid -s TYPE -o value "$EFI")
if [[ "$existing_fs" != "vfat" ]]; then
    mkfs.vfat -F32 "$EFI"
fi

mkfs.ext4 "${ROOT}"

# mount target
mount "${ROOT}" /mnt
ROOT_UUID=$(blkid -s UUID -o value "$ROOT")
if [[ $BOOT == 1 ]]; then
    mount --mkdir "$EFI" /mnt/boot
else
    mount --mkdir "$EFI" /mnt/boot/efi
fi

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
127.0.0.1	localhost
::1			localhost
127.0.1.1	archlinux.localdomain	archlinux
EOF



echo "-------------------------------------"
echo "-------INSTALANDO BOOTLOADER---------"	
echo "-------------------------------------"



if [[ $BOOT == 1 ]]; then
    bootctl install --path=/boot
    echo "default arch.conf" >> /boot/loader/loader.conf
    cat <<EOF > /boot/loader/entries/arch.conf
title Arch Linux
linux /vmlinuz-linux
initrd /initramfs-linux.img
options root=UUID=$ROOT_UUID rw quiet
EOF
else
    pacman -S grub efibootmgr --noconfirm --needed
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id="Linux Boot Manager"
    grub-mkconfig -o /boot/grub/grub.cfg
fi



echo "-----------------------------------------------------"
echo "-------------DISPLAY E DRIVERS DE AUDIO--------------"
echo "-----------------------------------------------------"

pacman -S xorg pulseaudio --noconfirm --needed

systemctl enable NetworkManager

#DESKTOP
if [[ $DESKTOP == '1' ]]
then
    pacman -S gnome gdm --noconfirm --needed
    systemctl enable gdm

elif [[ $DESKTOP == '2' ]]
then
    pacman -S plasma sddm kde-applications --noconfirm --needed
    systemctl enable sddm


elif [[ $DESKTOP == '3' ]]
then
    pacman -S xfce4 xfce4-goodies lightdm lightdm-gtk-greeter --noconfirm -needed
    systemctl enable lightdm
else
    echo "Faça a instalação você mesmo"
fi

echo "-------------------------------------------------------"
echo "---------INSTALAÇÃO COMPLETA - FAÇA UM REBOOT----------"
echo "-------------------------------------------------------"

REALEND

arch-chroot /mnt sh next.sh
