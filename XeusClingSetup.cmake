# A CMake extension to set up a xeus-cling kernel configuration that integrates
# any number of external libraries that are known to CMake.
#
# This module provides the following CMake function:
#
# xeus_cling_setup(
#   [TARGETS target1 [target2 ...]]
#   [INCLUDE_DIRECTORIES inc1 [inc2 ...]]
#   [LINK_LIBRARIES lib1 [lib2 ...]]
#   [LIBRARY_DIRECTORIES dir1 [dir2 ...]]
#   [COMPILE_FLAGS flag1 [flag2 ...]]
#   [COMPILE_DEFINITIONS def1 [def2 ...]]
#   [SETUP_HEADERS header1 [header2 ...]]
#   [DOXYGEN_TAGFILES tagfile1 [tagfile2 ...]]
#   [DOXYGEN_URLS url1 [url2 ...]]
#   [KERNEL_LOGO_FILES file1 [file2]]
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
# LIBRARY_DIRECTORIES
#     A list of directories to search for shared libraries.
#
# COMPILE_FLAGS
#     A list of compiler flags to add to the interpreter session.
#
# COMPILE_DEFINITIONS
#     A list of preprocessor defines to set for the interpreter session.
#
# SETUP_HEADERS
#     A list of C++ headers to include into the kernel setup process. Use this
#     to hook any C++ start-up code or default includes that you want to apply
#     into the kernel startup procedure. The file will be included with angle
#     brackets - it is recommended to pass an absolute path if available.
#
# DOXYGEN_URLS
#     A list of URLs that inline documentation should be embedded from. Only
#     https:// URLs are supported. Note that the web server configuration of
#     the given URL needs to allow embedding the pages it serves into iframes.
#
# DOXYGEN_TAGFILES
#     The Doxygen tagfiles that describe the documentation. These files can be
#     generated by Doxygen by specifying the GENERATE_TAGFILE configuration key.
#     More infos can be found in the Doxygen doc: https://www.doxygen.nl/manual/external.html
#     The list of file names given to this parameter must match the number of
#     URLs given to DOXYGEN_URLS. The tagfiles are expected to match to the given
#     URLs one by one. You have three options for providing tag file names:
#       * Provide an absolute path to the tag file
#       * Provide a relative path - which will be interpreted w.r.t. the current source directory
#       * Only provide a filename: The tagfile will be fetched from the given URL.
#         This is the preferred method if you control the server that serves the
#         Doxygen docs.
#
# KERNEL_LOGO_FILES
#     Image files for this kernel. These are e.g. used in JupyterLab in the kernel
#     selection menu. File names must be logo-32x32.png or logo-64x64.png and are
#     expected to be of the respective pixel size.
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
  set(MULTI TARGETS INCLUDE_DIRECTORIES LINK_LIBRARIES COMPILE_FLAGS LIBRARY_DIRECTORIES SETUP_HEADERS DOXYGEN_URLS DOXYGEN_TAGFILES COMPILE_DEFINITIONS KERNEL_LOGO_FILES)
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

  # Make sure that we got matching list length for DOXYGEN_URLS and DOXYGEN_TAGFILES
  list(LENGTH XEUSCLING_DOXYGEN_URLS len_urls)
  list(LENGTH XEUSCLING_DOXYGEN_TAGFILES len_tags)
  if(NOT len_urls EQUAL len_tags)
    message(FATAL_ERROR "xeus_cling_setup got passed different length lists for DOXYGEN_TAGFILES and DOXYGEN_URLS")
  endif()

  # Make sure that the given URLs use the https:// protocol
  foreach(url ${XEUSCLING_DOXYGEN_URLS})
    string(REGEX MATCH "https://.*" match "${url}")
    if(NOT "${match}" STREQUAL "${url}")
      message(FATAL_ERROR "xeus_cling_setup expects https:// URL for Doxygen documentation, got ${url}!")
    endif()
  endforeach()

  # Make sure that the given logos have the correct names
  set(allowed_logo_names logo-32x32.png logo-64x64.png)
  foreach(filename ${XEUSCLING_KERNEL_LOGO_FILES})
    get_filename_component(purename "${filename}" NAME)
    list(FIND allowed_logo_names "${purename}" index)
    if("${index}" STREQUAL "-1")
      message(FATAL_ERROR "xeus_cling_setup got passed illegal logo filename.")
    endif()
  endforeach()

  # Copy logo files into the build directory to have them be installed by `install_kernelspec`
  foreach(filename ${XEUSCLING_KERNEL_LOGO_FILES})
    if(NOT IS_ABSOLUTE "${filename}")
      set(filename "${CMAKE_CURRENT_SOURCE_DIR}/${filename}")
    endif()
    get_filename_component(purename "${filename}" NAME)
    configure_file("${filename}" "${CMAKE_CURRENT_BINARY_DIR}/${purename}" COPYONLY)
  endforeach()

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

    # Extract all include directories from the target
    set(XEUSCLING_INCLUDE_DIRECTORIES "${XEUSCLING_INCLUDE_DIRECTORIES};$<TARGET_PROPERTY:${target},INTERFACE_INCLUDE_DIRECTORIES>")

    # Extract all compile flags from the target
    set(XEUSCLING_COMPILE_FLAGS "${XEUSCLING_COMPILE_FLAGS};$<TARGET_PROPERTY:${target},INTERFACE_COMPILE_FLAGS>")

    # Extract all compile definitions from the target
    set(XEUSCLING_COMPILE_DEFINITIONS "${XEUSCLING_COMPILE_DEFINITIONS};$<TARGET_PROPERTY:${target},INTERFACE_COMPILE_DEFINITIONS>")

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
    set(xeus_pragma_header "${xeus_pragma_header}$<$<BOOL:${inc}>:#pragma cling add_include_path(\"$<JOIN:${inc},\")\n#pragma cling add_include_path(\">\")\n>")
  endforeach()

  # Append all library directories to the pragma header
  foreach(dir ${XEUSCLING_LIBRARY_DIRECTORIES})
    set(xeus_pragma_header "${xeus_pragma_header}#pragma cling add_library_path(\"${dir}\")\n")
  endforeach()

  # Append all library loading commands to the pragma header
  foreach(lib ${XEUSCLING_LINK_LIBRARIES})
    set(xeus_pragma_header "${xeus_pragma_header}#pragma cling load(\"${lib}\")\n")
  endforeach()

  # Append the user-provided start-up headers
  foreach(header ${XEUSCLING_SETUP_HEADERS})
    set(xeus_pragma_header "${xeus_pragma_header}#include<${header}>\n")
  endforeach()

  # Generate the header file
  file(
    GENERATE
    OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/xeus_cling.hh"
    CONTENT ${xeus_pragma_header}
  )

  # Create a string from the given compiler options
  set(cxxopts_string "")
  foreach(flag ${XEUSCLING_COMPILE_FLAGS})
    set(cxxopts_string "${cxxopts_string}$<$<BOOL:${flag}>:\"$<JOIN:${flag},\",\">\",>")
  endforeach()

  foreach(def ${XEUSCLING_COMPILE_DEFINITIONS})
    set(cxxopts_string "${cxxopts_string}$<$<BOOL:${def}>:\"-D$<JOIN:${def},\",-D\">\",>")
  endforeach()

  # Generate the kernel.json file
  file(
    GENERATE
    OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/kernel.json
    CONTENT
    "
      {
        \"display_name\": \"${XEUSCLING_KERNEL_NAME}\",
        \"argv\": [
          \"${XCPP_BIN}\",
          \"-f\",
          \"{connection_file}\",
          \"-std=c++${XEUSCLING_CXX_STANDARD}\",
          ${cxxopts_string}
          \"-include\",
          \"${CMAKE_CURRENT_BINARY_DIR}/xeus_cling.hh\"
        ],
        \"language\": \"C++${XEUSCLING_CXX_STANDARD}\"
      }
    "
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
      COMMENT "The jupyter executable was not found by CMake, not installing kernel spec"
    )
  endif()

  # Add installation logic for Doxygen data
  if(XEUSCLING_DOXYGEN_URLS)
    # Find the xeus-cling installation prefix
    find_package(xeus-cling REQUIRED)
    set(prefix "${xeus-cling_DIR}/../../..")

    # Collect a list of files to install
    set(json_files)
    set(tag_files)

    # Iterate over the given inputs
    math(EXPR bound "${len_urls} - 1")
    foreach(index RANGE ${bound})
      # Extract the current pair of URL and tagfile - a poor man's zip
      list(GET XEUSCLING_DOXYGEN_URLS ${index} url)
      list(GET XEUSCLING_DOXYGEN_TAGFILES ${index} tag)

      # Make sure that the URL ends with a trailing / - an undocumented requirement of xeus-cling
      string(REGEX MATCH ".*/" match "${url}")
      if(NOT "${match}" STREQUAL "${url}")
        set(url "${url}/")
      endif()

      # Locate the Doxygen tag files - we might need to download it
      if(IS_ABSOLUTE "${tag}")
        set(fulltag "${tag}")
      else()
        if(EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/${tag})
          set(fulltag "${CMAKE_CURRENT_SOURCE_DIR}/${tag}")
        else()
          set(fulltag "${CMAKE_CURRENT_BINARY_DIR}/${tag}")
          message("-- Attempting to fetch tag file from ${url}/${tag}")
          file(
            DOWNLOAD
            "${url}${tag}"
            "${fulltag}"
            STATUS status
          )
          list(GET status 0 statuscode)
          if(NOT "${statuscode}" STREQUAL "0")
            list(GET status 1 error)
            message(FATAL_ERROR "xeus_cling_setup reported error downloading tag file: ${error}")
          endif()
        endif()
      endif()

      file(
        GENERATE
        OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/${tag}.json"
        CONTENT
        "
          {
            \"url\": \"${url}\",
            \"tagfile\": \"${tag}\"
          }
        "
      )

      # Append our new files to the list of collected files
      set(json_files ${json_files} "${CMAKE_CURRENT_BINARY_DIR}/${tag}.json")
      set(tag_files ${tag_files} "${fulltag}")
    endforeach()

    add_custom_target(
      install_doxygen_configuration
      COMMAND ${CMAKE_COMMAND} -E copy ${json_files} "${prefix}/etc/xeus-cling/tags.d"
      COMMAND ${CMAKE_COMMAND} -E copy ${tag_files} "${prefix}/share/xeus-cling/tagfiles"
      COMMENT "Installing Doxygen information for Jupyter inline documentation..."
    )
    add_dependencies(install_kernelspec install_doxygen_configuration)
  endif()
endfunction()
