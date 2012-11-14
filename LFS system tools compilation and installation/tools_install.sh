#!/bin/sh

#to be ran as lfs user

cd $LFS/sources

#binutils installation
tar -jxf binutils-2.22.tar.bz2
rc=$?
mkdir -v binutils-build
cd binutils-build
time { ../binutils-2.22/configure --target=$LFS_TGT --prefix=/tools --disable-nls --disable-werror && make && make install && rc2=$?; }

#test if all went good
if [ $rc != 0 ] || [ $rc2 != 0 ] ; then
    echo -e "\e[1;4;31mBinutils installation failed see script\e[0m"
    exit 1
else
    echo -e "\e[1;34mBinutils correctly configured and installed\e[0m"
fi
cd ..
rm -rf binutils-2.22
rm -rf binutils-build

#gcc compilation and installation
tar -xf gcc-4.6.2.tar.bz2
rc=$?
cd gcc-4.6.2
tar -jxf ../mpfr-3.1.0.tar.bz2
rc2=$?
mv -v mpfr-3.1.0 mpfr
tar -Jxf ../gmp-5.0.4.tar.xz
rc3=$?
mv -v gmp-5.0.4 gmp
tar -zxf ../mpc-0.9.tar.gz
rc4=$?

if [ $rc != 0 ] || [ $rc2 != 0 ] || [ $rc3 != 0 ] || [ $rc4 != 0 ] ; then
    echo -e "\e[1;4;31mFailed to open one of gcc, mpfr, gmp or mpc archives\e[0m"
    exit 1
else
    echo -e "\e[1;34mArchives opening done\e[0m"
fi

mv -v mpc-0.9 mpc
patch -Np1 -i ../gcc-4.6.2-cross_compile-1.patch
rc=$?
if [ $rc != 0 ] || [ $rc2 != 0 ] || [ $rc3 != 0 ] || [ $rc4 != 0 ] ; then
    echo -e "\e[1;4;31mmpc patch FAILED\e[0m"
    exit 1
else
    echo -e "\e[1;34mArchives opening done\e[0m"
fi

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
rc=$?
make
rc2=$?
make install
rc3=$?
ln -vs libgcc.a `$LFS_TGT-gcc -print-libgcc-file-name | \
sed 's/libgcc/&_eh/'`
rc4=$?

if [ $rc != 0 ] || [ $rc2 != 0 ] || [ $rc3 != 0 ] || [ $rc4 != 0 ] ; then
    echo -e "\e[1;4;31mProblem while installing libgcc\e[0m"
    exit 1
else
    echo -e "\e[1;34mLibgcc well installed\e[0m"
fi

cd ..
rm -rf gcc-4.6.2
rm -rf gcc-build

#linux headers installation
tar -xf linux-3.2.6.tar.xz
rc=$?
cd linux-3.2.6
make mrproper
rc2=$?
make headers_check
rc3=$?
make INSTALL_HDR_PATH=dest header_install
rc4=$?

if [ $rc != 0 ] || [ $rc2 != 0 ] || [ $rc3 != 0 ] || [ $rc4 != 0 ] ; then
    echo -e "\e[1;4;31mProblem while installing linux headers\e[0m"
    exit 1
else
    echo -e "\e[1;34mLinux headers well installed\e[0m"
fi

