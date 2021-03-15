#!/bin/bash

set -e

for project in adder
do
  rm -rf build-$project
  mkdir build-$project
  cd build-$project
  cmake ../projects/$project
  make
  make install_kernelspec
  cd ..
done
