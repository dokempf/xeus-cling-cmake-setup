cmake_minimum_required(VERSION 3.9)

# Set a name and a version number for your project:
project(adder VERSION 0.0.1 LANGUAGES CXX)

# Initialize some default paths
include(GNUInstallDirs)

# Define the minimum C++ standard that is required
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Make sure to build shared libraries
set(BUILD_SHARED_LIBS ON)

# compile the library
add_subdirectory(src)

# Install targets and configuration
install(
  TARGETS adder
  EXPORT adder-config
  RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
  LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
  ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
)

install(
  EXPORT adder-config
  NAMESPACE adder::
  DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/adder
)

install(
  DIRECTORY ${CMAKE_CURRENT_LIST_DIR}/include/
  DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
)

# Add the actual CMake code that we are testing here
include(../../../XeusClingSetup.cmake)
xeus_cling_setup(TARGETS adder2)

# This prints a summary of found dependencies
include(FeatureSummary)
feature_summary(WHAT ALL)
