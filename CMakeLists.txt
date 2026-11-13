cmake_minimum_required(VERSION 3.18)
project(cropsim LANGUAGES Fortran)

# The engine source is generated from the frozen original by
# tools/make_engine.py and checked in, so the build needs no Python step.
set(CROPSIM_REFERENCE_SOURCES
  fortran/src/cropsim_engine.f90
  fortran/src/cropsim_api.f90
)
# The compute kernel: modern modules, no global state, thread-safe.
set(CROPSIM_KERNEL_SOURCES
  fortran/kernel/csk_types.f90
  fortran/kernel/csk_physics.f90
  fortran/kernel/csk_balance.f90
  fortran/kernel/csk_kernel.f90
  fortran/kernel/csk_capi.f90
)
add_library(cropsim SHARED ${CROPSIM_REFERENCE_SOURCES} ${CROPSIM_KERNEL_SOURCES})
set_target_properties(cropsim PROPERTIES
  Fortran_MODULE_DIRECTORY ${CMAKE_BINARY_DIR}/modules
  POSITION_INDEPENDENT_CODE ON
)

if(CMAKE_Fortran_COMPILER_ID STREQUAL "GNU")
  # The original is fixed to these flags so results match old runs.
  # Both the reference engine and the kernel use -O2 with no fast-math
  # and no FMA contraction, so they round identically.
  set_source_files_properties(${CROPSIM_REFERENCE_SOURCES} PROPERTIES
    COMPILE_OPTIONS "-O2;-ffree-line-length-none;-std=legacy;-ffp-contract=off")
  # -frecursive keeps every local on the stack, so the kernel can run
  # on many threads at once.
  set_source_files_properties(${CROPSIM_KERNEL_SOURCES} PROPERTIES
    COMPILE_OPTIONS "-O2;-std=f2018;-frecursive;-ffp-contract=off")
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
  target_compile_options(cropsim PRIVATE -O2 -fp-model=precise -recursive)
endif()

# Install the library inside the Python package directory.
install(TARGETS cropsim
  LIBRARY DESTINATION cropsim
  RUNTIME DESTINATION cropsim
  ARCHIVE DESTINATION cropsim/lib
)
