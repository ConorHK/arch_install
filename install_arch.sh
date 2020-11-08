#! bin/sh
# Based heavily on Altercation's bullet proof guide.

DRIVE=/dev/$1

sgdisk --zap-all $DRIVE

sgdisk --clear \
       --new=1:0:+550MiB --typecode=1:ef00 --change-name=1:EFI \
       --new=2:0:+8GiB   --typecode=2:8200 --change-name=2:cryptswap \
       --new=3:0:0       --typecode=3:8300 --change-name=3:cryptsystem \
         $DRIVE

mkfs.fat -F32 -n EFI /dev/disk/by-partlabel/EFI

cryptsetup luksFormat --align-payload=8192 -s 256 -c aes-xts-plain64 /dev/disk/by-partlabel/cryptsystem

cryptsetup open /dev/disk/by-partlabel/cryptsystem system

cryptsetup open --type plain --key-file /dev/urandom /dev/disk/by-partlabel/cryptswap swap

mkswap -L swap /dev/mapper/swap

swapon -L swap

mkfs.btrfs --force --label system /dev/mapper/system

o=defaults,x-mount.mkdir

o_btrfs=$o,compress=lzo,ssd,noatime

mount -t btrfs LABEL=system /mnt

btrfs subvolume create /mnt/root

btrfs subvolume create /mnt/home

btrfs subvolume create /mnt/snapshots

umount -R /mnt

mount -t btrfs -o subvol=root,$o_btrfs LABEL=system /mnt

mount -t btrfs -o subvol=home,$o_btrfs LABEL=system /mnt/home

mount -t btrfs -o subvol=snapshots,$o_btrfs LABEL=system /mnt/.snapshots

pacstrap /mnt base

genfstab -L -p /mnt >> /mnt/etc/fstab

sed -i "s+LABEL=swap+/dev/mapper/swap" /mnt/etc/fstab

systemd-nspawn -bD /mnt

echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen

locale-gen

localectl set-locale LANG=en_US.UTF-8

timedatectl set-ntp 1

timedatectl set-timezone Europe/Dublin

hostnamectl set-hostname $2

echo "127.0.1.1	$2.localdomain	$2" >> /etc/hosts

pacman -Syu base-devel btrfs-progs iw gptfdisk zsh vim
