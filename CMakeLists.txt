cmake_minimum_required(VERSION 3.18)
project(cropsim LANGUAGES Fortran)

# The engine source is generated from the frozen original by
# tools/make_engine.py and checked in, so the build needs no Python step.
add_library(cropsim SHARED
  fortran/src/cropsim_engine.f90
  fortran/src/cropsim_api.f90
)
set_target_properties(cropsim PROPERTIES
  Fortran_MODULE_DIRECTORY ${CMAKE_BINARY_DIR}/modules
  POSITION_INDEPENDENT_CODE ON
)

if(CMAKE_Fortran_COMPILER_ID STREQUAL "GNU")
  # The original is fixed to these flags so results match old runs.
  target_compile_options(cropsim PRIVATE -O2 -ffree-line-length-none -std=legacy)
  # On Windows and macOS link the Fortran runtime in, so the library stands
  # alone (Homebrew's libgfortran.dylib targets only the newest macOS). On
  # Linux the wheel repair step (auditwheel) bundles libgfortran instead.
  if(WIN32)
    target_link_options(cropsim PRIVATE -static)
    set_target_properties(cropsim PROPERTIES PREFIX "lib")
  elseif(APPLE)
    target_link_options(cropsim PRIVATE
      -static-libgfortran -static-libquadmath -static-libgcc)
  endif()
elseif(CMAKE_Fortran_COMPILER_ID MATCHES "Intel")
  target_compile_options(cropsim PRIVATE -O2)
endif()

# Install the library inside the Python package directory.
install(TARGETS cropsim
  LIBRARY DESTINATION cropsim
  RUNTIME DESTINATION cropsim
  ARCHIVE DESTINATION cropsim/lib
)
