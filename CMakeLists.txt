cmake_minimum_required(VERSION 3.21)
project(RustDeskQuickHost LANGUAGES CXX RC)

if(NOT MSVC OR NOT WIN32)
    message(FATAL_ERROR "QuickHost requires MSVC and the Windows resource compiler.")
endif()
if(NOT CMAKE_SIZEOF_VOID_P EQUAL 4)
    message(FATAL_ERROR "QuickHost requires an x86 build. Configure with -A Win32.")
endif()
if(NOT CMAKE_VS_PLATFORM_TOOLSET STREQUAL "v141_xp")
    message(FATAL_ERROR "The XP build requires -T v141_xp,version=14.16.")
endif()
if(NOT MSVC_VERSION EQUAL 1916)
    message(FATAL_ERROR "The XP build requires MSVC 19.16 (toolset 14.16).")
endif()

set(CMAKE_CONFIGURATION_TYPES "Release" CACHE STRING "Supported configurations" FORCE)
set(CMAKE_MSVC_RUNTIME_LIBRARY MultiThreaded)
set(QUICKHOST_DEPS_ROOT "" CACHE PATH "Prefix containing x86 /MT dependency include/ and lib/ directories")
if(NOT IS_DIRECTORY "${QUICKHOST_DEPS_ROOT}/include" OR
   NOT IS_DIRECTORY "${QUICKHOST_DEPS_ROOT}/lib")
    message(FATAL_ERROR "Set QUICKHOST_DEPS_ROOT to a prefix containing include/ and lib/ (see docs/build-windows.md).")
endif()

function(quickhost_dependency dependency header)
    find_path(${dependency}_INCLUDE_DIR NAMES "${header}"
        PATHS "${QUICKHOST_DEPS_ROOT}/include" NO_DEFAULT_PATH REQUIRED)
    find_library(${dependency}_LIBRARY NAMES ${ARGN}
        PATHS "${QUICKHOST_DEPS_ROOT}/lib" NO_DEFAULT_PATH REQUIRED)
    add_library(${dependency} STATIC IMPORTED)
    set_target_properties(${dependency} PROPERTIES
        IMPORTED_LOCATION "${${dependency}_LIBRARY}"
        INTERFACE_INCLUDE_DIRECTORIES "${${dependency}_INCLUDE_DIR}")
endfunction()

quickhost_dependency(sodium sodium.h libsodium sodium)
quickhost_dependency(vpx vpx/vp8cx.h vpx libvpx)
quickhost_dependency(yuv libyuv/convert.h yuv libyuv)
quickhost_dependency(zstd zstd.h zstd_static libzstd_static zstd libzstd)

foreach(asset rustdesk_app.ico rustdesk_tray.ico qslogo.png material_more_vert.png material_refresh.png)
    if(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/resources/${asset}")
        message(FATAL_ERROR "Missing resource: resources/${asset}")
    endif()
endforeach()

add_executable(RustDeskQS WIN32
    src/main.cpp
    src/portable_host.cpp
    src/xp_fls_compat.cpp
    src/portable_host.rc)
target_compile_features(RustDeskQS PRIVATE cxx_std_17)
target_include_directories(RustDeskQS PRIVATE src)
target_compile_definitions(RustDeskQS PRIVATE
    UNICODE _UNICODE NOMINMAX WIN32_LEAN_AND_MEAN
    WINVER=0x0501 _WIN32_WINNT=0x0501 SODIUM_STATIC)
target_compile_options(RustDeskQS PRIVATE "$<$<COMPILE_LANGUAGE:CXX>:/utf-8>" "$<$<COMPILE_LANGUAGE:CXX>:/W3>")
target_link_options(RustDeskQS PRIVATE /SUBSYSTEM:WINDOWS,5.01)
target_link_libraries(RustDeskQS PRIVATE
    sodium vpx yuv zstd
    advapi32 comctl32 comdlg32 crypt32 gdi32 gdiplus iphlpapi
    mfuuid ole32 oleaut32 shell32 user32 ws2_32)
set_target_properties(RustDeskQS PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")