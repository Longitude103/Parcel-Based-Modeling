!=======================================================================
!  csk_kernel - run one year of CropSim for one SIM, soil and weather.
!
!  run_year is the per-year part of the original main program
!  (PROGRAM CROPSIMv7, lines 812-1168): it sets up the soil, crop and
!  carryover state, prepares the weather, runs the daily water balance,
!  computes the yield and hands back the end-of-year state.
!
!  It touches nothing outside its arguments, so any number of runs can
!  go at once on different threads.
!=======================================================================
module csk_kernel
  use csk_types
  use csk_physics
  use csk_balance
  implicit none
  private

  public :: run_year

contains

  subroutine run_year(p, simp, soilp, wx, state_in, opt, state_out, res)
    type(csk_params_t),  intent(in)  :: p
    type(csk_sim_t),     intent(in)  :: simp
    type(csk_soil_t),    intent(in)  :: soilp
    type(csk_weather_t), intent(in)  :: wx
    type(csk_state_t),   intent(in)  :: state_in
    type(csk_options_t), intent(in)  :: opt
    type(csk_state_t),   intent(out) :: state_out
    type(csk_result_t),  intent(out) :: res

    type(csk_work_t) :: w
    integer :: k, i, livecrop_deplt
    real :: soilrz, rzfact, rdepth, d

    res = empty_result()
    state_out = state_in

    if (.not. valid_inputs()) then
      res%status = CSK_ERR_BAD_INPUT
      return
    end if

    w%fixes = not(opt%revert)      ! fixes on unless reverted
    call load_params(w, p)
    w%iyear = wx%year
    w%livecond = opt%livecond

    ! ---- SIM values (original 828-910) ----
    w%crop = simp%crop
    w%layers = simp%layers
    w%implt = simp%implt
    w%idplt = simp%idplt
    w%imbg = simp%imbg
    w%idbg = simp%idbg
    w%imend = simp%imend
    w%idend = simp%idend
    w%gddveg = simp%gddveg
    w%gddflo = simp%gddflo
    w%gddripe = simp%gddripe
    w%gyform = simp%gyform
    w%gddefc = simp%gddefc
    w%gddmat = simp%gddmat
    w%ncut = simp%ncut
    w%jdycut = simp%jdycut
    w%rzmin = simp%rzmin
    w%rzmax = simp%rzmax
    w%tbreak = simp%tbreak
    w%gddroot = simp%gddroot
    w%rzmgmt = simp%rzmgmt
    w%iyield = simp%iyield
    w%ymax = simp%ymax
    w%ycoeff = simp%ycoeff

    ! Root zone limits scaled by the soil's water holding class
    ! (original 849-856), except for pastures.
    w%soil = soilp%soil
    if ((w%crop /= 12) .and. (w%crop /= 13)) then
      soilrz = w%soil/100
      rzfact = min((0.6 + 0.4*(soilrz - 3.0)/4.0), 1.0)
      w%rzmgmt = w%rzmgmt * rzfact
      w%rzmax = w%rzmax * rzfact
    end if
    ! The original scales RZMAX but not RZMIN, so on shallow soils RZMIN
    ! can exceed RZMAX and the roots start deeper than the soil allows.
    if (fix_on(w, FIX_RZMIN_CAP)) w%rzmin = min(w%rzmin, w%rzmax)

    w%iterrc = simp%iterrc
    w%chand = simp%chand
    w%chanw = simp%chanw
    w%tintrv = simp%tintrv
    w%ntills = simp%ntills
    w%itflag = simp%itflag
    do k = 1, w%ntills
      w%itiltm(k) = simp%itiltm(k)
      w%tilday(k) = simp%tilday(k)
      w%tilcod(k) = simp%tilcod(k)
    end do
    w%irrtyp = simp%irrtyp
    w%pad = simp%pad
    w%rainal = simp%rainal
    w%syscap = simp%syscap
    w%iper = simp%iper
    w%apmin = simp%apmin
    w%apmax = simp%apmax
    w%smalli = simp%smalli
    w%gstart = simp%gstart
    w%gstop = simp%gstop
    w%irrsch = simp%irrsch
    w%jfirst = simp%jfirst
    w%jstopi = simp%jstopi
    w%jgoi = simp%jgoi
    w%jdfreq = simp%jdfreq
    w%ddepth = simp%ddepth
    w%eapp = simp%eapp
    w%ereuse = simp%ereuse
    w%prunof = simp%prunof

    ! ---- Soil properties (original 913-984) ----
    ! Known-irrigation runs (IRRTYP 2) take the soil from the SIM.
    if (w%irrtyp == 2) then
      w%alpha1 = simp%alpha1
      w%airdry = simp%airdry
      w%fieldc = simp%fieldc
      w%pwp = simp%pwp
      w%bulkd = simp%bulkd
      w%kirr = simp%kirr
      do k = 1, w%kirr
        w%fdirrig(k,1) = simp%fdirrig(1,k)
        w%fdirrig(k,2) = simp%fdirrig(2,k)
        w%fdirrig(k,3) = simp%fdirrig(3,k)
      end do
    else
      w%alpha1 = 0.0
      w%bulkd = soilp%bulkd
      w%orgm = soilp%orgm
      w%fieldc = soilp%fieldc
      w%pwp = soilp%pwp
      w%airdry = soilp%airdry
    end if

    w%ihygrp = w%soil/10 - 10*(w%soil/100)
    w%satwc = 1.0 - w%bulkd/2.65
    w%draind = soilp%drnday
    w%dcoeff = soilp%drncoe

    ! Effective wilting point rises toward field capacity below the
    ! root zone; available water per layer.
    w%totdep = 0.
    do i = 1, w%layers
      w%center(i) = w%totdep + w%depth(i)*0.5
      rdepth = w%center(i)/w%rzmax
      if (rdepth > 1.) rdepth = 1.
      d = exp(-2.303*rdepth**4.462)
      w%avmft(i) = (w%fieldc(i) - w%pwp(i))*w%depth(i)
      w%pwp(i) = w%pwp(i) + (w%fieldc(i) - w%pwp(i))*(1. - d)
      w%pawft(i) = (w%fieldc(i) - w%pwp(i))*w%depth(i)
      w%totdep = w%totdep + w%depth(i)
    end do

    ! ---- Carryover state (original 986-998) ----
    w%theta = state_in%theta
    w%oldcrp = state_in%oldcrp
    w%oldres = state_in%oldres
    w%livecrop = state_in%livecrop
    w%snotmp = state_in%snotmp
    w%snoh2o = state_in%snoh2o
    w%soilt = state_in%soilt

    if (w%livecond == 1) w%livecrop = 1
    if (w%crop < 10) then
      w%residue = w%oldres
    else
      w%residue = 100.
    end if

    ! ---- Winter wheat (original 1005-1035) ----
    ! A live crop at the start of the year was planted last fall: its
    ! season starts at spring green-up (March 15).
    if (w%crop == 7) then
      call dayofyr(w%jdyplt, w%implt, w%idplt, leap_calendar(w))
      w%jfplt = w%jdyplt
      if ((w%irrtyp > 1) .or. (w%itflag > 2)) then
        w%livecrop = 1
      else
        if (w%livecrop == 0) w%itflag = 0
      end if
      if (w%livecrop == 1) then
        w%implt = 3
        w%idplt = 15
        if ((w%irrtyp == 1) .and. (w%itflag < 3)) w%jfplt = -999
      end if
    else
      w%livecrop = 0
      w%jfplt = -999
    end if

    w%dplbg = 0.0
    do i = 1, w%layers
      w%dplbg = w%dplbg + (w%fieldc(i) - w%theta(i))*w%depth(i)
    end do

    ! ---- Dates and weather (original 1049-1053, READWEAT) ----
    call dayofyr(w%jdybg, w%imbg, w%idbg, leap_calendar(w))
    call dayofyr(w%jdyend, w%imend, w%idend, leap_calendar(w))
    call dayofyr(w%jdyplt, w%implt, w%idplt, leap_calendar(w))
    w%imstr = wx%imstr
    w%idstr = wx%idstr
    w%lat = wx%lat
    w%long = wx%long
    w%elev = wx%elev
    w%wx_ndays = wx%ndays
    w%wx_tmax = wx%tmax
    w%wx_tmin = wx%tmin
    w%wx_precip = wx%precip
    w%wx_etr = wx%etr
    call prepare_weather(w)

    ! ---- Tillage dates (original 1059-1081) ----
    ! Timing 1 = days before planting, 2 = after planting, 3 = after
    ! maturity (wheat: after harvest, or next fall for a new crop).
    do i = 1, w%ntills
      if (w%crop /= 7) then
        if (w%itiltm(i) == 1) w%tilday(i) = w%jdyplt - w%tilday(i)
        if (w%itiltm(i) == 2) w%tilday(i) = w%jdyplt + w%tilday(i)
        if (w%itiltm(i) == 3) w%tilday(i) = w%jdymat + w%tilday(i)
      else if (w%livecrop == 0) then
        if (w%itiltm(i) == 1) w%tilday(i) = w%jdyplt - w%tilday(i)
        if (w%itiltm(i) == 2) w%tilday(i) = w%jdyplt + w%tilday(i)
        if (w%itiltm(i) == 3) w%tilday(i) = 367 + w%tilday(i)
      else
        if (w%itiltm(i) == 1) w%tilday(i) = -999 - w%tilday(i)
        if (w%itiltm(i) == 2) w%tilday(i) = -999 + w%tilday(i)
        if (w%itiltm(i) == 3) w%tilday(i) = w%jdymat + w%tilday(i)
      end if
    end do

    ! ---- Water balance and yield (original 1116-1127) ----
    livecrop_deplt = w%livecrop
    call water_balance(w, res)

    if (w%itflag > 0) then
      call crop_yield(w)
    else
      w%yield = 0.0
      w%yldratio = 0.0
    end if

    ! ---- Winter wheat live-crop flag for next year (1131-1149) ----
    ! In wheat-fallow, a crop alive at the start of the year was
    ! harvested; one that was not was planted this fall.
    if (w%crop == 7) then
      if ((w%irrtyp == 1) .and. (w%itflag < 3)) then
        if (w%livecrop == 1) then
          w%livecrop = 0
        else
          w%livecrop = 1
        end if
      else
        w%livecrop = 1
      end if
    else
      w%livecrop = 0
    end if

    ! ---- End-of-year state ----
    state_out%theta = w%theta
    state_out%oldcrp = w%crop
    state_out%oldres = w%residue
    state_out%livecrop = w%livecrop
    state_out%snotmp = w%snotmp
    state_out%snoh2o = w%snoh2o
    state_out%soilt = w%soilt

    ! ---- Results ----
    ! Crop labels as the COHYST files gave them (fallow wheat = 15).
    res%crop_yr = w%crop
    if ((w%crop == 7) .and. (w%livecrop == 1) .and. (w%irrtyp == 1) .and. &
        (w%itflag /= 3)) res%crop_yr = 15
    res%crop_mon = w%crop
    if ((w%crop == 7) .and. (livecrop_deplt == 0) .and. (w%irrtyp == 1) .and. &
        (w%itflag /= 3)) res%crop_mon = 15

    res%totrof = 0.
    do k = w%imbg, w%imend
      res%totrof = res%totrof + w%rofmon(k)
    end do

    res%imbg = w%imbg
    res%imend = w%imend
    res%jdyplt = w%jdyplt
    res%jfirst = w%jfirst
    res%jdyefc = w%jdyefc
    res%jdymat = w%jdymat
    res%jdyfrz = w%jdyfrz
    res%irigno = w%irigno
    res%itflag = w%itflag
    res%yield = w%yield
    res%yldratio = w%yldratio
    res%bvalue = w%bvalue
    res%etmax = w%etmax
    res%etyld = w%etyld
    res%ets = w%ets
    res%etrs = w%etrs
    res%es = w%es
    res%ts = w%ts
    res%sgrirr = w%sgrirr
    res%snirr = w%snirr
    res%precips = w%precips
    res%eprecips = w%eprecips
    res%drains = w%drains
    res%dplbg = w%dplbg
    res%etrmon = w%etrmon
    res%emon = w%emon
    res%tmon = w%tmon
    res%etmon = w%etmon
    res%ermon = w%ermon
    res%ramon = w%ramon
    res%rofmon = w%rofmon
    res%ronmon = w%ronmon
    res%irnmon = w%irnmon
    res%irgmon = w%irgmon
    res%infmon = w%infmon
    res%dramon = w%dramon
    res%dplmon = w%dplmon
    res%numirr = w%numirr
    res%etrwk = w%etrwk
    res%etwk = w%etwk
    res%erwk = w%erwk
    res%rawk = w%rawk
    res%irnwk = w%irnwk
    res%irgwk = w%irgwk
    res%jdybg = w%jdybg
    res%jdyend = w%jdyend
    res%wetsups = w%wetsups
    res%wsmon = w%wsmon
    res%balerr = w%balerr
    res%status = w%status

  contains

    logical function valid_inputs()
      valid_inputs = .false.
      if ((simp%crop < 1) .or. (simp%crop > NCROP)) return
      if ((simp%layers < 1) .or. (simp%layers > NLAY)) return
      if ((simp%irrtyp < 1) .or. (simp%irrtyp > 5)) return
      ! Scheduled irrigation (IRRTYP 3-5) supports IRRSCH 1-3 only; the
      ! original's forecast methods (4, 5) and the unimplemented 6 are
      ! rejected (decided by Heath, 2026-11-13).
      if ((simp%irrtyp >= 3) .and. ((simp%irrsch < 1) .or. (simp%irrsch > 3))) return
      if ((simp%ntills < 0) .or. (simp%ntills > NTILL)) return
      if ((simp%kirr < 0) .or. (simp%kirr > NEVENT)) return
      if (simp%crop == 10 .and. ((simp%ncut < 1) .or. (simp%ncut > 5))) return
      if (any(simp%tilcod(1:simp%ntills) < 1) .or. any(simp%tilcod(1:simp%ntills) > 80)) return
      if ((simp%imbg < 1) .or. (simp%imbg > 12) .or. (simp%imend < 1) .or. (simp%imend > 12)) return
      if ((simp%implt < 1) .or. (simp%implt > 12)) return
      if ((wx%ndays < 1) .or. (wx%ndays > NDAY)) return
      if ((wx%imstr < 1) .or. (wx%imstr > 12)) return
      if ((state_in%oldcrp < 1) .or. (state_in%oldcrp > NCROP)) return
      if ((p%nfday < 0) .or. (p%nfday > NFCST - NDAY)) return
      valid_inputs = .true.
    end function valid_inputs

  end subroutine run_year

  subroutine load_params(w, p)
    type(csk_work_t), intent(inout) :: w
    type(csk_params_t), intent(in) :: p
    w%etrfact = p%etrfact
    w%nfday = p%nfday
    w%ytrend = p%ytrend
    w%depth = p%depth
    w%ydens = p%ydens
    w%resrat = p%resrat
    w%spgrav = p%spgrav
    w%fragil = p%fragil
    w%restyp = p%restyp
    w%cc = p%cc
    w%kcl = p%kcl
    w%kcu = p%kcu
    w%tbase = p%tbase
    w%tceil = p%tceil
    w%sftmp = p%sftmp
    w%smfmx = p%smfmx
    w%smfmn = p%smfmn
    w%snocovmx = p%snocovmx
    w%snocov1 = p%snocov1
    w%snocov2 = p%snocov2
    w%timp = p%timp
    w%smtmp = p%smtmp
    w%cnfallow = p%cnfallow
    w%cn = p%cn
    w%tilfac = p%tilfac
  end subroutine load_params

  function empty_result() result(r)
    type(csk_result_t) :: r
    r%status = CSK_OK
    r%crop_yr = 0; r%crop_mon = 0; r%imbg = 0; r%imend = 0
    r%jdyplt = 0; r%jfirst = 0; r%jdyefc = 0; r%jdymat = 0; r%jdyfrz = 0
    r%irigno = 0; r%itflag = 0
    r%yield = 0.; r%yldratio = 0.; r%bvalue = 0.; r%etmax = 0.; r%etyld = 0.
    r%ets = 0.; r%etrs = 0.; r%es = 0.; r%ts = 0.
    r%sgrirr = 0.; r%snirr = 0.; r%precips = 0.; r%eprecips = 0.; r%drains = 0.
    r%dplbg = 0.; r%totrof = 0.
    r%etrmon = 0.; r%emon = 0.; r%tmon = 0.; r%etmon = 0.
    r%ermon = 0.; r%ramon = 0.; r%rofmon = 0.; r%ronmon = 0.
    r%irnmon = 0.; r%irgmon = 0.; r%infmon = 0.; r%dramon = 0.; r%dplmon = 0.
    r%numirr = 0
    r%etrwk = 0.; r%etwk = 0.; r%erwk = 0.; r%rawk = 0.; r%irnwk = 0.; r%irgwk = 0.
    r%jdybg = 0; r%jdyend = 0
    r%wetsups = 0.; r%wsmon = 0.; r%balerr = 0.
    r%d_gdd = 0.; r%d_kc = 0.; r%d_rzd = 0.; r%d_etr = 0.
    r%d_precip = 0.; r%d_eprecip = 0.; r%d_runoff = 0.; r%d_runon = 0.
    r%d_grirr = 0.; r%d_nirr = 0.; r%d_irrinf = 0.; r%d_e = 0.; r%d_t = 0.
    r%d_et = 0.; r%d_drain = 0.; r%d_wetsup = 0.; r%d_snow = 0.; r%d_soilw = 0.
    r%d_dpln = 0.; r%d_awdpln = 0.; r%d_balerr = 0.
  end function empty_result

end module csk_kernel
