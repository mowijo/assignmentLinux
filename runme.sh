#!/bin/bash


# libelf-dev



function installPackages()
{

  echo "The script will now install packages required. For that you need to sudo."
  echo "If you dont like to grant sudo to an arbitrary script from the internet, "
  echo "remove the apt-get command from this script and install the packages prior"
  echo "to execution."

  sudo apt-get install  wget xz-utils bzip2 build-essential flex bison bc libelf-dev libssl-dev xorriso qemu-system-x86
}

function buildImage()
{

  KERNEL_VERSION=6.6.7
  BUSYBOX_VERSION=1.33.0
  SYSLINUX_VERSION=6.03

  rm -rf isoimage
  rm -rf _install/{dev,proc,sys}
  rm -rf linux-${KERNEL_VERSION}
  rm -rf busybox-${BUSYBOX_VERSION}
  rm -rf syslinux-${SYSLINUX_VERSION}



  wget -O kernel.tar.xz http://kernel.org/pub/linux/kernel/v6.x/linux-${KERNEL_VERSION}.tar.xz
  wget -O busybox.tar.bz2 http://busybox.net/downloads/busybox-${BUSYBOX_VERSION}.tar.bz2
  wget -O syslinux.tar.xz http://kernel.org/pub/linux/utils/boot/syslinux/syslinux-${SYSLINUX_VERSION}.tar.xz
  tar -xvf kernel.tar.xz
  tar -xvf busybox.tar.bz2
  tar -xvf syslinux.tar.xz


  mkdir isoimage
  cd busybox-${BUSYBOX_VERSION}
  make defconfig

  sed -i "s|.*CONFIG_STATIC.*|CONFIG_STATIC=y|" .config
  echo "CONFIG_STATIC_LIBGCC=y" >> .config

  make busybox install -j `nproc`
  cd _install
  rm -f linuxrc
  mkdir -p dev proc sys
  echo '#!/bin/sh' > init
  echo 'dmesg -n 1' >> init
  echo 'mount -t devtmpfs none /dev' >> init
  echo 'mount -t proc none /proc' >> init
  echo 'mount -t sysfs none /sys' >> init
  echo 'setsid cttyhack /bin/helloWorld' >> init


  echo "/bin/sh -c 'echo -e \"\n\nhello world\n\n\"' ; /bin/sh" > bin/helloWorld
  chmod ugo+x bin/helloWorld

  chmod +x init
  find . | cpio -R root:root -H newc -o | gzip > ../../isoimage/rootfs.gz
  cd ../../linux-${KERNEL_VERSION}
  make defconfig bzImage -j `nproc`
  cp arch/x86/boot/bzImage ../isoimage/kernel.gz
  cd ../isoimage
  cp ../syslinux-${SYSLINUX_VERSION}/bios/core/isolinux.bin .
  cp ../syslinux-${SYSLINUX_VERSION}/bios/com32/elflink/ldlinux/ldlinux.c32 .
  echo 'default kernel.gz initrd=rootfs.gz' > ./isolinux.cfg
  xorriso \
    -as mkisofs \
    -o ../minimal_linux_live.iso \
    -b isolinux.bin \
    -c boot.cat \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    ./
  cd ..

}


function launchImage()
{
  qemu-system-x86_64 -boot d -cdrom minimal_linux_live.iso -m 512
}

installPackages

set -ex

pushd .
buildImage
popd
launchImage

set +ex
