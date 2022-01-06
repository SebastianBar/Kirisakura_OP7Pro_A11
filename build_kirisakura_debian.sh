#!/bin/bash
export DEBIAN_FRONTEND=noninteractive

echo
echo "Update host OS..."
apt-get -qq update &> /dev/null
apt-get -qq dist-upgrade &> /dev/null
# From https://source.android.com/setup/build/initializing#installing-required-packages-ubuntu-1804
apt-get -qq install git-core gnupg flex bison build-essential zip curl zlib1g-dev gcc-multilib g++-multilib libc6-dev-i386 libncurses5 lib32ncurses5-dev x11proto-core-dev libx11-dev lib32z1-dev libgl1-mesa-dev libxml2-utils xsltproc unzip fontconfig &> /dev/null
# cpio required for something I don't remember, zip for final output
apt-get -qq install zip cpio mkbootimg libssl-dev bc binutils binutils-aarch64-linux-gnu binutils-arm-linux-gnueabi &> /dev/null
apt-get -qq autoremove &> /dev/null

echo
echo "Clean build directory..."
make clean &> /dev/null && make mrproper &> /dev/null

echo
echo "Setup dependencies and issue build commands"

mkdir -p .tmp
echo " - Downloading Google's clang-r437112b..."
curl -s -L -o .tmp/google-clang.tar.gz https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/master/clang-r437112b.tar.gz
echo " - Downloading gcc-aarch64..."
curl -s -L -o .tmp/aosp-gcc-arm64.tar.gz https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/+archive/refs/tags/ndk-r22.tar.gz
echo " - Downloading gcc-arm..."
curl -s -L -o .tmp/aosp-gcc-arm.tar.gz https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9/+archive/refs/tags/ndk-r22.tar.gz
echo " - Downloading aosp-gcc-host..."
curl -s -L -o .tmp/aosp-gcc-host.tar.gz https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/host/x86_64-linux-glibc2.17-4.8/+archive/refs/heads/master.tar.gz
echo " - Downloading libufdt..."
curl -s -L -o .tmp/libufdt.tar.gz https://android.googlesource.com/platform/prebuilts/misc/+archive/refs/heads/master/linux-x86/libufdt.tar.gz

mkdir -p .tools
echo " - Extracting Google's clang-r437112b..."
mkdir .tools/google-clang && tar -zxf .tmp/google-clang.tar.gz -C .tools/google-clang
echo " - Extracting gcc-aarch64..."
mkdir .tools/aosp-gcc-arm64 && tar -zxf .tmp/aosp-gcc-arm64.tar.gz -C .tools/aosp-gcc-arm64
echo " - Extracting gcc-arm..."
mkdir .tools/aosp-gcc-arm && tar -zxf .tmp/aosp-gcc-arm.tar.gz -C .tools/aosp-gcc-arm
echo " - Extracting aosp-gcc-host..."
mkdir .tools/aosp-gcc-host && tar -zxf .tmp/aosp-gcc-host.tar.gz -C .tools/aosp-gcc-host
# libufdt required for boot image
echo " - Extracting libufdt..."
mkdir .tools/libufdt && tar -zxf .tmp/libufdt.tar.gz -C .tools/libufdt


echo " - Cleaning up .tar.gz files..."
rm -rf .tmp

export ARCH=arm64
export SUBARCH=arm64
export CLANG_PATH=$(pwd)/.tools/google-clang/bin
export AOSP_GCC_ARM64_PATH=$(pwd)/.tools/aosp-gcc-arm64/bin
export AOSP_GCC_ARM_PATH=$(pwd)/.tools/aosp-gcc-arm/bin
export AOSP_GCC_HOST_PATH=$(pwd)/.tools/aosp-gcc-host/bin
export LIBUFDT_PATH=$(pwd)/.tools/libufdt
export PATH=${CLANG_PATH}:${AOSP_GCC_ARM64_PATH}:${AOSP_GCC_ARM_PATH}:${AOSP_GCC_HOST_PATH}:${LIBUFDT_PATH}:${PATH}
export LD_LIBRARY_PATH=${CLANG_PATH}:${LD_LIBRARY_PATH}
export CLANG_TRIPLE=aarch64-linux-gnu-
export CROSS_COMPILE=$(pwd)/.tools/aosp-gcc-arm64/bin/aarch64-linux-android-
export CROSS_COMPILE_ARM32=$(pwd)/.tools/aosp-gcc-arm/bin/arm-linux-androideabi-

mkdir -p out

echo "Extend ulimit..."
ulimit -s 65536

echo
echo "Set DEFCONFIG..."
make CC=clang HOSTCC=clang HOSTCXX=clang++ AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip READELF=llvm-readelf LLVM_IAS=1 O=out kirisakura_defconfig || exit 1

echo
echo "Build the kernel..."
make CC=clang HOSTCC=clang HOSTCXX=clang++ AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip READELF=llvm-readelf LLVM_IAS=1 O=out -j$(nproc --all) || exit 1

echo
echo "Packaging the kernel..."
IMAGE="Image.gz-dtb"
date="$(date +%d%m%Y-%I%M)"
zip_filename="kirisakura-kernel.zip"

git clone https://github.com/lemniskett/AnyKernel3 zipper

cp out/arch/"$ARCH"/boot/"$IMAGE" zipper/"$IMAGE"
cd zipper
rm -rf .git .gitignore LICENSE README.md
sed -i 's/do.devicecheck=1/do.devicecheck=0/g' anykernel.sh
zip -r9 "$zip_filename" . || exit 1
echo ::set_output name=outfile::"$(pwd)"/"$zip_filename"
