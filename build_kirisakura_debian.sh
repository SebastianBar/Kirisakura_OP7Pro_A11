#!/bin/bash

echo "Extend ulimit..."
ulimit -s 65536

#echo
#echo "Clean build directory..."
#make clean &> /dev/null && make mrproper &> /dev/null

echo
echo "Setup environment variables..."
export ARCH=arm64
export SUBARCH=arm64
export CLANG_PATH=/tools/google-clang/bin
export AOSP_GCC_ARM64_PATH=/tools/aosp-gcc-arm64/bin
export AOSP_GCC_ARM_PATH=/tools/aosp-gcc-arm/bin
export AOSP_GCC_HOST_PATH=/tools/aosp-gcc-host/bin
export LIBUFDT_PATH=/tools/libufdt
export PATH=${CLANG_PATH}:${AOSP_GCC_ARM64_PATH}:${AOSP_GCC_ARM_PATH}:${AOSP_GCC_HOST_PATH}:${LIBUFDT_PATH}:${PATH}
export LD_LIBRARY_PATH=${CLANG_PATH}:${LD_LIBRARY_PATH}
export CLANG_TRIPLE=aarch64-linux-gnu-
export CROSS_COMPILE=/tools/aosp-gcc-arm64/bin/aarch64-linux-android-
export CROSS_COMPILE_ARM32=/tools/aosp-gcc-arm/bin/arm-linux-androideabi-

outfolder="out"
mkdir -p ${outfolder}

echo
echo "Setup DEFCONFIG..."
make CC=clang HOSTCC=clang HOSTCXX=clang++ AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip READELF=llvm-readelf LLVM_IAS=1 O=${outfolder} kirisakura_defconfig || exit 1

echo
echo "Build the kernel..."
make CC=clang HOSTCC=clang HOSTCXX=clang++ AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip READELF=llvm-readelf LLVM_IAS=1 O=${outfolder} -j$(nproc --all) || exit 1

echo
echo "Packaging the kernel..."
IMAGE="Image.gz-dtb"
date="$(date +%d%m%Y-%I%M)"
zip_filename="kirisakura-kernel.zip"

git clone https://github.com/lemniskett/AnyKernel3 zipper

cp ${outfolder}/arch/"$ARCH"/boot/"$IMAGE" zipper/"$IMAGE"
cd zipper
rm -rf .git .gitignore LICENSE README.md
sed -i 's/do.devicecheck=1/do.devicecheck=0/g' anykernel.sh
zip -r9 "$zip_filename" . || exit 1
echo ::set_output name=outfile::"$(pwd)"/"$zip_filename"
