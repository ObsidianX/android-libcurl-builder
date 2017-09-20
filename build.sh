#!/bin/bash

# Download and build curl, openssl for Android

# Make the working directory
mkdir curl-android-build
cd curl-android-build
ROOT_DIR=`pwd -P`
echo Building curl for Android in $ROOT_DIR

OUTPUT_DIR=$ROOT_DIR/..
mkdir $OUTPUT_DIR

# NDK environment variables
# arm64-v8a
#API=21
#ABI=arm64-v8a
#TOOLCHAIN_ARCH=arm64
#EXPORTED_ARCH=armv8-a
#OPENSSL_ARCH=android64-aarch64
#HOST=aarch64-linux-android

# armeabi-v7a
API=19
ABI=armeabi-v7a
TOOLCHAIN_ARCH=arm
EXPORTED_ARCH=armv7-a
OPENSSL_ARCH=android-armeabi
HOST=arm-linux-androideabi

PLATFORM=android-${API}

# Create standalone toolchain for cross-compiling
$ANDROID_NDK_ROOT/build/tools/make-standalone-toolchain.sh --arch=${TOOLCHAIN_ARCH} --platform=$PLATFORM --install-dir=ndk-standalone-toolchain-${TOOLCHAIN_ARCH} --verbose
TOOLCHAIN=$ROOT_DIR/ndk-standalone-toolchain-${TOOLCHAIN_ARCH}

# Setup cross-compile environment
export PATH=$PATH:$TOOLCHAIN/bin
export SYSROOT=$TOOLCHAIN/sysroot
export CROSS_SYSROOT=$SYSROOT
export ARCH=${EXPORTED_ARCH}
export CHOST=${HOST}
export CC=${CHOST}-clang
export CXX=${CHOST}-clang++
export AR=llvm-ar
export AS=llvm-as
export LD=${CHOST}-clang
export RANLIB=${CHOST}-ranlib
export NM=${CHOST}-nm
export STRIP=${CHOST}-strip

# Download and build openssl
OPENSSL_OUTPUTDIR=${OUTPUT_DIR}/openssl
OPENSSL_VERSION=openssl-1.1.0f
OPENSSL_DIR=$ROOT_DIR/${OPENSSL_VERSION}

curl "https://www.openssl.org/source/${OPENSSL_VERSION}.tar.gz" -o "${OPENSSL_VERSION}.tar.gz"
tar -xvf ${OPENSSL_VERSION}.tar.gz 
cd ${OPENSSL_DIR}
patch -p1 < ${ROOT_DIR}/../patches/openssl-1.1.0f-android-arm64-clang.patch
export CPPFLAGS="-mthumb -mfloat-abi=softfp -mfpu=vfp -march=${ARCH}  -DANDROID -sysroot=${SYSROOT} -D__ANDROID_API_=${API}"
export LDFLAGS="-L${ANDROID_NDK_ROOT}/platforms/${PLATFORM}/arch-${TOOLCHAIN_ARCH}/usr/lib"
./Configure ${OPENSSL_ARCH} no-stdio no-asm no-shared no-engine --static -D__ANDROID_API_=${API} ${LDFLAGS} -DANDROID
make V=1

# Copy openssl lib and includes to output directory
mkdir -p ${OPENSSL_OUTPUTDIR}/lib/${ABI}
mkdir ${OPENSSL_OUTPUTDIR}/include
cp libssl.a ${OPENSSL_OUTPUTDIR}/lib/${ABI}
cp libcrypto.a ${OPENSSL_OUTPUTDIR}/lib/${ABI}
cp -LR include/openssl ${OPENSSL_OUTPUTDIR}/include
cd ..

# Download and build libcurl
CURL_VERSION=curl-7.55.1
CURL_DIR=$ROOT_DIR/${CURL_VERSION}
curl "https://curl.haxx.se/download/${CURL_VERSION}.tar.gz" -o "${CURL_VERSION}.tar.gz"
tar -xvf ${CURL_VERSION}.tar.gz 
cd ${CURL_DIR}
patch -p1 < ${ROOT_DIR}/../patches/curl-7.55.1-openssl-1.1.0f.patch
export CFLAGS="-v --sysroot=${SYSROOT}" # -mandroid -march=${ARCH} -mfloat-abi=softfp -mfpu=vfp -mthumb"
export CPPFLAGS="${CFLAGS} -DCURL_STATICLIB -D__ANDROID_API__=${API} -march=${ARCH} -I${OPENSSL_DIR}/include/ -I${TOOLCHAIN}/include" # -mthumb -mfloat-abi=softfp -mfpu=vfp 
export LDFLAGS="-march=${ARCH} -L${OPENSSL_DIR}" # -Wl,--fix-cortex-a8
./configure --host=${CHOST} --disable-shared --enable-static --disable-dependency-tracking --with-ssl=${OPENSSL_DIR} --without-ca-bundle --without-ca-path --enable-ipv6 --enable-http --disable-ftp --enable-file --disable-ldap --disable-ldaps --disable-rtsp --disable-proxy --disable-dict --disable-telnet --disable-tftp --disable-pop3 --disable-imap --disable-smtp --disable-gopher --disable-sspi --disable-manual --target=${CHOST} --prefix=/opt/curlssl 
if [[ $? == 0 ]] ; then
	make V=1
else
	exit
fi

# Copy libcurl and includes to output directory
mkdir -p $OUTPUT_DIR/curl/lib/${ABI}
mkdir $OUTPUT_DIR/curl/include
cp lib/.libs/libcurl.a $OUTPUT_DIR/curl/lib/${ABI}
cp -LR include/curl $OUTPUT_DIR/curl/include
cd ..

#rm -rf ${ROOT_DIR}
