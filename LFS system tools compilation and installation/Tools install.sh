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
tar -xf gcc-4.6.2.tar.bz2
cd gcc-4.6.2
patch -Np1 -i ../gcc-4.6.2-startfiles_fix-1.patch
cp -v gcc/Makefile.in{,.orig}

sed 's@\./fixinc\.sh@-c true@' gcc/Makefile.in.orig > gcc/Makefile.in
cp -v gcc/Makefile.in{,.tmp}

sed 's/^T_CFLAGS =$/& -fomit-frame-pointer/' gcc/Makefile.in.tmp \
> gcc/Makefile.in

for file in \
$(find gcc/config -name linux64.h -o -name linux.h -o -name sysv4.h)
do
cp -uv $file{,.orig}
sed -e 's@/lib\(64\)\?\(32\)\?/ld@/tools&@g' \
-e 's@/usr@/tools@g' $file.orig > $file
echo '
#undef STANDARD_INCLUDE_DIR
#define STANDARD_INCLUDE_DIR 0
#define STANDARD_STARTFILE_PREFIX_1 ""
#define STANDARD_STARTFILE_PREFIX_2 ""' >> $file
touch $file.orig
done

case $(uname -m) in
x86_64)
for file in $(find gcc/config -name t-linux64) ; do \
cp -v $file{,.orig}
sed '/MULTILIB_OSDIRNAMES/d' $file.orig > $file
done
;;
esac

tar -jxf ../mpfr-3.1.0.tar.bz2
mv -v mpfr-3.1.0 mpfr
tar -Jxf ../gmp-5.0.4.tar.xz
mv -v gmp-5.0.4 gmp
tar -zxf ../mpc-0.9.tar.gz
mv -v mpc-0.9 mpc

mkdir -v ../gcc-build
cd ../gcc-build

CC="$LFS_TGT-gcc -B/tools/lib/" \
AR=$LFS_TGT-ar RANLIB=$LFS_TGT-ranlib \
../gcc-4.6.2/configure --prefix=/tools \
--with-local-prefix=/tools --enable-clocale=gnu \
--enable-shared --enable-threads=posix \
--enable-__cxa_atexit --enable-languages=c,c++ \
--disable-libstdcxx-pch --disable-multilib \
--disable-bootstrap --disable-libgomp \
--without-ppl --without-cloog \
--with-mpfr-include=$(pwd)/../gcc-4.6.2/mpfr/src \
--with-mpfr-lib=$(pwd)/mpfr/src/.libs
make
make install
ln -vs gcc /tools/bin/cc
cd ..
rm -rf gcc-build
rm -rf gcc-4.6.2

#installation of TCL
tar -xf tcl8.5.11-src.tar.gz 
cd tcl8.5.11
cd unix
./configure --prefix=/tools
make
TZ=UTC make test
make install
chmod -v u+w /tools/lib/libtcl8.5.so
make install-private-headers
ln -sv tclsh8.5 /tools/bin/tclsh
cd ..

#installation of expect
tar -xf expect5.45.tar.gz
cd expect5.45
cp -v configure{,.orig}
sed 's:/usr/local/bin:/bin:' configure.orig > configure
./configure --prefix=/tools --with-tcl=/tools/lib \
--with-tclinclude=/tools/include
make
make test
make SCRIPTS="" install
cd ..

#installation of Deja GNU
tar -xf dejagnu-1.5.tar.gz
cd dejagnu-1.5
./configure --prefix=/tools
make install
make check
cd ..

#check
tar -xf check-0.9.8.tar.gz
cd check-0.9.8
./configure --prefix=/tools
make
make check
make install
cd ..
rm -rf tcl8.5.11
rm -rf expect5.45
rm -rf dejagnu-1.5
rm -rf check-0.9.8


