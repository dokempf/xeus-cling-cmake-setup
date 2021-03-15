#!/bin/bash

rm -rf build-$1
mkdir build-$1
cd build-$1
cmake -DCMAKE_INSTALL_PREFIX=../inst ../projects/$1
make
if [ "$2" = "install" ]
then
  make install
  cd ..
  rm -rf build-$1
else
  make install_kernelspec
  cd ..
fi
