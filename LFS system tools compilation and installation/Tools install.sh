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





