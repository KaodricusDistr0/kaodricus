#!/bin/sh

#to be ran as lfs user

cd $LFS/sources

#binutils installation
tar -jxf binutils-2.22.tar.bz2
mkdir -v binutils-build
cd binutils-build
time { ../binutils-2.22/configure --target=$LFS_TGT --prefix=/tools --disable-nls --disable-werror && make && make install; }
cd ..
rm -rf binutils-2.22
rm -rf binutils-build

#gcc compilation and installation
tar -xf gcc-4.6.2.tar.bz2
cd gcc-4.6.2
tar -jxf ../mpfr-3.1.0.tar.bz2
mv -v mpfr-3.1.0 mpfr
tar -Jxf ../gmp-5.0.4.tar.xz
mv -v gmp-5.0.4 gmp
tar -zxf ../mpc-0.9.tar.gz
mv -v mpc-0.9 mpc
patch -Np1 -i ../gcc-4.6.2-cross_compile-1.patch
mkdir -v ../gcc-build
cd ../gcc-build
../gcc-4.6.2/configure \
--target=$LFS_TGT --prefix=/tools \
--disable-nls --disable-shared --disable-multilib \
--disable-decimal-float --disable-threads \
--disable-libmudflap --disable-libssp \
--disable-libgomp --disable-libquadmath \
--disable-target-libiberty --disable-target-zlib \
--enable-languages=c --without-ppl --without-cloog \
--with-mpfr-include=$(pwd)/../gcc-4.6.2/mpfr/src \
--with-mpfr-lib=$(pwd)/mpfr/src/.libs
make
make install
ln -vs libgcc.a `$LFS_TGT-gcc -print-libgcc-file-name | \
sed 's/libgcc/&_eh/'`
cd ..
rm -rf gcc-4.6.2
rm -rf gcc-build

#linux headers installation
tar -xf linux-3.2.6.tar.xz
cd linux-3.2.6
make mrproper
make headers_check
make INSTALL_HDR_PATH=dest header_install
cp -rv dest/include/* /tools/include
cd ..
rm -rf linux-3.2.6

#glibc installation 
tar -xf glibc-2.14.1.tar.bz2
cd glibc-2.14.1
patch -Np1 -i ../glibc-2.14.1-gcc_fix-1.patch
patch -Np1 -i ../glibc-2.14.1-cpuid-1.patch
mkdir -v ../glibc-build
cd ../glibc-build
case `uname -m` in
i?86) echo "CFLAGS += -march=i486 -mtune=native" > configparms ;;
esac
../glibc-2.14.1/configure --prefix=/tools \
--host=$LFS_TGT --build=$(../glibc-2.14.1/scripts/config.guess) \
--disable-profile --enable-add-ons \
--enable-kernel=2.6.25 --with-headers=/tools/include \
libc_cv_forced_unwind=yes libc_cv_c_cleanup=yes
make
make install
cd ..
rm -rf glibc-build
rm -rf glibc-2.14.1

#adjusting the loolchaint
SPECS=`dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/specs
$LFS_TGT-gcc -dumpspecs | sed \
-e 's@/lib\(64\)\?/ld@/tools&@g' \
-e "/^\*cpp:$/{n;s,$, -isystem /tools/include,}" > $SPECS
echo "New specs file is: $SPECS"
unset SPECS

#binutils pass2
tar -jxf binutils-2.22.tar.bz2
mkdir -v binutils-build
cd binutils-build
CC="$LFS_TGT-gcc -B/tools/lib/" \
AR=$LFS_TGT-ar RANLIB=$LFS_TGT-ranlib \
../binutils-2.22/configure --prefix=/tools \
--disable-nls --with-lib-path=/tools/lib
make
make install
make -C ld clean
make -C ld LIB_PATH=/usr/lib:/lib
cd ..
rm -rf binutils-2.22
rm -rf binutils-build

#gcc pass2






