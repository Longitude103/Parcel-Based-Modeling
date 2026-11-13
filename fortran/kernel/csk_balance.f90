!=======================================================================
!  csk_balance - the daily soil water balance (DEPLT, original lines
!  1859-2750) and irrigation scheduling (IRRIGA, 2774-2990).
!
!  The original's print-only work (daily, monthly and weekly reports,
!  off-season totals) is left out; everything it returned is kept, and
!  daily values are recorded for the caller.
!=======================================================================
module csk_balance
  use csk_types
  use csk_physics
  implicit none
  private

  public :: water_balance

contains

  logical function is_wet_cover(crop)
    integer, intent(in) :: crop
    ! Riparian woodland, wetlands and open water: ET = KC * ETR.
    is_wet_cover = (crop == 16) .or. (crop == 18) .or. (crop == 19) .or. &
                   (crop == 20) .or. (crop == 21)
  end function is_wet_cover

  !---------------------------------------------------------------------
  !  Irrigation scheduling for the day (IRRIGA).
  !
  !  IRRSCH 1, 2  demand: irrigate at the allowable depletion
  !  IRRSCH 3     rotation: fixed delivery depth DDEPTH
  !  IRRSCH 4     demand, delayed if the forecast rain covers it
  !  IRRSCH 5     demand, delayed if forecast rain exceeds 1 inch
  !---------------------------------------------------------------------
  subroutine irrigate(w)
    type(csk_work_t), intent(inout) :: w
    real :: rainstor, cyclet, soilmd, forcrain
    integer :: istage, jdsch, jday

    jday = w%jday
    w%netirr = 0.0
    w%groirr = 0.0
    istage = w%kstg
    if (w%kstg == 0) istage = w%icut
    rainstor = w%rainal(istage) * w%dpla

    select case (w%irrsch)
    case (:2)
      if (w%awdpln < w%dpla) return
      if ((w%gdd < w%gstart) .or. (w%gdd >= w%gstop)) return
      if (w%today + 1 < w%jnexti) return
      w%netirr = w%dpln - rainstor
      call size_demand_irrigation(.true.)

    case (3)
      soilmd = w%awdpln - rainstor
      if (soilmd <= w%eapp(istage)*w%smalli(istage)) then
        w%netirr = 0.0
        w%groirr = 0.0
        w%dinf = 0.0
      else
        w%groirr = w%ddepth
        w%netirr = w%ddepth*w%eapp(istage)
        if (w%irrtyp > 3) then
          w%dinf = w%groirr*(1.0 - (1.0 - w%ereuse(istage))*w%prunof(istage))
        else
          w%dinf = w%netirr
        end if
        w%irigno = w%irigno + 1
        if (w%irigno == 1) w%jfirst = jday
        ! The original never advanced JNEXTI here, so after the first
        ! delivery water could come on any day.
        if (fix_on(w, FIX_ROTATION_FREQUENCY)) w%jnexti = real(jday + w%jdfreq)
      end if

    case (4)
      if (jday < w%jnexti) return
      if ((w%gdd < w%gstart) .or. (w%gdd >= w%gstop)) return
      forcrain = 0.0
      do jdsch = jday + 1, jday + w%nfday
        forcrain = forcrain + w%precip(jdsch)
      end do
      if ((w%awdpln - forcrain) < w%dpla) then
        w%netirr = 0.
      else
        w%netirr = max(w%dpln - rainstor, 0.)
      end if
      call size_demand_irrigation(.false.)

    case (5)
      if (jday < w%jnexti) return
      if ((w%gdd < w%gstart) .or. (w%gdd >= w%gstop)) return
      forcrain = 0.0
      do jdsch = jday + 1, jday + w%nfday
        forcrain = forcrain + w%precip(jdsch)
      end do
      if ((w%awdpln < w%dpla) .or. (forcrain > 1.0)) then
        w%netirr = 0.
      else
        w%netirr = max(w%dpln - rainstor, 0.)
      end if
      call size_demand_irrigation(.false.)
    end select

  contains

    ! Gross depth from the net requirement, bounded by the smallest,
    ! minimum and maximum application for the stage; then infiltration
    ! (surface systems lose tailwater) and the next allowed day.
    subroutine size_demand_irrigation(demand)
      logical, intent(in) :: demand
      w%groirr = w%netirr/w%eapp(istage)
      if (w%groirr < w%smalli(istage)) then
        w%netirr = 0.0
        w%groirr = 0.0
        w%dinf = 0.0
        ! The forecast methods (4, 5) carry on from here in the original,
        ! so a day with no irrigation still counts in IRIGNO.
        if (demand .or. fix_on(w, FIX_IRRIGATION_COUNT)) return
      else
        if (w%groirr < w%apmin(istage)) w%groirr = w%apmin(istage)
        if (w%groirr > w%apmax(istage)) w%groirr = w%apmax(istage)
        w%netirr = w%groirr*w%eapp(istage)
      end if

      if (w%irrtyp == 4) then
        w%dinf = w%groirr*(1.0 - (1.0 - w%ereuse(istage))*w%prunof(istage))
      else
        w%dinf = w%netirr
      end if
      cyclet = w%groirr/(w%syscap*w%iper(istage))
      w%jnexti = max(w%today, w%jnexti) + cyclet
      w%irigno = w%irigno + 1
      if (w%irigno == 1) w%jfirst = jday
    end subroutine size_demand_irrigation

  end subroutine irrigate

  !---------------------------------------------------------------------
  !  Daily water balance from JDYBG to JDYEND.
  !---------------------------------------------------------------------
  subroutine water_balance(w, res)
    type(csk_work_t), intent(inout) :: w
    type(csk_result_t), intent(inout) :: res
    real :: e, t, et, tup, drain, extra, distd, amt, addl, thetup, dfract, dist
    real :: s0, s1, inflow, outflow
    integer :: i, jday, jdywet, imon, iday, iweek, itill, crop
    logical :: wet, reach248

    crop = w%crop
    wet = is_wet_cover(crop)

    ! ---- Initialise (original 1863-1945) ----
    w%awater = 0.
    w%cume = 0.
    w%drains = 0.
    w%eprecips = 0.
    w%es = 0.
    w%etmax = 0.
    w%etrs = 0.
    w%ets = 0.
    w%etyld = 0.
    w%eveg = 0.
    w%icut = 1
    w%irigno = 0
    w%ievent = 1
    w%jnexti = 1
    jdywet = w%jdybg - 1
    w%kstg = 0
    w%precips = 0.
    w%runons = 0.
    w%rzd = w%rzmin
    w%sgrirr = 0.
    w%snirr = 0.
    w%tdefs = 0.
    w%time = jdywet
    w%ts = 0.
    w%tveg = 0.
    w%tdef = 0.
    w%tps = 0.
    w%perrzd = 0.
    w%wetsups = 0.
    w%balerr = 0.

    tup = w%kcl(crop)/(w%kcu(crop) - w%kcl(crop))

    w%totwat = 0.
    do i = 1, w%layers
      w%totwat = w%totwat + w%theta(i) * w%depth(i)
    end do

    w%etrmon = 0.; w%emon = 0.; w%tmon = 0.; w%etmon = 0.
    w%ermon = 0.; w%ramon = 0.; w%rofmon = 0.; w%ronmon = 0.
    w%irnmon = 0.; w%irgmon = 0.; w%infmon = 0.; w%dramon = 0.
    w%wsmon = 0.
    w%etrwk = 0.; w%etwk = 0.; w%erwk = 0.; w%rawk = 0.
    w%irnwk = 0.; w%irgwk = 0.

    ! ---- Daily loop ----
    do jday = w%jdybg, w%jdyend
      w%jday = jday
      w%today = jday
      w%eprecip = 0.0
      e = 0.0
      t = 0.0
      et = 0.0
      w%runoff = 0.0
      w%runon = 0.0
      w%infday = 0.0
      w%irrinf = 0.0
      w%wetsup = 0.0
      w%gdd = w%gdds(jday)
      w%tavg = 0.5 * (w%tmax(jday) + w%tmin(jday))
      s0 = storage()

      ! Growth stage: by GDD for grain and tuber crops, by cutting for
      ! alfalfa and hay, and before/after cover for the rest.
      if (crop < 12) then
        w%kstg = 1
        if (w%gdd > w%gddflo) w%kstg = 2
        if (w%gdd > w%gddripe) w%kstg = 3
        if ((crop == 10) .or. (crop == 11)) then
          ! The original set ICUT to 1 at the start and never updated it
          ! here (CROPCO, which tracks cuttings, ran before DEPLT).
          if (fix_on(w, FIX_FORAGE_CUTTING_STAGE)) w%icut = cutting_cycle(w%icut)
          w%kstg = w%icut
        end if
      else
        w%kstg = 1
        if (w%gdd > w%gddefc) w%kstg = 2
      end if

      if ((w%rzd < w%rzmax) .or. (w%awater <= 0.0)) call root_zone(w)

      ! Rain and snow melt: runoff, then infiltration.
      if ((w%precip(jday) > 0.) .or. (w%snoh2o > 0.0)) then
        w%rain = w%precip(jday)
        if (fix_on(w, FIX_SNOWMELT_BASE)) then
          call snowmelt(w, w%smtmp)
        else
          call snowmelt(w, 0.0)          ! SMTMP was never set in the original
        end if
        call effective_precip(w, .false.)
        if ((w%eprecip > w%rain) .and. (w%iterrc == 0)) then
          if (w%status == 0) w%status = CSK_ERR_EFF_PRECIP
        end if
        if (w%irrtyp == 2) w%eprecip = w%precip(jday)
        w%dinf = w%eprecip
        jdywet = jday
        call infiltrate(w)
      end if

      w%awdpln = mgmt_depletion(w)
      w%dpla = w%awater*w%pad(w%kstg)

      ! ---- Irrigation ----
      irrigation: block
        if (w%irrtyp == 1) exit irrigation

        if (w%irrsch == 3) then
          ! Rotation delivery: not before the first delivery date, not
          ! after Nov 1 (forage) or maturity (other crops), and not in
          ! the summer shut-off for alfalfa, hay and pasture.
          if (jday < w%jfirst) exit irrigation
          if ((crop >= 10) .and. (crop <= 12)) then
            if ((jday > w%jstopi) .and. (jday < w%jgoi)) exit irrigation
            if (jday > 304) exit irrigation
          else
            if (jday > w%jdymat) exit irrigation
          end if
          if (w%irigno < 1) then
            call irrigate(w)
            if (w%irigno < 1) exit irrigation
          else
            if (jday < w%jnexti) exit irrigation
            call irrigate(w)
          end if
        else
          if (fix_on(w, FIX_IRRIGATION_COUNT)) then
            if (w%irrtyp == 2) then
              ! Known irrigation dates and depths, with their own index.
              if (int(w%fdirrig(w%ievent,1)) /= jday) exit irrigation
              w%groirr = w%fdirrig(w%ievent,2)
              w%netirr = w%groirr*w%fdirrig(w%ievent,3)
              w%dinf = w%netirr
              w%ievent = w%ievent + 1
              w%irigno = w%irigno + 1
              if (w%irigno == 1) w%jfirst = jday
            end if
          else
            ! The original used IRIGNO as the index of the next known
            ! irrigation and started it at 1 for every irrigated run.
            if (w%irigno < 1) w%irigno = 1
            if (w%irrtyp == 2) then
              if (int(w%fdirrig(w%irigno,1)) /= jday) exit irrigation
              w%groirr = w%fdirrig(w%irigno,2)
              w%netirr = w%groirr*w%fdirrig(w%irigno,3)
              w%dinf = w%netirr
              w%irigno = w%irigno + 1
            end if
          end if
          if (w%irrtyp > 2) then
            if ((w%gdd < w%gstart) .or. (w%gdd > w%gstop)) exit irrigation
            call irrigate(w)
          end if
        end if

        w%sgrirr = w%sgrirr + w%groirr
        w%snirr = w%snirr + w%netirr
        w%irrinf = w%dinf
        jdywet = jday
        call infiltrate(w)
      end block irrigation

      ! ---- Crop coefficient, residue and soil temperature ----
      w%kc = w%cropkc(jday)
      if (crop < 10) then
        if (jday == w%jdymat) then
          if ((crop /= 7) .or. (w%livecrop == 1)) then
            call crop_yield(w)
            w%residue = w%yield * w%ydens(crop) * w%resrat(crop)
            w%oldcrp = crop
          end if
        end if
        do itill = 1, w%ntills
          if (jday == w%tilday(itill)) then
            w%residue = w%residue*w%tilfac(w%tilcod(itill), w%fragil(w%oldcrp))/100.
          end if
        end do
      end if

      call soil_temperature(w)

      ! ---- Evaporation and transpiration ----
      reach248 = .false.
      if (.not. wet) then
        if (w%etr(jday) > 0.) then
          w%ep = w%etr(jday)*min((w%kcu(crop) + w%kcl(crop) - w%kc), 1.0)
          w%epmax = w%ep
          if (w%ep <= 0.) w%ep = 0.001
          if (w%ep <= 0.001) then
            call transpiration(reach248)
          else
            call evaporation(w)
            w%theta(1) = w%theta(1) - w%e1/w%depth(1)
            w%theta(2) = w%theta(2) - w%e2/w%depth(2)
            e = w%e1 + w%e2
            if (crop == 15) then
              reach248 = .true.        ! no transpiration from fallow
            else
              call transpiration(reach248)
            end if
          end if
        end if
      end if

      ! Seasonal ET and transpiration deficit totals.
      if (reach248) then
        if (crop < 10) then
          if ((w%gdd >= w%gddveg) .and. (w%gdd <= w%gyform)) then
            w%etmax = w%e1 + w%e2 + w%tp + w%etmax
            w%etyld = w%e1 + w%e2 + t + w%etyld
            w%tps(w%kstg) = w%tps(w%kstg) + w%tp
            w%tdefs = w%tdefs + w%tp - t
            w%tdef(w%kstg) = w%tdef(w%kstg) + w%tp - t
          end if
        else if ((crop > 9) .and. (crop < 12)) then
          w%tps(w%icut) = w%tps(w%icut) + w%tp
          w%tdefs = w%tdefs + w%tp - t
          w%tdef(w%icut) = w%tdef(w%icut) + w%tp - t
          w%etmax = w%e1 + w%e2 + w%tp + w%etmax
          w%etyld = w%e1 + w%e2 + t + w%etyld
        end if
      end if

      ! Wetlands and open water: ET from the crop coefficient; the
      ! profile is held at field capacity.
      if (wet) then
        et = w%kc * w%etr(jday)
        do i = 1, w%layers
          w%theta(i) = w%fieldc(i)
        end do
      end if

      ! ---- Redistribution of water above field capacity ----
      extra = 0.
      distd = 0.0
      do i = 1, w%layers
        if (w%theta(i) > w%fieldc(i)) then
          extra = extra + (w%theta(i) - w%fieldc(i))*w%depth(i)
          w%theta(i) = w%fieldc(i)
          distd = distd + w%depth(i)
          cycle
        end if
        if (extra == 0.) cycle
        amt = (w%fieldc(i) - w%theta(i))*w%depth(i)
        if (amt >= extra) then
          addl = extra
          extra = 0.
        else
          addl = amt
          extra = extra - amt
        end if
        thetup = addl/w%depth(i)
        w%theta(i) = w%theta(i) + thetup
        if (w%theta(i) >= w%fieldc(i)) distd = distd + w%depth(i)
      end do

      ! ---- Drainage below the profile ----
      drain = 0.0
      if (extra > 0.0) then
        dfract = (real(jday - jdywet + 1)/w%draind)**w%dcoeff
        if (dfract > 1.0) dfract = 1.0
        drain = extra * dfract
        dist = (1.0 - dfract) * extra/distd
        do i = 1, w%layers
          if (w%theta(i) >= w%fieldc(i)) w%theta(i) = w%theta(i) + dist
        end do
      end if

      ! ---- Seasonal totals ----
      w%drains = w%drains + drain
      w%etrs = w%etrs + w%etr(jday)
      w%es = w%es + e
      w%precips = w%precips + w%precip(jday)
      w%eprecips = w%eprecips + w%eprecip
      w%runons = w%runons + w%runon
      w%ts = w%ts + t
      if (w%gdd <= w%gddveg) then
        w%eveg = w%eveg + e
        w%tveg = w%tveg + t
      end if

      ! Whole-profile depletion (used by the next day's irrigation) and
      ! management-zone depletion.
      w%dpln = 0.0
      do i = 1, w%layers
        w%dpln = w%dpln + (w%fieldc(i) - w%theta(i))*w%depth(i)
      end do
      w%awdpln = mgmt_depletion(w)

      if (wet) then
        w%ets = w%ets + et
      else
        w%ets = w%es + w%ts
      end if

      ! ---- Weekly totals ----
      iweek = (jday - 1) / 7 + 1
      w%etrwk(iweek) = w%etrwk(iweek) + w%etr(jday)
      w%etwk(iweek) = w%etwk(iweek) + e + t
      w%erwk(iweek) = w%erwk(iweek) + w%eprecip
      w%rawk(iweek) = w%rawk(iweek) + w%precip(jday)
      w%irnwk(iweek) = w%irnwk(iweek) + w%netirr
      w%irgwk(iweek) = w%irgwk(iweek) + w%groirr

      ! ---- Monthly totals ----
      call calday(jday, imon, iday)
      w%etrmon(imon) = w%etrmon(imon) + w%etr(jday)
      w%emon(imon) = w%emon(imon) + e
      w%tmon(imon) = w%tmon(imon) + t
      w%ermon(imon) = w%ermon(imon) + w%eprecip
      w%ramon(imon) = w%ramon(imon) + w%precip(jday)
      w%rofmon(imon) = w%rofmon(imon) + w%runoff
      w%ronmon(imon) = w%ronmon(imon) + w%runon
      if (w%rofmon(imon) < 0.0) then
        if (w%status == 0) w%status = CSK_ERR_NEG_RUNOFF
      end if
      if (wet) then
        w%etmon(imon) = w%etmon(imon) + et
      else
        w%etmon(imon) = w%emon(imon) + w%tmon(imon)
      end if
      w%dramon(imon) = w%dramon(imon) + drain
      w%irgmon(imon) = w%irgmon(imon) + w%groirr
      w%irnmon(imon) = w%irnmon(imon) + w%netirr
      w%numirr(imon) = w%irigno
      ! The original added DINF here, after infiltration had already
      ! set it to zero, so INFMON was always 0.
      w%infmon(imon) = w%infmon(imon) + w%dinf
      w%wsmon(imon) = w%wsmon(imon) + w%wetsup
      w%wetsups = w%wetsups + w%wetsup
      if (iday <= 1) w%dplmon(imon) = w%dpln

      w%totwat = 0.0
      do i = 1, w%layers
        w%totwat = w%totwat + w%theta(i)*w%depth(i)
      end do

      ! ---- Daily record and water balance check ----
      s1 = storage()
      inflow = w%precip(jday) + w%runon + w%irrinf + w%wetsup
      if (wet) then
        outflow = w%runoff + et + drain
      else
        outflow = w%runoff + e + t + drain
      end if
      res%d_gdd(jday) = w%gdd
      res%d_kc(jday) = w%kc
      res%d_rzd(jday) = w%rzd
      res%d_etr(jday) = w%etr(jday)
      res%d_precip(jday) = w%precip(jday)
      res%d_eprecip(jday) = w%eprecip
      res%d_runoff(jday) = w%runoff
      res%d_runon(jday) = w%runon
      res%d_grirr(jday) = w%groirr
      res%d_nirr(jday) = w%netirr
      res%d_irrinf(jday) = w%irrinf
      res%d_e(jday) = e
      res%d_t(jday) = t
      if (wet) then
        res%d_et(jday) = et
      else
        res%d_et(jday) = e + t
      end if
      res%d_drain(jday) = drain
      res%d_wetsup(jday) = w%wetsup
      res%d_snow(jday) = w%snoh2o
      res%d_soilw(jday) = w%totwat
      res%d_dpln(jday) = w%dpln
      res%d_awdpln(jday) = w%awdpln
      res%d_balerr(jday) = (s1 - s0) - (inflow - outflow)
      w%balerr = w%balerr + res%d_balerr(jday)

      w%groirr = 0.0
      w%netirr = 0.0
      w%dinf = 0.0
    end do

    ! The original relabelled dryland fallow wheat as crop 15 to write
    ! the monthly file and then set any crop 15 that matched back to 7
    ! (original 2719-2732). Real summer fallow (crop 15) therefore left
    ! DEPLT as winter wheat, which then drives the yield and the wheat
    ! live-crop flag for the next year.
    if (w%iyear > 1938) then
      if ((crop == 15) .and. (w%livecrop == 0) .and. (w%irrtyp == 1) .and. &
          (w%itflag /= 3)) w%crop = 7
    end if

  contains

    ! Cutting cycle for the day, by the same rules CROPCO uses.
    integer function cutting_cycle(prev) result(ic)
      integer, intent(in) :: prev
      integer :: k
      ic = prev
      if (jday < w%jdycut(1)) ic = 1
      if ((jday >= w%jdycut(1)) .and. (jday < w%jdycut(2))) ic = 2
      do k = 3, 5
        if ((jday > w%jdycut(k-1)) .and. (jday < w%jdycut(k))) ic = k
      end do
      if (jday >= w%jdycut(max(w%ncut, 1))) ic = max(w%ncut, 1)
    end function cutting_cycle

    real function storage()
      integer :: k
      storage = w%snoh2o
      do k = 1, w%layers
        storage = storage + w%theta(k)*w%depth(k)
      end do
    end function storage

    !-------------------------------------------------------------------
    !  Transpiration and root water uptake (DEPLT 200-245). Sets t.
    !  REACHED is false when there is no potential transpiration (the
    !  original skipped the seasonal totals then).
    !-------------------------------------------------------------------
    subroutine transpiration(reached)
      logical, intent(out) :: reached
      real :: tweigh, wavail, av, sr, trans, tuse, twait, uptake
      real :: perdep(NLAY), depl
      logical :: tflag
      integer :: k, itries

      reached = .false.
      w%tp = w%etr(jday)*(w%kc - w%kcl(crop))
      if (w%ep > 0.0) w%tp = w%tp*(1.0 + tup*(w%epmax - e)/w%epmax)
      if (w%tp <= 0.0) return
      reached = .true.

      tweigh = 0.0
      w%dpln = 0.0
      wavail = 0.0
      do k = 1, w%layers
        depl = (w%fieldc(k) - w%theta(k))*w%depth(k)*w%perrzd(k)
        if (depl < 0.0) depl = 0.0
        w%dpln = w%dpln + depl
        if (w%perrzd(k) > 0.0) then
          perdep(k) = depl/(w%pawft(k)*w%perrzd(k))
          if (perdep(k) > 1.0) perdep(k) = 1.0
          if (w%theta(k) > w%pwp(k)) then
            wavail = wavail + (w%theta(k) - w%pwp(k))*w%depth(k)*w%perrzd(k)
            tweigh = tweigh + w%rdf(k)*(1.0 - perdep(k))
          end if
        else
          perdep(k) = 0.0
        end if
      end do

      ! Stress factor from the depletion of plant available water.
      av = (1. - w%dpln/w%paw)*100.
      if (av < 0.) av = 0.
      sr = av/w%tbreak
      if (av > w%tbreak) sr = 1.0
      t = w%tp*sr
      if (t <= 0.0) return

      ! Uptake.
      trans = t
      tuse = 0.0
      w%dpln = 0.0
      twait = 0.0
      tflag = .false.
      itries = 1
      if (wavail <= t) then
        ! Demand exceeds the water available: take the root zone to PWP.
        do k = 1, w%layers
          w%theta(k) = w%pwp(k)*w%perrzd(k) + w%theta(k)*(1.0 - w%perrzd(k))
          perdep(k) = 1.0
        end do
        w%dpln = w%paw
        tuse = wavail
        return
      end if

      do
        do k = 1, w%layers
          uptake = trans*(1.0 - perdep(k))*w%rdf(k)/tweigh
          if (uptake < 0.0) uptake = 0.0
          wavail = (w%theta(k) - w%pwp(k))*w%depth(k)*w%perrzd(k)
          if (wavail < 0.0) wavail = 0.0
          if (uptake > wavail) then
            ! Not enough water in the layer for its share.
            tuse = tuse + wavail
            w%theta(k) = w%pwp(k)*w%perrzd(k) + w%theta(k)*(1.0 - w%perrzd(k))
            tflag = .true.
          else
            tuse = tuse + uptake
            w%theta(k) = w%theta(k) - uptake/w%depth(k)
          end if
          perdep(k) = (w%fieldc(k) - w%theta(k))*w%depth(k)/w%pawft(k)
          if (perdep(k) > 1.0) perdep(k) = 1.0
          w%dpln = w%dpln + (w%fieldc(k) - w%theta(k))*w%depth(k)*w%perrzd(k)
          twait = twait + w%rdf(k)*(1.0 - perdep(k))
        end do

        if (.not. tflag) return
        tweigh = twait
        trans = t - tuse
        if (abs(trans) < 0.001) return
        w%dpln = 0.0
        twait = 0.0
        itries = itries + 1
        tflag = .false.
        if (itries > 20) then
          if (w%status == 0) w%status = CSK_ERR_TRANS_CONV
          return
        end if
      end do
    end subroutine transpiration

  end subroutine water_balance

end module csk_balance
