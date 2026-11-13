!=======================================================================
!  csk_physics - the CropSim process routines, one per process.
!
!  Each routine is the original v8.0 subroutine of the same purpose,
!  with its module variables replaced by components of the run's
!  csk_work_t (w). Arithmetic is kept in the original order so that,
!  with no fixes switched on, results match the original bit for bit.
!  Original subroutine names and line numbers are given for each.
!=======================================================================
module csk_physics
  use csk_types
  implicit none
  private

  public :: dayofyr, calday
  public :: prepare_weather, crop_coefficient
  public :: snowmelt, effective_precip, evaporation, infiltrate
  public :: root_zone, mgmt_depletion, soil_temperature, crop_yield

  integer, parameter :: IDAYS(12) = [0,31,59,90,120,151,181,212,243,273,304,334]

  ! FAO-style four-segment crop coefficient curves (CROPCO, crops 9 and
  ! 11-22): FS1, FS2, FS3 (fractions of season), KCINI, KCMID, KCEND.
  real, parameter :: FAO(6,9:22) = reshape([ &
      0.192, 0.462, 0.808, 0.150, 1.000, 0.300, &   !  9 sunflower
      0.,    0.,    0.,    0.,    0.,    0.,    &   ! 10 alfalfa (own method)
      0.036, 0.109, 0.927, 0.243, 0.750, 0.669, &   ! 11 irrigated hay
      0.036, 0.109, 0.927, 0.243, 0.750, 0.669, &   ! 12 irrigated pasture
      0.036, 0.109, 0.927, 0.243, 0.587, 0.587, &   ! 13 native pasture
      0.036, 0.073, 1.000, 0.688, 0.746, 0.746, &   ! 14 urban turf
      0.00,  0.10,  1.00,  0.150, 0.150, 0.150, &   ! 15 summer fallow
      0.105, 0.158, 0.842, 0.364, 1.082, 0.798, &   ! 16 riparian woodland
      0.105, 0.158, 0.842, 0.547, 0.873, 0.691, &   ! 17 non-riparian woodland
      0.071, 0.286, 0.857, 0.243, 1.011, 0.282, &   ! 18 cattail wetland
      0.036, 0.109, 1.000, 0.729, 1.011, 0.606, &   ! 19 reed/swamp wetland
      0.010, 0.100, 1.000, 0.800, 0.800, 0.800, &   ! 20 shallow open water
      0.010, 0.100, 1.000, 0.526, 0.526, 1.012, &   ! 21 deep open water
      0.036, 0.109, 0.927, 0.243, 0.587, 0.587  &   ! 22 farmstead
      ], [6, 14])

