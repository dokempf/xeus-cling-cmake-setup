# xeus-cling-cmake-setup

*DISCLAIMER:* This repository is still in an experimental state. It's core
functionality is implemented and e.g. used by [this project](https://github.com/dokempf/dune-jupyter-course/blob/master/dune/jupyter-kernel/CMakeLists.txt#L36) but things may still fail in more general
scenarios. You are welcome to give it a try and report your issues though.

[xeus-cling](https://github.com/jupyter-xeus/xeus-cling) provides an implemenation of a Jupyter Kernel
for C++ based on the Clang/LLVM C++ interpreter [cling](https://github.com/root-project/cling). Interpreting
C++ in jupyter has great potential e.g. in rapid prototyping and in teaching.

Working with external libaries in `xeus-cling` requires setting up the include and library paths
for the external dependencies with `#pragma` directives. Putting these directly into the notebook
is not ideal for several reasons:
* They make the notebook quite unreadable
* They scare beginners
* They contain build-specific paths, making a distribution of the notebook impossible

This project goes an alternative route of solving the problem to set up xeus-cling with external dependencies:
Assuming that you are using CMake to build your project anyway, it provides a CMake extension
that generates a xeus-cling kernel configuration into the build directory. This configuration can
be installed into your jupyter environment.

## Prerequisites

* A working installation of xeus-cling. The [currently preferred way is by using anaconda](https://github.com/jupyter-xeus/xeus-cling).
* Your project needs to build shared libraries (e.g. by setting `BUILD_SHARED_LIBS=ON` in CMake)
* Your project needs to be able to successfully build with Clang 5.

## How to use it in your code.

This project should be easy to integrate into your project, as its implementation is provided as one single file:
Copy `XeusClingSetup.cmake` into your project and include it into your
CMake build system by adding this line to your `CMakeLists.txt` (preferrably
to the top level one):

```
include(XeusClingSetup.cmake)
```

If your project makes use of git submodules, you can alternatively add this
repository as a submodule and do:

```
add_subdirectory(xeus-cling-cmake-setup)
```

After doing this, a function `xeus_cling_setup` is available in CMake. You can pass CMake targets,
include directories, libraries and compile flags to the function to make them available in the
generated jupyter kernel configuration:

```
xeus_cling_setup(
  TARGETS mylibrary
)
```

It is recommended to work with CMake targets only, but include directories and libraries can also
be specified manually (see below for the full signature of `xeus_cling_setup`).

A `kernel.json` file will be generated into your build directory. You can install
this kernel specification by building the CMake target `install_kernelspec` or you
can manually do so using the `jupyter kernelspec install` command. Note that in either
case, the Conda environment where `xeus-cling` is installed needs to be activated first.

## Documentation

The CMake function `xeus_cling_setup` allows for many more parameters than shown in above minimal example:

```
xeus_cling_setup(
  [TARGETS target1 [target2 ...]]
  [INCLUDE_DIRECTORIES inc1 [inc2 ...]]
  [LINK_LIBRARIES lib1 [lib2 ...]]
  [LIBRARY_DIRECTORIES dir1 [dir2 ...]]
  [COMPILE_OPTIONS flag1 [flag2 ...]]
  [COMPILE_DEFINITIONS def1 [def2 ...]]
  [SETUP_HEADERS header1 [header2 ...]]
  [DOXYGEN_TAGFILES tagfile1 [tagfile2 ...]]
  [DOXYGEN_URLS url1 [url2 ...]]
  [KERNEL_LOGO_FILES file1 [file2]]
  [KERNEL_NAME name]
  [CXX_STANDARD 11|14|17]
  [REQUIRED]
)
```

A detailed description of the parameters can be found at the top of the `XeusClingSetup.cmake` file.

## Limitations

* `cling` itself is limited to working with shared libraries. [They are looking for a volunteer to work on static libraries](https://github.com/root-project/cling/issues/280).
* We currently do not globally install the kernelspec during installation of the CMake project. In order to implement this, we would need to resolve `INSTALL_INTERFACE` generator expressions in the generation process of `kernel.json` and `xeus_cling.hh`. However, CMake has not yet implemented the necessary bits e.g. see [this issue on file(GENERATE)](https://gitlab.kitware.com/cmake/cmake/-/issues/17984) or [this issue on install(CODE)](https://gitlab.kitware.com/cmake/cmake/-/issues/15785).

## Licensing

`XeusClingSetup.cmake` is licensed under the MIT license. The license text and
copyright statement are provided within the file, so you can just copy it into
your project.
