# A CMake extension to set up a xeus-cling kernel configuration that integrates
# any number of external libraries that are known to CMake.
#
# This module provides the following CMake function:
#
# xeus_cling_setup(
#   [TARGETS target1 [target2 ...]]
#   [INCLUDE_DIRECTORIES inc1 [inc2 ...]]
#   [LINK_LIBRARIES lib1 [lib2 ...]]
#   [KERNEL_NAME name]
#   [CXX_STANDARD 11|14|17]
#   [REQUIRED]
# )
#
# The function sets up a kernel.json file and an accompanying C++ header in the CMake
# build directory. This file can be installed into the jupyter environment with
# `jupyter kernelspec` - the exact command is written in kernel.json. During installation
# in CMake, the kernel spec is automatically installed.
#
# These are the arguments of `xeus_cling_setup`:
#
# TARGETS
#     A list of CMake targets that our kernel should link against. Specifying
#     a list of targets is preferred opposed to manuall specifying INCLUDE_DIRECTORIES
#     and LINK_LIBRARIES. Libraries need to be shared libraries in order to be
#     usable with xeus-cling.
#
# INCLUDE_DIRECTORIES
#     A list of include directories that should be added to the xeus-cling session.
#     May include generator expressions.
#
# LINK_LIBRARIES
#     A list of shared library locations that should be loaded in the xeus-cling session.
#     May include generator expressions
#
# KERNEL_NAME
#     The display name of the Jupyter Kernel that is to be generated. Defaults to
#     a readable combination of the C++ standard and the CMake project name of your project.
#
# CXX_STANDARD
#     Use this to explicitly set the used C++ standard. Defaults to 17.
#
# REQUIRED
#     Set this if you want to error out if xeus-cling was not found on the system.
#
# NO_INSTALL
#     Set this to prevent automatic installation of the kernelspec during installation
#     of the project.
#
# This file is licensed under the MIT License:
#
# Copyright 2021 Dominic Kempf, Heidelberg University
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the Software
# is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
# PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
# OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#

