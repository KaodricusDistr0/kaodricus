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