contains

  !---------------------------------------------------------------------
  !  Calendar (DAYOFYR, CALDAY). No leap years, as in the original.
  !---------------------------------------------------------------------
  pure subroutine dayofyr(jday, imon, iday)
    integer, intent(out) :: jday
    integer, intent(in)  :: imon, iday
    jday = iday + IDAYS(imon)
  end subroutine dayofyr

  pure subroutine calday(jday, imon, iday)
    integer, intent(in)  :: jday
    integer, intent(out) :: imon, iday
    integer :: j
    do j = 1, 12
      if (jday <= IDAYS(j)) exit
    end do
    imon = j - 1
    iday = jday - IDAYS(imon)
    if (jday > 366) then
      imon = 13
      iday = 0
    end if
  end subroutine calday

  !---------------------------------------------------------------------
  !  Weather preparation, growing degree days, development dates, daily
  !  crop coefficients and solar radiation (READWEAT, original 3556-3733).
  !---------------------------------------------------------------------
  subroutine prepare_weather(w)
    type(csk_work_t), intent(inout) :: w
    real :: tmaxa, tmina, etra, precipa, t1, t2, gdd, day, rsoa, rsob, rso, deltat
    integer :: i, jday, n

    call dayofyr(w%jdystr, w%imstr, w%idstr)
    w%ndays = 0

    ! Defaults for the first days (used to replace out-of-range values).
    tmaxa = 55
    tmina = 30
    etra = 0.10
    precipa = 0.0

    w%etr = 0.
    w%precip = 0.
    w%tmax = 0.
    w%tmin = 0.
    w%gdds = 0.
    w%solar = 0.

    i = w%jdystr
    do
      n = i - w%jdystr + 1
      if (n > w%wx_ndays .or. i > NDAY) exit
      w%tmax(i) = w%wx_tmax(n)
      w%tmin(i) = w%wx_tmin(n)
      w%precip(i) = w%wx_precip(n)
      w%etr(i) = w%wx_etr(n)

      w%ndays = w%ndays + 1
      if ((w%tmax(i) < -50.) .or. (w%tmax(i) > 125.)) w%tmax(i) = tmaxa
      if ((w%tmin(i) < -50.) .or. (w%tmin(i) > 100.)) w%tmin(i) = tmina
      if ((w%precip(i) < 0.) .or. (w%precip(i) > 10.)) w%precip(i) = precipa
      if ((w%etr(i) < 0.) .or. (w%etr(i) > 0.6)) w%etr(i) = etra

      if ((i - w%jdystr) >= 3) then
        tmaxa = (w%tmax(i) + w%tmax(i-1) + w%tmax(i-2)) / 3.0
        tmina = (w%tmin(i) + w%tmin(i-1) + w%tmin(i-2)) / 3.0
        precipa = (w%precip(i) + w%precip(i-1) + w%precip(i-2)) / 3.0
        etra = (w%etr(i) + w%etr(i-1) + w%etr(i-2)) / 3.0
      end if

      ! Reduce reference ET for field conditions.
      w%etr(i) = w%etrfact * w%etr(i)
      i = i + 1
    end do
    w%jdystp = w%jdystr + w%ndays - 1

    ! Growing degree days and first killing freeze (after day 200).
    w%jdyfrz = 0
    w%gdds = 0.0
    gdd = w%gdd
    do i = w%jdyplt, w%jdyend
      t1 = w%tmax(i)
      if (t1 >= w%tceil(w%crop)) t1 = w%tceil(w%crop)
      if (t1 < w%tbase(w%crop)) t1 = w%tbase(w%crop)
      t2 = w%tmin(i)
      if (t2 <= w%tbase(w%crop)) t2 = w%tbase(w%crop)
      if (t2 > w%tceil(w%crop)) t2 = w%tceil(w%crop)
      gdd = (t1 + t2) / 2. - w%tbase(w%crop)
      if (gdd < 0.) gdd = 0.
      w%gdds(i) = w%gdds(i-1) + gdd
      if (w%tmin(i) < 26. .and. i >= 200) then
        if (w%jdyfrz < 1) w%jdyfrz = i
      end if
    end do
    if (w%jdyfrz < 1) w%jdyfrz = w%jdyend
    if (w%jdystr > w%jdybg) w%jdybg = w%jdystr

    ! Development dates from GDD. Crops 10 and up only need cover and
    ! maturity (maturity = freeze date).
    w%jdyefc = first_day(w%gddefc)
    if (w%crop >= 10) then
      w%jdymat = w%jdyfrz
    else
      w%jdymat = first_day(w%gddmat)
      if (w%jdymat > w%jdyfrz) w%jdymat = w%jdyfrz
      w%jdyflo = first_day(w%gddflo)
      w%jdyripe = first_day(w%gddripe)
      w%jdyveg = first_day(w%gddveg)
    end if

    ! Daily crop coefficients. The original computed each day's KC
    ! before setting that day's GDD, so KC used the previous day's GDD
    ! (and on the first day, the last daily GDD increment above).
    w%gdd = gdd
    do jday = w%jdystr, w%jdystp
      if (fix_on(w, FIX_KC_GDD_LAG)) w%gdd = w%gdds(jday)
      call crop_coefficient(w, jday)
      w%gdd = w%gdds(jday)
      w%cropkc(jday) = w%kc
    end do

    ! Solar radiation estimate and mean annual air temperature, used
    ! only by the soil temperature routine.
    w%tanual = 0.0
    do i = 1, w%jdystp
      day = i
      w%tavg = 0.5 * (w%tmax(i) + w%tmin(i))
      rsoa = 753.6 - 6.53 * w%lat + 0.0057*w%elev
      rsob = -7.1 + 6.4 * w%lat + 0.0030 * w%elev
      rso = rsoa + rsob * cos(2*3.14159*(day-170)/365)
      deltat = w%tmax(i) - w%tmin(i)
      if (w%precip(i) > 0.2) then
        w%solar(i) = rso*exp(0.0146*w%tavg) &
                     /(1.+exp(- deltat/36.301))**3.6795
      else
        w%solar(i) = rso*exp(7.82E-4*w%tavg) &
                     /(1.+exp(- deltat/9.4619))**3.6142
      end if
      w%tanual = w%tanual + w%tavg
    end do
    w%tanual = w%tanual / w%ndays

  contains

    ! First day from planting on which cumulative GDD reaches TARGET
    ! (JDYEND+1 if never), as the original DO/GOTO searches gave.
    integer function first_day(target)
      real, intent(in) :: target
      integer :: k
      do k = w%jdyplt, w%jdyend
        if (w%gdds(k) >= target) exit
      end do
      first_day = k
    end function first_day

  end subroutine prepare_weather

  !---------------------------------------------------------------------
  !  Crop coefficient for day JDAY (CROPCO, original 2995-3552).
  !  Uses w%gdd as the GDD for the day. KC keeps its previous value on
  !  days none of the rules set it, as in the original.
  !---------------------------------------------------------------------
  subroutine crop_coefficient(w, jday)
    type(csk_work_t), intent(inout) :: w
    integer, intent(in) :: jday
    integer :: crop, ipct
    real :: fgs

    crop = w%crop

    ! Crops 1-7: Wright (1982) tables, by percent time to effective
    ! cover and percent of 100 days after it.
    if (crop <= 7) then
      if (jday <= w%jdyefc) then
        w%iefc = 1
        w%pct = real(jday - w%jdyplt) / real(w%jdyefc - w%jdyplt)
      else
        w%iefc = 2
        w%pct = real(jday - w%jdyefc) / 100.
      end if

      if ((w%pct >= 0.0) .and. (w%pct <= 1.0)) then
        ipct = w%pct / 0.10
        if ((ipct > 0) .and. (ipct < 10)) w%kc = w%cc(crop,w%iefc,ipct) + &
            10*mod(w%pct,0.1)*(w%cc(crop,w%iefc,ipct+1) - w%cc(crop,w%iefc,ipct))
        if ((ipct == 0) .and. (w%iefc == 1)) w%kc = w%kcl(crop) + &
            10*mod(w%pct,0.1)*(w%cc(crop,w%iefc,1) - w%kcl(crop))
        if ((w%iefc == 2) .and. (w%pct < 0.1)) w%kc = w%cc(crop,w%iefc,1) + &
            10*mod(w%pct,0.1)*(w%cc(crop,w%iefc,2) - w%cc(crop,w%iefc,1))
        if (ipct == 10) w%kc = w%cc(crop,w%iefc,10)
      else
        w%kc = w%kcl(crop)
      end if

      ! JFPLT is the fall planting date of winter wheat.
      if (crop == 7) then
        if ((w%jfplt > 0) .and. (jday >= w%jfplt)) w%kc = 0.25
      end if

      if (w%kc > w%kcu(crop)) w%kc = w%kcu(crop)
      if (w%kc < w%kcl(crop)) w%kc = w%kcl(crop)
    end if

    ! Corn: Watts (1982) and Stegman (1988), by fraction of GDD to maturity.
    if (crop == 8) then
      w%kc = w%kcu(crop)
      if (w%gdd < 0.42*w%gddmat) w%kc = 0.15 + .85*(w%gdd - 0.12*w%gddmat)/(0.3*w%gddmat)
      if (w%gdd <= 0.12*w%gddmat) w%kc = 0.15
      if (w%gdd > 0.78*w%gddmat) w%kc = 1.0 - 0.7*(w%gdd - 0.78*w%gddmat)/(0.22*w%gddmat)
      if (w%gdd > w%gddmat) w%kc = 0.15
      if (w%kc > w%kcu(crop)) w%kc = w%kcu(crop)
      if (w%kc < 0.15) w%kc = 0.15
    end if

    if (crop == 9) then
      fgs = w%gdd / w%gddmat
      call fao_curve(crop, fgs)
    end if

    if (crop == 10) call alfalfa(jday)

    ! Irrigated hay: the season restarts at the cutting.
    if (crop == 11) then
      if (jday == w%jdycut(1)) w%gddcut = w%gdd
      if (jday < w%jdycut(1)) then
        fgs = w%gdd / w%gddmat
      else
        fgs = (w%gdd - w%gddcut) / (w%gddmat - w%gddcut)
      end if
      call fao_curve(crop, fgs)
    end if

    if (crop >= 12) then
      fgs = w%gdd / w%gddmat
      call fao_curve(crop, fgs)
    end if

    ! Bounds.
    if (jday > w%jdyfrz) w%kc = w%kcl(crop)
    if (w%kc < w%kcl(crop)) w%kc = w%kcl(crop)
    if (w%kc > w%kcu(crop)) w%kc = w%kcu(crop)

  contains

    subroutine fao_curve(c, f)
      integer, intent(in) :: c
      real, intent(in) :: f
      real :: fs1, fs2, fs3, kcini, kcmid, kcend
      fs1 = FAO(1,c); fs2 = FAO(2,c); fs3 = FAO(3,c)
      kcini = FAO(4,c); kcmid = FAO(5,c); kcend = FAO(6,c)
      if (f <= fs1) w%kc = kcini
      if ((f > fs1) .and. (f < fs2)) w%kc = kcini + (kcmid - kcini)*(f - fs1)/(fs2 - fs1)
      if ((f >= fs2) .and. (f <= fs3)) w%kc = kcmid
      if ((f > fs3) .and. (f <= 1.0)) w%kc = kcmid - (kcmid - kcend)*(f - fs3)/(1.0 - fs3)
      if (f > 1.0) w%kc = kcini
    end subroutine fao_curve

    ! Alfalfa: Wright (1982), by cutting cycle. JDYPLT is green-up.
    subroutine alfalfa(jd)
      integer, intent(in) :: jd
      integer :: k
      if (jd < w%jdycut(1)) then
        w%icut = 1
        w%iefc = 1
      end if
      if ((jd >= w%jdycut(1)) .and. (jd < w%jdycut(2))) then
        w%icut = 2
        w%iefc = 2
      end if
      do k = 3, 5
        if ((jd > w%jdycut(k-1)) .and. (jd < w%jdycut(k))) then
          w%icut = k
          w%iefc = 2
        end if
      end do
      if (jd >= w%jdycut(w%ncut)) then
        w%icut = w%ncut
        w%iefc = 3
      end if

      ! Percent of time through the current growth cycle.
      if ((w%icut == 1) .and. (jd >= w%jdyplt)) &
        w%pct = real(jd - w%jdyplt) / real(w%jdycut(1) - w%jdyplt)
      if (w%icut >= 2) then
        if (w%iefc == 2) then
          w%pct = real(jd - w%jdycut(w%icut-1)) / real(w%jdycut(w%icut) - w%jdycut(w%icut-1))
        else
          ! Final regrowth after the last cutting. The original measured
          ! it from cutting 1 when there are two cuttings.
          k = w%icut
          if (k == 2 .and. .not. fix_on(w, FIX_ALFALFA_REGROWTH)) k = 1
          w%pct = real(jd - w%jdycut(k)) / real(305 - w%jdycut(k))
        end if
      end if

      if ((jd <= w%jdyplt) .or. (jd >= 305)) w%kc = w%kcl(10)

      ipct = int(w%pct/0.1)
      if ((ipct > 0) .and. (ipct < 10)) w%kc = w%cc(10,w%iefc,ipct) + &
          10*mod(w%pct,0.1)*(w%cc(10,w%iefc,ipct+1) - w%cc(10,w%iefc,ipct))
      if (ipct == 0) w%kc = w%kcl(10) + &
          10*mod(w%pct,0.1)*(w%cc(10,w%iefc,ipct+1) - w%kcl(10))
      if (ipct == 10) w%kc = w%cc(10,w%iefc,10)
    end subroutine alfalfa

  end subroutine crop_coefficient

  !---------------------------------------------------------------------
  !  Snow accumulation and melt (SNOWMELT, original 3907-4022; SWAT).
  !  Works on w%rain, the day's liquid water reaching the ground.
  !---------------------------------------------------------------------
  subroutine snowmelt(w, smtmp)
    type(csk_work_t), intent(inout) :: w
    real, intent(in) :: smtmp
    real :: smfac, xx, snomlt, snocov
    integer :: jday

    jday = w%jday
    w%snotmp = w%snotmp * (1. - w%timp) + w%tavg * w%timp

    if (w%tavg <= w%sftmp) then
      w%snoh2o = w%snoh2o + w%rain
      w%rain = 0.
    end if

    if (w%tmax(jday) > smtmp .and. w%snoh2o > 0.) then
      smfac = (w%smfmx + w%smfmn) / 2. + sin((jday - 81) / 58.09) * &
              (w%smfmx - w%smfmn) / 2.
      snomlt = smfac * (((w%snotmp + w%tmax(jday)) / 2.) - smtmp)
      if (w%snoh2o < w%snocovmx) then
        xx = w%snoh2o / w%snocovmx
        snocov = xx / (xx + exp(w%snocov1 - w%snocov2 * xx))
      else
        snocov = 1.
      end if
      snomlt = snomlt * snocov
      if (snomlt < 0.) snomlt = 0.
      if (snomlt > w%snoh2o) snomlt = w%snoh2o
      w%snoh2o = w%snoh2o - snomlt
      w%rain = w%rain + snomlt
    end if
  end subroutine snowmelt

  !---------------------------------------------------------------------
  !  Runoff and effective precipitation (EFPRECIP, original 1607-1728):
  !  SCS curve number adjusted for residue, growth stage and soil water
  !  in the top foot, with optional terrace channel storage.
  !---------------------------------------------------------------------
  subroutine effective_precip(w, fix_residue_cn)
    type(csk_work_t), intent(inout) :: w
    logical, intent(in) :: fix_residue_cn
    real :: cnumb, cnavg, cnfalo, cnpeak, cnfact, curvn1, curvn3, smax, s3
    real :: sw, sat, fc, rundep, totrdp, w1, w2, s, p, rrunof, dpond
    integer :: ilay, crop, ihy

    crop = w%crop
    ihy = w%ihygrp

    if (crop < 10) then
      if (w%restyp(w%oldcrp) == 1) then
        cnfact = (12.648 - 4.7000/sqrt(0.001123 * w%residue))/100.
      else
        cnfact = (12.456 - 6.4098/sqrt(0.001123 * w%residue))/100.
      end if
      cnfact = max(cnfact, 0.0)

      cnpeak = (2.0*w%cn(crop,ihy) - w%cnfallow(ihy)) * (1.0 - cnfact)
      cnavg = w%cn(crop,ihy) * (1.0 - cnfact)
      cnfalo = w%cnfallow(ihy) * (1.0 - cnfact)

      if (w%gdd <= w%gddveg) then
        cnumb = cnfalo
      else
        if (w%gdd <= w%gddefc) then
          cnumb = cnfalo + (cnavg - cnfalo)*(w%gdd - w%gddveg)/(w%gddefc - w%gddveg)
        else
          cnumb = cnavg + (cnpeak - cnavg)*(w%gdd - w%gddefc)/(w%gddmat - w%gddefc)
        end if
      end if
      if (w%gdd > w%gddmat) then
        if (fix_residue_cn) then
          cnumb = cnfalo
        else
          ! Original: the residue factor is applied a second time.
          cnumb = cnfalo * (1.0 - cnfact)
        end if
      end if
    else
      cnfact = 0.0
      cnumb = w%cn(crop,ihy)
    end if

    ! Antecedent moisture (top 12 inches).
    curvn1 = 4.2*cnumb/(10. - 0.058*cnumb)
    curvn3 = 23.*cnumb/(10. + 0.13*cnumb)
    smax = 25.4 * (1000./curvn1 - 10.)
    s3 = 25.4 * (1000./curvn3 - 10.)

    sw = 0.0
    sat = 0.0
    fc = 0.0
    rundep = 12.
    totrdp = 0.
    do ilay = 1, w%layers
      totrdp = totrdp + w%depth(ilay)
      if (totrdp < rundep) then
        sw = sw + (w%theta(ilay) - w%pwp(ilay))*25.4*w%depth(ilay)
        sat = sat + (w%satwc - w%pwp(ilay))*25.4*w%depth(ilay)
        fc = fc + (w%fieldc(ilay) - w%pwp(ilay))*25.4*w%depth(ilay)
      else
        sw = sw + (w%theta(ilay) - w%pwp(ilay))*25.4*(rundep - (totrdp - w%depth(ilay)))
        sat = sat + (w%satwc - w%pwp(ilay))*25.4*(rundep - (totrdp - w%depth(ilay)))
        fc = fc + (w%fieldc(ilay) - w%pwp(ilay))*25.4*(rundep - (totrdp - w%depth(ilay)))
        exit
      end if
    end do

    w2 = (log(fc/(1.0 - s3/smax) - fc) - log(sat/(1.0 - 2.54/smax) - sat)) / (sat - fc)
    w1 = log(fc/(1.0 - s3/smax) - fc) + w2 * fc
    s = max(2.54, smax * (1 - sw / (sw + exp(w1 - w2*sw))))
    w%curvno = 25400. / (s + 254.)
    s = s / 25.4

    p = w%rain
    if (0.2*s > p) then
      rrunof = 0.0
    else
      rrunof = ((p - 0.2*s)**2. / (p + 0.8*s)) / p
    end if

    ! Terrace channels hold runoff (and run-on from the hillslope).
    if (w%iterrc == 0) then
      w%eprecip = w%rain * (1.0 - rrunof)
      w%runon = 0.0
      w%runoff = w%rain - w%eprecip
    else
      w%runon = w%rain * rrunof * (w%tintrv - w%chanw)/w%chanw
      dpond = (w%rain * rrunof + w%runon)/12.
      if (dpond <= w%chand) then
        w%eprecip = w%runon + w%rain
        w%runoff = 0.0
      else
        w%eprecip = w%rain * (1.0 - rrunof) + w%chand * 12.
        w%runoff = (dpond - w%chand) * 12.
      end if
    end if

    if ((w%runoff < 0.0) .or. ((w%eprecip > w%rain) .and. (w%iterrc == 0))) then
      if (w%status == 0) w%status = CSK_ERR_RUNOFF
    end if
  end subroutine effective_precip

  !---------------------------------------------------------------------
  !  Soil evaporation, two-stage (EVAP, original 1478-1542), with the
  !  potential reduced for surface residue.
  !---------------------------------------------------------------------
  subroutine evaporation(w)
    type(csk_work_t), intent(inout) :: w
    real :: alpha, avail, avail2, resdep, redf
    integer :: jday

    jday = w%jday
    if (w%alpha1 /= 0.0) then
      alpha = w%alpha1
    else
      alpha = 0.303*(w%fieldc(1) - w%airdry(1))*w%depth(1) + 0.0547
    end if

    w%e1 = 0.0
    w%e2 = 0.0
    stages: block
      if (w%ep <= 0.0) exit stages
      if (abs(w%theta(1) - w%airdry(1)) <= 0.0001) then
        ! Stage 2 drying.
        if (w%theta(2) <= w%airdry(2)) exit stages
        w%e2 = alpha*(sqrt(real(jday) - w%time) - sqrt(real(jday-1) - w%time))
        if (w%e2 > w%ep) w%e2 = w%ep
        avail2 = (w%theta(2) - w%airdry(2))*w%depth(2)
        if (w%e2 > avail2) w%e2 = avail2
        exit stages
      end if

      if (w%residue > 0.0) then
        resdep = 1.123E-07 * w%residue / w%spgrav(w%oldcrp)
        redf = min(-0.99 - 0.236*log(resdep), 1.0)
        if (redf < 0.0) redf = 0.0
      else
        redf = 1.0
      end if
      w%ep = w%ep * redf

      ! Stage 1 drying.
      w%time = real(jday)
      avail = (w%theta(1) - w%airdry(1))*w%depth(1)
      ! Written as the original's test (AVAIL < EP goes to the transition)
      ! so a NaN AVAIL takes the same branch.
      if (.not. (avail < w%ep)) then
        w%e1 = w%ep
        exit stages
      end if

      ! Transition from stage 1 to stage 2.
      w%time = real(jday-1) + avail/w%ep
      w%e1 = avail
      w%e2 = alpha*sqrt(1.0 - avail/w%ep)
      avail2 = (w%theta(2) - w%airdry(2))*w%depth(2)
      if (w%e2 > avail2) w%e2 = avail2
      if ((w%e1 + w%e2) <= w%ep) exit stages
      w%e2 = w%ep - w%e1
      w%time = real(jday) - (w%e2/alpha)**2.0
    end block stages

    if (w%e1 < 0.0) w%e1 = 0.0
    if (w%e2 < 0.0) w%e2 = 0.0
    w%cume = w%cume + w%e1 + w%e2
  end subroutine evaporation

  !---------------------------------------------------------------------
  !  Infiltration (NTHET, original 1561-1602): fill layers to field
  !  capacity from the top; spread any remainder evenly over the profile.
  !---------------------------------------------------------------------
  subroutine infiltrate(w)
    type(csk_work_t), intent(inout) :: w
    real :: dinfl, amt, thetup
    integer :: i

    if (w%dinf == 0.) return
    w%infday = w%infday + w%dinf
    do i = 1, w%layers
      if (w%dinf == 0.) return
      amt = (w%fieldc(i) - w%theta(i))*w%depth(i)
      if (amt < 0.0) amt = 0.0
      if (amt >= w%dinf) then
        dinfl = w%dinf
        w%dinf = 0.
      else
        dinfl = amt
        w%dinf = w%dinf - amt
      end if
      thetup = dinfl/w%depth(i)
      w%theta(i) = w%theta(i) + thetup
    end do

    thetup = w%dinf/w%totdep
    do i = 1, w%layers
      w%theta(i) = w%theta(i) + thetup
    end do
    w%dinf = 0.
  end subroutine infiltrate

  !---------------------------------------------------------------------
  !  Root depth, root fraction of each layer, available water in the
  !  management zone and the root zone, and the root distribution
  !  (ROOTZN, original 1733-1803).
  !---------------------------------------------------------------------
  subroutine root_zone(w)
    type(csk_work_t), intent(inout) :: w
    real :: remain, topdep, botdep, fdepth, zu, zl
    integer :: i

    if (fix_on(w, FIX_PERENNIAL_ROOTS) .and. w%crop >= 10 .and. w%crop <= 13) then
      ! Established perennial forage: full root depth all year.
      w%rzd = w%rzmax
    else
      ! Original: roots grow from RZMIN at GDDROOT to RZMAX at GDDFLO.
      ! Crops 10 and up never read GDDFLO (it is 0), so for them the
      ! depth is RZMAX only if the balance starts on a day with no GDD
      ! yet; otherwise it falls toward RZMIN as GDD accrue.
      w%rzd = (w%rzmax - w%rzmin)*(w%gdd - w%gddroot)/(w%gddflo - w%gddroot) + w%rzmin
      if (w%rzd > w%rzmax) w%rzd = w%rzmax
      if (w%rzd < w%rzmin) w%rzd = w%rzmin
    end if

    ! Fraction of each layer filled with roots. Layers below the roots
    ! keep their previous value (roots only deepen).
    remain = w%rzd
    do i = 1, w%layers
      remain = remain - w%depth(i)
      if (remain >= 0.) w%perrzd(i) = 1.
      if (remain < 0.0 .and. remain > -w%depth(i)) &
        w%perrzd(i) = (w%depth(i) + remain)/w%depth(i)
      if (remain < 0.) remain = 0.
    end do

    ! Available water in the irrigation management zone (to RZMGMT)
    ! and plant available water in the whole root zone.
    w%paw = 0.0
    w%awater = 0.0
    topdep = 0.0
    botdep = 0.0
    do i = 1, w%layers
      topdep = botdep
      botdep = botdep + w%depth(i)
      if (botdep <= w%rzmgmt) w%awater = w%awater + w%avmft(i)*w%perrzd(i)
      if ((w%rzmgmt > topdep) .and. (w%rzmgmt < botdep)) then
        if (w%rzd >= w%rzmgmt) then
          fdepth = (w%rzmgmt - topdep)/w%depth(i)
        else
          fdepth = w%perrzd(i)
        end if
        w%awater = w%awater + w%avmft(i)*fdepth
      end if
      w%paw = w%paw + w%pawft(i)*w%perrzd(i)
    end do

    ! Root distribution function by layer.
    zu = 0.0
    zl = w%depth(1)/w%rzd
    if (zl > 1.0) zl = 1.0
    w%rdf(1) = rdist(zl, zu)
    do i = 2, NLAY
      zu = zl
      zl = zl + w%depth(i)/w%rzd
      if (zl > 1.0) zl = 1.0
      w%rdf(i) = rdist(zl, zu)
    end do

  contains

    pure real function rdist(z2, z1)
      real, intent(in) :: z2, z1
      rdist = 2.0633*(z2 - z1) - 1.622*(z2*z2 - z1*z1) + 0.5587*(z2**3.0 - z1**3.0)
    end function rdist

  end subroutine root_zone

  !---------------------------------------------------------------------
  !  Depletion below field capacity in the irrigation management zone
  !  (the AWDPLN loops in DEPLT, original 1980-2005 and 2482-2507).
  !---------------------------------------------------------------------
  real function mgmt_depletion(w) result(awdpln)
    type(csk_work_t), intent(in) :: w
    real :: topdep, botdep, fdepth, depl
    integer :: i

    awdpln = 0.0
    topdep = 0.0
    botdep = 0.0
    do i = 1, w%layers
      topdep = botdep
      botdep = botdep + w%depth(i)
      if (botdep <= w%rzmgmt) then
        depl = (w%fieldc(i) - w%theta(i))*w%depth(i)*w%perrzd(i)
        awdpln = awdpln + depl
        if (w%rzmgmt == botdep) exit
      end if
      if ((w%rzmgmt > topdep) .and. (w%rzmgmt < botdep)) then
        if (w%rzd >= w%rzmgmt) then
          fdepth = (w%rzmgmt - topdep)/w%depth(i)
        else
          fdepth = w%perrzd(i)
        end if
        depl = (w%fieldc(i) - w%theta(i))*w%depth(i)*fdepth
        awdpln = awdpln + depl
        exit
      end if
    end do
  end function mgmt_depletion

  !---------------------------------------------------------------------
  !  Soil temperature by layer (SOILTEMP, original 3736-3903; SWAT
  !  equations 2.3.3-2.3.12). Does not feed back to the water balance.
  !---------------------------------------------------------------------
  subroutine soil_temperature(w)
    type(csk_work_t), intent(inout) :: w
    real :: f, dp, ww, b, wc, dd, xx, sto, tlag, df, zd, bcv, tcov
    real :: agbio, cv, cov, albsoil, albedo, tbare, surftemp
    integer :: k, jday, crop

    jday = w%jday
    crop = w%crop
    tlag = 0.8

    ! Damping depth.
    f = w%bulkd / (w%bulkd + 686. * exp(-5.63 * w%bulkd))
    dp = 39.4 + 98.4 * f
    ww = .356 - .144 * w%bulkd
    wc = w%totwat / (ww * w%totdep)
    b = log(19.7 / dp)
    f = exp(b * ((1. - wc) / (1. + wc))**2.)
    dd = f * dp

    ! Cover from above-ground biomass and residue.
    if ((jday >= w%jdyplt) .and. (jday < w%jdymat)) then
      if (w%etmax <= 0.) then
        agbio = 0.0
      else
        agbio = w%ymax * w%ydens(crop) * w%resrat(crop)
        agbio = agbio*(w%kc - w%kcl(crop))/(w%kcu(crop) - w%kcl(crop))
      end if
    else
      agbio = 0.0
    end if

    cv = w%residue + agbio
    bcv = 1.123*cv / (1.123*cv + exp(7.563 - 1.4566E-4 * cv))
    xx = 0.
    if (w%snoh2o >= 0.) then
      if (w%snoh2o <= 4.724) then
        xx = w%snoh2o / (w%snoh2o + exp(6.055 - 7.625 * w%snoh2o))
      else
        xx = 1.0
      end if
      bcv = max(xx, bcv)
    end if

    ! Soil surface temperature.
    cov = exp(-5.0E-5*1.123*cv)
    albsoil = 0.30 - 0.10*(w%soil/100 - 4.)/5.
    if (w%snoh2o > 0.02) then
      albedo = 0.8
    else
      albedo = 0.23*(1.0 - cov) + cov * albsoil
    end if
    sto = (4.1855E-02 * w%solar(jday) * (1. - albedo) - 14.) / 20.
    w%tavg = (w%tmax(jday) + w%tmin(jday))/2.0
    tbare = w%tavg + 0.5 * (w%tmax(jday) - w%tmin(jday)) * sto
    tcov = bcv * w%soilt(2) + (1. - bcv) * tbare
    if (w%residue > 0.01 .or. w%snoh2o > 0.01) then
      surftemp = min(tbare, tcov)
    else
      surftemp = tbare
    end if

    do k = 1, w%layers
      zd = w%center(k)
      zd = zd / dd
      df = zd / (zd + exp(-.8669 - 2.0775 * zd))
      w%soilt(k) = tlag * w%soilt(k) + (1. - tlag) * &
                   (df * (w%tanual - surftemp) + surftemp)
    end do
  end subroutine soil_temperature

  !---------------------------------------------------------------------
  !  Yield (YIELDS, original 1809-1854), from transpiration deficits or
  !  ET, with an optional long-term trend.
  !---------------------------------------------------------------------
  subroutine crop_yield(w)
    type(csk_work_t), intent(inout) :: w
    real, parameter :: AC(11) = [-22.963, -13.156, -18.249, 1.000, 1.000, -11.008, &
                                 -22.963, -24.578, -17.165, -12.562, -20.334]
    real, parameter :: BC(11) = [0.01199, 0.00708, 0.00963, 0.00000, 0.00000, 0.00601, &
                                 0.01199, 0.01280, 0.00909, 0.00678, 0.01067]
    real :: year, yadj, tr, ta
    integer :: crop

    crop = w%crop
    year = w%iyear
    ! The original indexed AC/BC (11 crops) with crops up to 22, reading
    ! past the arrays. The kernel uses no trend for crops 12-22.
    if (w%ytrend == 1 .and. crop <= 11) then
      yadj = max(AC(crop) + BC(crop) * year, 0.0)
    else
      yadj = 1.0
    end if

    if (crop < 12) then
      if (w%iyield == 1) then
        tr = w%tdef(1) + w%tdef(2) + w%tdef(3) + w%tdef(4) + w%tdef(5)
        ta = w%tps(1) + w%tps(2) + w%tps(3) + w%tps(4) + w%tps(5)
        w%yield = yadj*w%ymax*(1.0 - w%ycoeff*tr/ta)
      else
        w%yield = yadj*w%ymax*((1.0 - w%ycoeff) + w%ycoeff*w%etyld/w%etmax)
      end if
    else
      w%yield = w%ymax
    end if
    if (w%yield < 0.0) w%yield = 0.0

    w%bvalue = yadj*w%ymax*w%ycoeff/w%etmax
    w%yldratio = w%yield / (yadj*w%ymax)
  end subroutine crop_yield

end module csk_physics
