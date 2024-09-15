if(WIN32)
# ------------------------------------------------------------------------------
# CMake for lua-ffi
# ------------------------------------------------------------------------------
# Setup with Visual Studio 17 2022 generator for x64
# ------------------------------------------------------------------------------
# Visual Studio is a mutlti-configuration generator
# https://stackoverflow.com/questions/24460486/
#
# Basic instructions for out-of-source build
# ------------------------------------------
# mkdir build64 && cd build64
# cmake .. -G "Visual Studio 17 2022" -A x64 -DLUA_HINTS=C:/Temp/ONELUAPRO_BOOTSTRAP -DCMAKE_INSTALL_PREFIX=C:\Apps\OneLuaPro-5.4.7.2-x64 -DCMAKE_PREFIX_PATH=C:/Temp/ONELUAPRO_BOOTSTRAP
# cmake --build . --config Release
# cmake --install . --config Release
#
# Available architectures (-A ...) are: Win32, x64, ARM, ARM64

# ------------------------------------------------------------------------------
# General definitions
cmake_minimum_required(VERSION 3.23 FATAL_ERROR)

# ------------------------------------------------------------------------------
# find liblua installation and version info
if(NOT LUA_HINTS)
  if(WIN32)
    set(LUA_HINTS "c:/Apps")
  endif()
endif()
find_package(liblua REQUIRED CONFIG HINTS ${LUA_HINTS})
if(liblua_FOUND)
  message(STATUS "liblua version        : ${liblua_VERSION}")
  message(STATUS "liblua install prefix : ${LIBLUA_INSTALLDIR}")
  message(STATUS "liblua include dir    : ${LIBLUA_INCLUDEDIR}")
  message(STATUS "liblua lib dir        : ${LIBLUA_LIBDIR}")
else()
  message(FATAL_ERROR "Unable to find liblua version ${liblua_VERSION}.")
endif()
# Note: liblua_VERSION is set by find_package() directly. LIBLUA_INSTALLDIR,
# LIBLUA_INCLUDEDIR and LIBLUA_LIBDIR are set by libluaConfigVersion.cmake in
# <prefix>/share/cmake/liblua.

# ------------------------------------------------------------------------------
# Installation prefix directory - automatically set from find_package()
# Needs to be defined before project definition statement - for whatever reason
if(NOT CMAKE_INSTALL_PREFIX)
  set(CMAKE_INSTALL_PREFIX ${LIBLUA_INSTALLDIR})
endif()

# ------------------------------------------------------------------------------
# Project defintion
project(lua-ffi LANGUAGES C)

# ------------------------------------------------------------------------------
# Other settings
set(CMAKE_VERBOSE_MAKEFILE ON)
# Version settings
set(LUA_FFI_VERSION_MAJOR 1)
set(LUA_FFI_VERSION_MINOR 0)
set(LUA_FFI_VERSION_PATCH 0)

# ------------------------------------------------------------------------------
# Setup GNU-alike installatin directories
include (GNUInstallDirs)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/${CMAKE_INSTALL_LIBDIR})
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/${CMAKE_INSTALL_LIBDIR})
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/${CMAKE_INSTALL_BINDIR})
set(INSTALL_LIBDIR
  ${CMAKE_INSTALL_LIBDIR} CACHE PATH "Installation directory for libraries")
set(INSTALL_BINDIR
  ${CMAKE_INSTALL_BINDIR} CACHE PATH "Installation directory for executables")
set(INSTALL_INCLUDEDIR
  ${CMAKE_INSTALL_INCLUDEDIR} CACHE PATH "Installation directory for header files")
set(INSTALL_DOCDIR
  ${CMAKE_INSTALL_DOCDIR} CACHE PATH "Installation directory for documentation")
set(INSTALL_MANDIR
  ${CMAKE_INSTALL_MANDIR} CACHE PATH "Installation directory for manpages")
set(INSTALL_DATAROOTDIR
  ${CMAKE_INSTALL_DATAROOTDIR} CACHE PATH "Installation directory for data")
# Lua-specific installation dirs
set(INSTALL_TOP_CDIR
  ${INSTALL_LIBDIR}/lua/${liblua_VERSION_MAJOR}.${liblua_VERSION_MINOR})
set(INSTALL_TOP_LDIR
  ${INSTALL_DATAROOTDIR}/lua/${liblua_VERSION_MAJOR}.${liblua_VERSION_MINOR})

# ------------------------------------------------------------------------------
# Report to user
message(STATUS "Build type: ${CMAKE_BUILD_TYPE}")
message(STATUS "C compiler flags: ${CMAKE_C_FLAGS} ${CMAKE_C_FLAGS_${CMAKE_BUILD_TYPE_UC}}")

# ------------------------------------------------------------------------------
# lua-ffi DLL
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/config.h.in ${CMAKE_CURRENT_BINARY_DIR}/config.h)
find_package(dlfcn-win32 REQUIRED)

# requires ailability of winflexbison, as cmake's flex_target() does not exist
# in MSVC build tools
set(FLEX_FILES
  "${CMAKE_CURRENT_BINARY_DIR}/lex.h"
  "${CMAKE_CURRENT_BINARY_DIR}/lex.c"
)
add_custom_command(OUTPUT ${FLEX_FILES}
  COMMAND ${LUA_HINTS}/bin/win_flex.exe --wincompat -o ${CMAKE_CURRENT_BINARY_DIR}/lex.c
  --header-file=${CMAKE_CURRENT_BINARY_DIR}/lex.h ${CMAKE_CURRENT_SOURCE_DIR}/lex.l
  COMMAND ${CMAKE_COMMAND} -E touch ${FLEX_FILES}
  DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/lex.l"
  COMMENT "Generating lex.c and lex.h"
)
add_custom_target(do_flex DEPENDS ${FLEX_FILES})