function(xeus_cling_setup)
  #
  # Parse Function Arguments and sanitize the input
  #

  # Parse Function Arguments
  set(OPTION REQUIRED NO_INSTALL)
  set(SINGLE CXX_STANDARD KERNEL_NAME)
  set(MULTI TARGETS INCLUDE_DIRECTORIES LINK_LIBRARIES)
  include(CMakeParseArguments)
  cmake_parse_arguments(XEUSCLING "${OPTION}" "${SINGLE}" "${MULTI}" ${ARGN})
  if(XEUSCLING_UNPARSED_ARGUMENTS)
    message(WARNING "Unparsed arguments in xeus_cling_setup: This often indicates typos!")
  endif()

  # We search for the xeus-cling interpreter binary. If you installed xeus-cling from conda,
  # make sure to activate the environment.
  # If you built xeus-cling from source, you can set CMAKE_PREFIX_PATH to
  # give CMake hints about where to find it.
  find_program(XCPP_BIN xcpp)

  # We also search for the jupyter executable to be able to install the kernel spec
  find_program(JUPYTER_BIN jupyter)

  # Apply the REQUIRED argument
  if(NOT XCPP_BIN)
    if(XEUSCLING_REQUIRED)
      message(FATAL_ERROR "xeus-cling set up was marked as required, but the interpreter was not found!")
    else()
      return()
    endif()
  endif()

  # Sanitize the C++ Standard input argument
  set(cxx_standard_list 98 11 14 17 20 23)
  set(cling_standard_list 11 14 17)
  if(NOT XEUSCLING_CXX_STANDARD)
    set(XEUSCLING_CXX_STANDARD 17)
  endif()
  list(FIND cxx_standard_list "${XEUSCLING_CXX_STANDARD}" cxx_std_index)
  if("${cxx_std_index}" STREQUAL "-1")
    message(FATAL_ERROR "xeus_cling_setup expected a C++ standard from {11, 14, 17}")
  endif()
  list(FIND cling_standard_list "${XEUSCLING_CXX_STANDARD}" cling_std_index)
  if("${cling_std_index}" STREQUAL "-1")
    message(FATAL_ERROR "xeus_cling_setup got passed a C++ standard that is not supported by Cling: C++${XEUSCLING_CXX_STANDARD}")
  endif()

  # Sanitize the kernel name Argument
  if(NOT XEUSCLING_KERNEL_NAME)
    set(XEUSCLING_KERNEL_NAME "C++${XEUSCLING_CXX_STANDARD} (${PROJECT_NAME})")
  endif()

  #
  # Collect the data for the generation stage from the given parameters
  #

  # Extract information from the given targets and append them to the other arguments
  foreach(target ${XEUSCLING_TARGETS})
    # Check existence of the target
    if(NOT TARGET ${target})
      message(FATAL_ERROR "xeus_cling_setup was passed a target ${target}, but it does not exist")
    endif()

    # All targets should be shared libraries
    get_target_property(type ${target} TYPE)
    if(NOT "${type}" STREQUAL "SHARED_LIBRARY")
      message(FATAL_ERROR "xeus_cling_setup assumed target ${target} to be a shared library")
    endif()

    # Check the target does not require a higher C++ standard
    get_target_property(target_cxx_standard ${target} CXX_STANDARD)
    if(target_cxx_standard)
      list(FIND cxx_standard_list "${target_cxx_standard}" target_std_index)
      if(target_std_index GREATER cxx_std_index)
        message(FATAL_ERROR "xeus_cling_setup was passed a target ${target} that requires C++${target_cxx_standard}, although the Cling setup works for C++${XEUSCLING_CXX_STANDARD}")
      endif()
    endif()

    # Append all include directories to the pragma header
    get_target_property(incs ${target} INCLUDE_DIRECTORIES)
    foreach(inc ${incs})
      set(XEUSCLING_INCLUDE_DIRECTORIES ${XEUSCLING_INCLUDE_DIRECTORIES} ${inc})
    endforeach()

    # Append the library file to the pragma header
    set(XEUSCLING_LINK_LIBRARIES ${XEUSCLING_LINK_LIBRARIES} "$<TARGET_FILE:${target}>")
  endforeach()

  #
  # Generate the kernel configuration
  #

  # Incrementally build the pragma header
  set(xeus_pragma_header "")

  # Append all include directories to the pragma header
  foreach(inc ${XEUSCLING_INCLUDE_DIRECTORIES})
    set(xeus_pragma_header "${xeus_pragma_header}$<$<BOOL:${inc}>:#pragma cling add_include_path(\"${inc}\")\n>")
  endforeach()

  # Append all library loading commands to the pragma header
  foreach(lib ${XEUSCLING_LINK_LIBRARIES})
    set(xeus_pragma_header "${xeus_pragma_header}#pragma cling load(\"${lib}\")\n")
  endforeach()

  # Generate the header file
  file(
    GENERATE
    OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/xeus_cling.hh"
    CONTENT ${xeus_pragma_header}
  )

  # Generate the kernel.json file
  file(
    GENERATE
    OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/kernel.json
    CONTENT
      "{
        \"display_name\": \"${XEUSCLING_KERNEL_NAME}\",
        \"argv\": [
          \"${XCPP_BIN}\",
          \"-f\",
          \"{connection_file}\",
          \"-std=c++${XEUSCLING_CXX_STANDARD}\",
          \"-include\",
          \"xeus_cling.hh\"
        ],
        \"language\": \"C++${XEUSCLING_CXX_STANDARD}\"
      }"
  )

  # Create a kernel name to identify the kernel in jupyter.
  string(
    UUID kernel_name
    NAMESPACE 00000000-0000-0000-0000-000000000000
    NAME "${XEUSCLING_KERNEL_NAME}"
    TYPE SHA1
  )

  # Add a target that triggers the installation of the kernel spec
  if(JUPYTER_BIN)
    add_custom_target(
      install_kernelspec
      COMMAND ${JUPYTER_BIN} kernelspec install ${CMAKE_CURRENT_BINARY_DIR} --sys-prefix --name=${kernel_name}
      COMMENT "Install kernelspec into the jupyter environment..."
    )
  else()
    add_custom_target(
      install_kernelspec
      COMMENT "The jupyter executable was not found by CMake, not install kernel spec"
    )
  endif()

  if(NOT XEUSCLING_NO_INSTALL)
    install(CODE "
      execute_process(
        COMMAND ${CMAKE_COMMAND} --build . --target install_kernelspec
      )
    ")
  endif()

endfunction()