cp -rv dest/include/* /tools/include
cd ..
rm -rf linux-3.2.6

#glibc installation 
tar -xf glibc-2.14.1.tar.bz2
rc=$?
cd glibc-2.14.1
patch -Np1 -i ../glibc-2.14.1-gcc_fix-1.patch
rc2=$?
patch -Np1 -i ../glibc-2.14.1-cpuid-1.patch
rc3=$?

if [ $rc != 0 ] || [ $rc2 != 0 ] || [ $rc3 != 0 ] ; then
    echo -e "\e[1;4;31mProblem while patching glibc\e[0m"
    exit 1
else
    echo -e "\e[1;34mGlibc patched\e[0m"
fi

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
rc=$?
make
rc2=$?
make install
rc3=$?

if [ $rc != 0 ] || [ $rc2 != 0 ] || [ $rc3 != 0 ] ; then
    echo -e "\e[1;4;31mProblem while installing Glibc\e[0m"
    exit 1
else
    echo -e "\e[1;34mGlibc well installed\e[0m"
fi

cd ..
rm -rf glibc-build
rm -rf glibc-2.14.1

#adjusting the toolchain
SPECS=`dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/specs
$LFS_TGT-gcc -dumpspecs | sed \
-e 's@/lib\(64\)\?/ld@/tools&@g' \
-e "/^\*cpp:$/{n;s,$, -isystem /tools/include,}" > $SPECS
echo "New specs file is: $SPECS"
unset SPECS

#binutils pass2
tar -jxf binutils-2.22.tar.bz2
rc=$?
mkdir -v binutils-build
cd binutils-build
CC="$LFS_TGT-gcc -B/tools/lib/" \
AR=$LFS_TGT-ar RANLIB=$LFS_TGT-ranlib \
../binutils-2.22/configure --prefix=/tools \
--disable-nls --with-lib-path=/tools/lib
make
rc2=$?
make install
rc3=$?
make -C ld clean
rc4=$?
make -C ld LIB_PATH=/usr/lib:/lib
rc5=$?

if [ $rc != 0 ] || [ $rc2 != 0 ] || [ $rc3 != 0 ] || [ $rc4 != 0 ] || [ $rc5 != 0 ] ; then
    echo -e "\e[1;4;31mProblem while installing binutils (pass 2)\e[0m"
    exit 1
else
    echo -e "\e[1;34mBinutils (pass 2) well installed\e[0m"
fi

cd ..
rm -rf binutils-2.22
rm -rf binutils-build

#gcc pass2
tar -xf gcc-4.6.2.tar.bz2
rc=$?
cd gcc-4.6.2
patch -Np1 -i ../gcc-4.6.2-startfiles_fix-1.patch
rc2=$?
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
rc3=$?
mv -v mpfr-3.1.0 mpfr
tar -Jxf ../gmp-5.0.4.tar.xz
rc4=$?
mv -v gmp-5.0.4 gmp
tar -zxf ../mpc-0.9.tar.gz
rc5=$?
mv -v mpc-0.9 mpc

if [ $rc != 0 ] || [ $rc2 != 0 ] || [ $rc3 != 0 ] || [ $rc4 != 0 ] || [ $rc5 != 0 ] ; then
    echo -e "\e[1;4;31mProblem while unzipping gcc (pass 2)\e[0m"
    exit 1
else
    echo -e "\e[1;34mgcc (pass 2) archives ok\e[0m"
fi

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
rc=$?
make install
rc2=$?

if [ $rc != 0 ] || [ $rc2 != 0 ] ; then
    echo -e "\e[1;4;31mProblem while installing gcc (pass 2)\e[0m"
    exit 1
else
    echo -e "\e[1;34mgcc (pass 2) well installed\e[0m"
fi

ln -vs gcc /tools/bin/cc
cd ..
rm -rf gcc-build
rm -rf gcc-4.6.2

#installation of TCL
tar -xf tcl8.5.11-src.tar.gz 
rc=$?
cd tcl8.5.11
cd unix
./configure --prefix=/tools
rc2=$?
make
rc3=$?
TZ=UTC make test
make install
rc4=$?
chmod -v u+w /tools/lib/libtcl8.5.so
make install-private-headers
rc5=$?

if [ $rc != 0 ] || [ $rc2 != 0 ] || [ $rc3 != 0 ] || [ $rc4 != 0 ] || [ $rc5 != 0 ] ; then
    echo -e "\e[1;4;31mProblem while installing TCL\e[0m"
    exit 1
else
    echo -e "\e[1;34mTCL well installed\e[0m"
fi

ln -sv tclsh8.5 /tools/bin/tclsh
cd ..

#installation of expect
tar -xf expect5.45.tar.gz
rc=$?
cd expect5.45
cp -v configure{,.orig}
sed 's:/usr/local/bin:/bin:' configure.orig > configure
./configure --prefix=/tools --with-tcl=/tools/lib \
--with-tclinclude=/tools/include
rc2=$?
make
rc3=$?
make test
make SCRIPTS="" install
rc4=$?

if [ $rc != 0 ] || [ $rc2 != 0 ] || [ $rc3 != 0 ] || [ $rc4 != 0 ] ; then
    echo -e "\e[1;4;31mProblem while installing expect\e[0m"
    exit 1
else
    echo -e "\e[1;34mexpect well installed\e[0m"
fi

cd ..

#installation of Deja GNU
tar -xf dejagnu-1.5.tar.gz
rc=$?
cd dejagnu-1.5
./configure --prefix=/tools
rc2=$?
make install
rc3=$?
make check
rc4=$?

if [ $rc != 0 ] || [ $rc2 != 0 ] || [ $rc3 != 0 ] || [ $rc4 != 0 ] ; then
    echo -e "\e[1;4;31mProblem while installing dejagnu\e[0m"
    exit 1
else
    echo -e "\e[1;34mdejagnu well installed\e[0m"
fi

cd ..

#check
tar -xf check-0.9.8.tar.gz
rc=$?
cd check-0.9.8
./configure --prefix=/tools
rc2=$?
make
rc3=$?
make check
make install
rc4=$?

if [ $rc != 0 ] || [ $rc2 != 0 ] || [ $rc3 != 0 ] || [ $rc4 != 0 ] ; then
    echo -e "\e[1;4;31mProblem while installing check\e[0m"
    exit 1
else
    echo -e "\e[1;34mcheck well installed\e[0m"
fi

cd ..
rm -rf tcl8.5.11
rm -rf expect5.45
rm -rf dejagnu-1.5
rm -rf check-0.9.8

#ncurses
tar -xf ncurses-5.9.tar.gz
rc=$?
cd ncurses-5.9
./configure --prefix=/tools --with-shared \
--without-debug --without-ada --enable-overwrite
rc2=$?
make
rc3=$?
make install
rc4=$?

if [ $rc != 0 ] || [ $rc2 != 0 ] || [ $rc3 != 0 ] || [ $rc4 != 0 ] ; then
    echo -e "\e[1;4;31mProblem while installing ncurses\e[0m"
    exit 1
else
    echo -e "\e[1;34mncurses well installed\e[0m"
fi

cd ..
rm -rf ncurses-5.9

#bash 4.2
tar -xf bash-4.2.tar.gz
rc=$?
cd bash-4.2
patch -Np1 -i ../bash-4.2-fixes-8.patch
rc2=$?
./configure --prefix=/tools --without-bash-malloc
rc3=$?
make
rc4=$?
make install
rc5=$?

if [ $rc != 0 ] || [ $rc2 != 0 ] || [ $rc3 != 0 ] || [ $rc4 != 0 ] || [ $rc5 != 0 ] ; then
    echo -e "\e[1;4;31mProblem while installing bash\e[0m"
    exit 1
else
    echo -e "\e[1;34mbash well installed\e[0m"
fi

ln -vs bash /tools/bin/sh
cd ..
rm -rf bash-4.2

#Bzip2
tar -xf bzip2-1.0.6.tar.gz
rc=$?
cd bzip2-1.0.6
make
rc2=$?
make PREFIX=/tools install
rc3=$?

if [ $rc != 0 ] || [ $rc2 != 0 ] || [ $rc3 != 0 ] ; then
    echo -e "\e[1;4;31mProblem while installing bzip\e[0m"
    exit 1
else
    echo -e "\e[1;34mbzip well installed\e[0m"
fi

cd ..
rm -rf bzip2-1.0.6


