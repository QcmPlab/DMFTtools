SET(CMAKE_SOURCE_DIR ${CMAKE_ARGV3})
SET(CMAKE_INSTALL_PREFIX ${CMAKE_ARGV4})
SET(PROJECT_NAME ${CMAKE_ARGV5})

SET(CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake/Modules")
SET(DT_TARGET_LIB ${CMAKE_INSTALL_PREFIX}/lib)
SET(DT_TARGET_INC ${CMAKE_INSTALL_PREFIX}/include)
SET(DT_TARGET_ETC ${CMAKE_INSTALL_PREFIX}/etc)
SET(DT_TARGET_BIN ${CMAKE_INSTALL_PREFIX}/bin)
SET(PKCONFIG_FILE ${DT_TARGET_ETC}/${PROJECT_NAME}.pc)


INCLUDE(${CMAKE_MODULE_PATH}/ColorsMsg.cmake)

FILE(INSTALL ${DT_TARGET_ETC}/modules/ DESTINATION $ENV{HOME}/.modules.d
  USE_SOURCE_PERMISSIONS)

FILE(INSTALL ${PKCONFIG_FILE} DESTINATION $ENV{HOME}/.pkgconfig.d
  USE_SOURCE_PERMISSIONS)


MESSAGE( STATUS "After installation usage options:")
MESSAGE( STATUS
  "Pick one choice (put it in your bash profile file to make it permanent):
${Yellow}A. source the file: ${DT_TARGET_BIN}/configvars.sh, i.e. ${ColourReset}
$ source ${DT_TARGET_BIN}/configvars.sh

${Yellow}B. use the provided ${PROJECT_NAME} environment module in ${DT_TARGET_ETC}, i.e.${ColourReset}
$ module use $HOME/.modules.d
$ module load ${PROJECT_NAME}/${FC_PLAT}

${Yellow}C. use pkg-config with the provided ${PROJECT_NAME}.pc in ${DT_TARGET_ETC}, i.e. ${ColourReset}
$ export PKG_CONFIG_PATH=${DT_TARGET_ETC}/:$PKG_CONFIG_PATH
$ pkg-config --cflags --libs ${PROJECT_NAME} (to get lib info)
")
