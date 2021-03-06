cmake_minimum_required(VERSION 3.12)
project(libmacaroons
        VERSION 0.4
        LANGUAGES C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake" ${CMAKE_MODULE_PATH})

# Sanitizers
set(SANITIZE_ADDRESS ON)
set(SANITIZE_UNDEFINED ON)

find_package(Sanitizers)

option(JSON_SUPPORT "Enable support for JSON Macaroons" ON)

add_library(macaroons
        base64.c
        explicit_bzero.c
        macaroons.c
        packet.c
        port.c
        sha256.c
        shim.c
        slice.c
        timingsafe_bcmp.c
        tweetnacl.c
        v1.c
        v2.c
        varint.c
        utf8check.h)

target_include_directories(macaroons
        INTERFACE
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/..>
        $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>)

if (JSON_SUPPORT)
    message(STATUS "Enabling JSON support")
    add_compile_definitions(MACAROONS_JSON)
endif ()

if (APPLE)
    target_compile_definitions(macaroons PRIVATE HAVE_OSX_LIBUTIL_H)
endif ()

# Test
add_executable(serialize_test macaroon-test-serialization.c)
target_link_libraries(serialize_test macaroons)
add_sanitizers(serialize_test)

add_executable(verifier_test macaroon-test-verifier.c)
target_link_libraries(verifier_test macaroons)

# Fuzzers
add_executable(fuzz_serializer fuzzer-driver_afl.c fuzzer-serializer.c)
target_link_libraries(fuzz_serializer macaroons)
add_sanitizers(fuzz_serializer)

# Installation
include(GnuInstallDirs)
set(INSTALL_CONFIGDIR ${CMAKE_INSTALL_LIBDIR}/cmake/macaroons)
install(TARGETS macaroons
        EXPORT macaroonsTarget
        LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
        ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR})
# Install the single header
install(FILES macaroons.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})

include(CMakePackageConfigHelpers)
write_basic_package_version_file(
        ${CMAKE_CURRENT_BINARY_DIR}/cmake/macaroons-version.cmake
        VERSION ${PROJECT_VERSION}
        COMPATIBILITY AnyNewerVersion)

install(FILES
        ${CMAKE_CURRENT_BINARY_DIR}/cmake/macaroons-version.cmake
        DESTINATION ${INSTALL_CONFIGDIR})

install(EXPORT macaroonsTarget DESTINATION ${INSTALL_CONFIGDIR} FILE macaroons-config.cmake)