add_library(lua-ffi MODULE)
add_dependencies(lua-ffi do_flex)

# setup lua include directory
target_include_directories(lua-ffi PRIVATE ${LIBLUA_INCLUDEDIR}
  ${CMAKE_CURRENT_SOURCE_DIR} ${CMAKE_CURRENT_BINARY_DIR})

# requires static build of libffi
target_compile_options(lua-ffi PRIVATE /D_WINDLL /D_WIN32 /D_CRT_SECURE_NO_WARNINGS /DFFI_STATIC_BUILD)
target_link_options(lua-ffi PRIVATE
  /LIBPATH:${LIBLUA_LIBDIR} liblua.lib
  /LIBPATH:${LIBLUA_LIBDIR} libffi.lib
  ws2_32.lib
)
target_link_libraries(lua-ffi dlfcn-win32::dl)
set_target_properties(lua-ffi PROPERTIES OUTPUT_NAME ffi PREFIX "")

# plattform-independend sources
target_sources(lua-ffi PRIVATE helper.h token.h ffi.c ${CMAKE_CURRENT_BINARY_DIR}/lex.c
  ${CMAKE_CURRENT_BINARY_DIR}/lex.h)

# Install
install(TARGETS lua-ffi
  RUNTIME DESTINATION ${INSTALL_TOP_CDIR}
  LIBRARY DESTINATION ${INSTALL_TOP_CDIR}
)

# Docs and Tests
install(
  FILES README.md tests/basetype.lua tests/wintest.lua
  DESTINATION ${INSTALL_DOCDIR}
  COMPONENT doc
)
# ------------------------------------------------------------------------------
# Keep original CMakeLists.txt untouched
else()
cmake_minimum_required(VERSION 3.5)

project(lua-ffi C)

include(FindPkgConfig)

# Version settings
set(LUA_FFI_VERSION_MAJOR 1)
set(LUA_FFI_VERSION_MINOR 0)
set(LUA_FFI_VERSION_PATCH 0)

# Define options for selecting Lua versions
option(USE_LUA51 "Force select Lua5.1")
option(USE_LUA52 "Force select Lua5.2")
option(USE_LUA53 "Force select Lua5.3")
option(USE_LUA54 "Force select Lua5.4")

# Helper function to find and include Lua
function(find_and_include_lua version)
    pkg_search_module(LUA lua-${version})
    if (LUA_FOUND)
        include_directories(${LUA_INCLUDE_DIRS})
    else()
        message(FATAL_ERROR "Liblua${version} is required.")
    endif()
endfunction()

if (LUA_INCLUDE_DIR)
    include_directories(${LUA_INCLUDE_DIR})
else()
    # Check which Lua version to use
    if(USE_LUA51)
        find_and_include_lua(5.1)
        set(LUA_VERSION_MAJOR 5)
        set(LUA_VERSION_MINOR 1)
    elseif(USE_LUA52)
        find_and_include_lua(5.2)
        set(LUA_VERSION_MAJOR 5)
        set(LUA_VERSION_MINOR 2)
    elseif(USE_LUA53)
        find_and_include_lua(5.3)
        set(LUA_VERSION_MAJOR 5)
        set(LUA_VERSION_MINOR 3)
    elseif(USE_LUA54)
        find_and_include_lua(5.4)
        set(LUA_VERSION_MAJOR 5)
        set(LUA_VERSION_MINOR 4)
    else()
        find_package(Lua REQUIRED)
        include_directories(${LUA_INCLUDE_DIR})
    endif()
endif()

find_package(FLEX REQUIRED)

pkg_search_module(LIBFFI libffi)
if (NOT LIBFFI_FOUND)
    message(FATAL_ERROR "libffi is required.")
endif()

add_compile_options(-D_GNU_SOURCE -DLUA_USE_LINUX -Os -Wall -Werror --std=gnu99 -fno-strict-aliasing)

# configure a header file to pass some of the CMake settings to the source code
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/config.h.in ${CMAKE_CURRENT_BINARY_DIR}/config.h)

include_directories(${LIBFFI_INCLUDE_DIRS} ${CMAKE_CURRENT_SOURCE_DIR} ${CMAKE_CURRENT_BINARY_DIR})

if (NOT LUA_INSTALL_PREFIX)
    if (LUA_VERSION_MAJOR AND LUA_VERSION_MINOR)
        set(LUA_INSTALL_PREFIX lib/lua/${LUA_VERSION_MAJOR}.${LUA_VERSION_MINOR})
    else()
        set(LUA_INSTALL_PREFIX lib/lua)
    endif()
endif()

flex_target(cparser lex.l ${CMAKE_CURRENT_BINARY_DIR}/lex.c
    DEFINES_FILE ${CMAKE_CURRENT_BINARY_DIR}/lex.h)

add_library(lffi MODULE ffi.c ${CMAKE_CURRENT_BINARY_DIR}/lex.c)
target_link_libraries(lffi PRIVATE ${LIBFFI_LIBRARIES})
set_target_properties(lffi PROPERTIES OUTPUT_NAME ffi PREFIX "")

install(
    TARGETS lffi
    DESTINATION ${LUA_INSTALL_PREFIX}
)
endif()
