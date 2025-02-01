# Copyright (C) 2025 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

include(FetchContent)

set(ICU_VERSION "70")
set(ICU_TARGET_NAME "icu_external")
set(ICU_URL https://github.com/unicode-org/icu/releases/download/release-70-1/icu4c-70_1-src.tgz)
set(ICU_URL_HASH SHA256=8d205428c17bf13bb535300669ed28b338a157b1c01ae66d31d0d3e2d47c3fd5)

set(THIRD_PARTY_PATH ${CMAKE_BINARY_DIR}/_deps/icu)
set(ICU_SOURCE_DIR  ${THIRD_PARTY_PATH}/icu-src)
set(ICU_INSTALL_DIR ${THIRD_PARTY_PATH}/icu-install)

if(NOT WIN32)
  set(ICU_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fPIC -Wno-deprecated-declarations")
  set(ICU_C_FLAGS "${CMAKE_C_FLAGS} -fPIC -Wno-deprecated-declarations")
endif()

# openvino::runtime exports _GLIBCXX_USE_CXX11_ABI=0 on CentOS7.
# It needs to be propagated to every library openvino_tokenizers links with.
# That prohibits linkage with prebuilt libraries because they aren't compiled with _GLIBCXX_USE_CXX11_ABI=0.
get_directory_property(OPENVINO_RUNTIME_COMPILE_DEFINITIONS COMPILE_DEFINITIONS)

if(OPENVINO_RUNTIME_COMPILE_DEFINITIONS)
  foreach(def IN LISTS OPENVINO_RUNTIME_COMPILE_DEFINITIONS)
    set(ICU_CXX_FLAGS "${ICU_CXX_FLAGS} -D${def}")
    set(ICU_C_FLAGS "${ICU_C_FLAGS} -D${def}")
  endforeach()
endif()

set(HOST_ENV_CMAKE ${CMAKE_COMMAND} -E env
      # CC=${CMAKE_C_COMPILER}
      # CXX=${CMAKE_CXX_COMPILER}
      CFLAGS=${ICU_C_FLAGS}
      CXXFLAGS=${ICU_CXX_FLAGS}
      LDFLAGS=${CMAKE_MODULE_LINKER_FLAGS}
)

# ICU supports only Release and Debug build types 
if(GENERATOR_IS_MULTI_CONFIG_VAR)
  set(ICU_CONFIGURE_FLAGS $<$<CONFIG:Debug>:"--enable-debug">$<$<NOT:$<CONFIG:Release>>:"--enable-release">)
  set(ICU_BUILD_TYPE $<$<CONFIG:Debug>:Debug>$<$<NOT:$<CONFIG:Debug>>:Release>)
else()
  if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    set(ICU_CONFIGURE_FLAGS "--enable-debug")
    set(ICU_BUILD_TYPE ${CMAKE_BUILD_TYPE})
  else()
    set(ICU_CONFIGURE_FLAGS "--enable-release")
    set(ICU_BUILD_TYPE "Release") 
  endif()
endif()

set(ICU_SHARED_PREFIX ${CMAKE_SHARED_LIBRARY_PREFIX})
set(ICU_STATIC_PREFIX ${CMAKE_STATIC_LIBRARY_PREFIX})
set(ICU_SHARED_SUFFIX ${CMAKE_SHARED_LIBRARY_SUFFIX})
set(ICU_STATIC_SUFFIX ${CMAKE_STATIC_LIBRARY_SUFFIX})

if(WIN32)
    set(ICU_INSTALL_LIB_SUBDIR "lib64")
    set(ICU_INSTALL_BIN_SUBDIR "bin64")
    set(ICU_UC_LIB_NAME "icuuc")
    set(ICU_I18N_LIB_NAME "icuin")
    set(ICU_DATA_LIB_NAME "icudt")
    set(ICU_UC_SHARED_LIB_NAME "${ICU_UC_LIB_NAME}${ICU_VERSION}")
    set(ICU_I18N_SHARED_LIB_NAME "${ICU_I18N_LIB_NAME}${ICU_VERSION}")
    set(ICU_DATA_SHARED_LIB_NAME "${ICU_DATA_LIB_NAME}${ICU_VERSION}")
else()
    set(ICU_INSTALL_LIB_SUBDIR "lib")
    set(ICU_INSTALL_BIN_SUBDIR "lib")
    set(ICU_UC_LIB_NAME "icuuc")
    set(ICU_I18N_LIB_NAME "icui18n")
    set(ICU_DATA_LIB_NAME "icudata")
    set(ICU_UC_SHARED_LIB_NAME ${ICU_UC_LIB_NAME})
    set(ICU_I18N_SHARED_LIB_NAME ${ICU_I18N_LIB_NAME})
    set(ICU_DATA_SHARED_LIB_NAME ${ICU_DATA_LIB_NAME})
    
    # Calculate the number of cores using CMake
    execute_process(COMMAND nproc
      OUTPUT_VARIABLE ICU_JOB_POOL_SIZE
      OUTPUT_STRIP_TRAILING_WHITESPACE)
endif()

set(ICU_INCLUDE_DIRS "${ICU_INSTALL_DIR}/include")

foreach(build_type IN ITEMS Release Debug)
  string(TOUPPER ${build_type} BUILD_TYPE)
  foreach(icu_target IN ITEMS UC I18N DATA)
    if(icu_target STREQUAL "DATA")
      set(lib_postfix ${CMAKE_RELEASE_POSTFIX})
    else()
      set(lib_postfix ${CMAKE_${BUILD_TYPE}_POSTFIX})
    endif()
    set(ICU_STATIC_LIB_DIR "${ICU_INSTALL_DIR}/${build_type}/${ICU_INSTALL_LIB_SUBDIR}")
    set(ICU_SHARED_LIB_DIR "${ICU_INSTALL_DIR}/${build_type}/${ICU_INSTALL_BIN_SUBDIR}")
    set(ICU_${icu_target}_LIB_${BUILD_TYPE} "${ICU_STATIC_LIB_DIR}/${ICU_STATIC_PREFIX}${ICU_${icu_target}_LIB_NAME}${lib_postfix}${ICU_STATIC_SUFFIX}")
    set(ICU_${icu_target}_SHARED_LIB_${BUILD_TYPE} "${ICU_SHARED_LIB_DIR}/${ICU_SHARED_PREFIX}${ICU_${icu_target}_SHARED_LIB_NAME}${lib_postfix}${ICU_SHARED_SUFFIX}")
    list(APPEND ICU_LIBRARIES_${BUILD_TYPE} ${ICU_${icu_target}_LIB_${BUILD_TYPE}})
    list(APPEND ICU_SHARED_LIBRARIES_${BUILD_TYPE} ${ICU_${icu_target}_LIB_${BUILD_TYPE}})
  endforeach()
endforeach()

include(ExternalProject)

if(WIN32)
  ExternalProject_Add(
    ${ICU_TARGET_NAME}
    URL ${ICU_URL}
    URL_HASH ${ICU_URL_HASH}
    PREFIX ${THIRD_PARTY_PATH}
    SOURCE_DIR ${ICU_SOURCE_DIR}
    INSTALL_DIR ${ICU_INSTALL_DIR}
    CONFIGURE_COMMAND msbuild ${ICU_SOURCE_DIR}\\source\\allinone\\allinone.sln /p:Configuration=${ICU_BUILD_TYPE} /p:Platform=x64 /t:i18n /t:uconv /t:makedata 
    BUILD_COMMAND ""
    INSTALL_COMMAND ${CMAKE_COMMAND} -E copy_directory ${ICU_SOURCE_DIR}/include ${ICU_INCLUDE_DIRS} && 
                    ${CMAKE_COMMAND} -E copy_directory ${ICU_SOURCE_DIR}/lib64 ${ICU_INSTALL_DIR}/${ICU_BUILD_TYPE}/${ICU_INSTALL_LIB_SUBDIR} &&
                    ${CMAKE_COMMAND} -E copy_directory ${ICU_SOURCE_DIR}/bin64 ${ICU_INSTALL_DIR}/${ICU_BUILD_TYPE}/${ICU_INSTALL_BIN_SUBDIR}
    BUILD_BYPRODUCTS ${ICU_LIBRARIES_RELEASE} ${ICU_LIBRARIES_DEBUG}
  )
elseif(APPLE)
  ExternalProject_Add(
    ${ICU_TARGET_NAME}
    URL ${ICU_URL}
    URL_HASH ${ICU_URL_HASH}
    PREFIX ${THIRD_PARTY_PATH}
    SOURCE_DIR ${ICU_SOURCE_DIR}
    INSTALL_DIR ${ICU_INSTALL_DIR}
    CONFIGURE_COMMAND ${HOST_ENV_CMAKE} ${ICU_SOURCE_DIR}/source/runConfigureICU MacOSX --prefix ${ICU_INSTALL_DIR}/${ICU_BUILD_TYPE} --includedir ${ICU_INCLUDE_DIRS}
                      ${ICU_CONFIGURE_FLAGS} 
                      --enable-static
                      --enable-rpath
                      --disable-shared
                      --disable-tests
                      --disable-samples
                      --disable-extras
                      --disable-icuio
                      --disable-draft
                      --disable-icu-config
    BUILD_COMMAND make -j${ICU_JOB_POOL_SIZE} VERBOSE=1
    INSTALL_COMMAND make install
    BUILD_BYPRODUCTS ${ICU_LIBRARIES_RELEASE} ${ICU_LIBRARIES_DEBUG}
  )
else()
  ExternalProject_Add(
    ${ICU_TARGET_NAME}
    URL ${ICU_URL}
    URL_HASH ${ICU_URL_HASH}
    PREFIX ${THIRD_PARTY_PATH}
    SOURCE_DIR ${ICU_SOURCE_DIR}
    INSTALL_DIR ${ICU_INSTALL_DIR}
    CONFIGURE_COMMAND ${HOST_ENV_CMAKE} ${ICU_SOURCE_DIR}/source/runConfigureICU Linux --prefix ${ICU_INSTALL_DIR}/${ICU_BUILD_TYPE} --includedir ${ICU_INCLUDE_DIRS}
                      ${ICU_CONFIGURE_FLAGS}
                      --enable-static
                      --enable-rpath
                      --disable-shared
                      --disable-tests
                      --disable-samples
                      --disable-extras
                      --disable-icuio
                      --disable-draft
                      --disable-icu-config
    BUILD_COMMAND make -j${ICU_JOB_POOL_SIZE}
    INSTALL_COMMAND make install
    BUILD_BYPRODUCTS ${ICU_LIBRARIES_RELEASE} ${ICU_LIBRARIES_DEBUG}
  )
endif()

# using custom FindICU module
list(PREPEND CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake/modules")
