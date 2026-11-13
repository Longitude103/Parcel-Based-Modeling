!=======================================================================
!  csk_capi - C interface to the CropSim kernel (see cropsim_kernel.h).
!
!    csk_version()                 API version
!    csk_struct_size(which)        byte size of each interface struct
!    csk_run_year(...)             run one year; thread-safe
!
!  The caller owns every input and output; the kernel keeps nothing
!  between calls.
!=======================================================================
module csk_capi
  use, intrinsic :: iso_c_binding
  use csk_types
  use csk_kernel
  implicit none
  private

contains

  function csk_version() bind(c, name='csk_version') result(v)
    integer(c_int) :: v
    v = CSK_API_VERSION
  end function csk_version

  ! 1 params, 2 sim, 3 soil, 4 weather, 5 state, 6 options, 7 result
  function csk_struct_size(which) bind(c, name='csk_struct_size') result(nbytes)
    integer(c_int), value :: which
    integer(c_int) :: nbytes
    type(csk_params_t)  :: a
    type(csk_sim_t)     :: b
    type(csk_soil_t)    :: c
    type(csk_weather_t) :: d
    type(csk_state_t)   :: e
    type(csk_options_t) :: f
    type(csk_result_t)  :: g
    select case (which)
      case (1); nbytes = int(c_sizeof(a), c_int)
      case (2); nbytes = int(c_sizeof(b), c_int)
      case (3); nbytes = int(c_sizeof(c), c_int)
      case (4); nbytes = int(c_sizeof(d), c_int)
      case (5); nbytes = int(c_sizeof(e), c_int)
      case (6); nbytes = int(c_sizeof(f), c_int)
      case (7); nbytes = int(c_sizeof(g), c_int)
      case default; nbytes = -1
    end select
  end function csk_struct_size

  function csk_run_year(params, sim, soil, weather, state_in, options, state_out, res) &
      bind(c, name='csk_run_year') result(status)
    type(csk_params_t),  intent(in)  :: params
    type(csk_sim_t),     intent(in)  :: sim
    type(csk_soil_t),    intent(in)  :: soil
    type(csk_weather_t), intent(in)  :: weather
    type(csk_state_t),   intent(in)  :: state_in
    type(csk_options_t), intent(in)  :: options
    type(csk_state_t),   intent(out) :: state_out
    type(csk_result_t),  intent(out) :: res
    integer(c_int) :: status

    call run_year(params, sim, soil, weather, state_in, options, state_out, res)
    if (options%legacy_round /= 0 .and. res%status /= CSK_ERR_BAD_INPUT) &
      call round_like_initial_dat(state_out)
    status = res%status
  end function csk_run_year

  ! Round the state as writing and re-reading INITIAL.DAT did, so a
  ! chain of runs can match the original program digit for digit.
  subroutine round_like_initial_dat(st)
    type(csk_state_t), intent(inout) :: st
    character(len=200) :: buf
    integer :: k
    write(buf, '(10(2X,F6.3))') (st%theta(k), k = 1, 10)
    read(buf, *) (st%theta(k), k = 1, 10)
    write(buf, '(2X,I4,2X,F9.1,2X,I4)') st%oldcrp, st%oldres, st%livecrop
    read(buf, *) st%oldcrp, st%oldres, st%livecrop
    write(buf, '(2X,F8.1,4X,F6.2,4X,10(2X,F5.1))') st%snotmp, st%snoh2o, (st%soilt(k), k = 1, 10)
    read(buf, *) st%snotmp, st%snoh2o, (st%soilt(k), k = 1, 10)
  end subroutine round_like_initial_dat

end module csk_capi
