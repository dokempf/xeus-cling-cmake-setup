#!/bin/bash

for project in adder:
do
  rm -rf build-$project
  mkdir build-$project
  cd build-$project
  cmake -DCMAKE_INSTALL_PREFIX=../inst ../projects/$project
  make
  make install_kernelspec
  cd ..
done
