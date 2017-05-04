FUNCTION(BUILD_DT_ENV_MODULE FILE)
  MESSAGE("-+ Writing tmp env. module to ${FILE}")
  FILE(WRITE  ${FILE}  "#%Modules\n")
  FILE(APPEND ${FILE} "set root ${PREFIX}\n")
  FILE(APPEND ${FILE} "set plat ${FC_PLAT}\n")
  FILE(APPEND ${FILE} "set version \"${VERSION} (${FC_PLAT})\"\n")
  FILE(APPEND ${FILE} "set compiler ${CMAKE_Fortran_COMPILER}\n")
  FILE(READ   ${DT_ENV}/module CONTENTS)
  FILE(APPEND ${FILE} "${CONTENTS}")
ENDFUNCTION()



FUNCTION(BUILD_DT_CONFIGVARS FILE)
  FILE(READ   ${DT_BIN}/configvars.sh CONTENTS)
  FILE(WRITE  ${FILE} "${CONTENTS}")
  FILE(APPEND ${FILE} "add_library_to_system ${CMAKE_INSTALL_PREFIX}\n")
ENDFUNCTION()
