add_library(adder adder.cpp)
target_include_directories(adder PUBLIC
  $<BUILD_INTERFACE:${CMAKE_SOURCE_DIR}/include/>
  $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)

# Add an alias for use if this project is included as a subproject in another project
add_library(adder::adder ALIAS adder)

add_library(adder2 adder2.cpp)
target_include_directories(adder2 PUBLIC
  $<BUILD_INTERFACE:${CMAKE_SOURCE_DIR}/include/>
  $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)
target_link_libraries(adder2 PUBLIC adder)

# Add an alias for use if this project is included as a subproject in another project
add_library(adder::adder2 ALIAS adder2)
