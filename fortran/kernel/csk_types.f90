!=======================================================================
!  csk_types - data types for the CropSim compute kernel.
!
!  The kernel is a re-write of the CropSim v8.0 water balance
!  (fortran/original/CROPSIM_V8.0.F90) as a pure compute library:
!
!    * no files are read or written,
!    * no module (global) variables: every value a run needs lives in a
!      csk_work_t that is local to the run, so runs are re-entrant and
!      can be made from many threads at once,
!    * inputs and outputs are BIND(C) structures (see cropsim_kernel.h).
!
!  With options%fixes = 0 the kernel reproduces the original program.
!  Each known bug has its own bit in options%fixes (FIX_* below), so the
!  original behaviour can always be run next to the corrected one.
!=======================================================================
module csk_types
  use, intrinsic :: iso_c_binding, only: c_int, c_float
  implicit none
  private

  integer, parameter, public :: NLAY = 10        ! soil layers
  integer, parameter, public :: NCROP = 22       ! crop / land use codes
  integer, parameter, public :: NDAY = 366       ! days in a year array
  integer, parameter, public :: NFCST = 400      ! weather arrays, padded for forecasts
  integer, parameter, public :: NEVENT = 50      ! known irrigation events
  integer, parameter, public :: NTILL = 20       ! tillage operations

  integer(c_int), parameter, public :: CSK_API_VERSION = 1

  ! ---- Status codes (1-4 are the original program's STOP checks) ----
  integer(c_int), parameter, public :: CSK_OK             = 0
  integer(c_int), parameter, public :: CSK_ERR_RUNOFF     = 1
  integer(c_int), parameter, public :: CSK_ERR_EFF_PRECIP = 2
  integer(c_int), parameter, public :: CSK_ERR_TRANS_CONV = 3
  integer(c_int), parameter, public :: CSK_ERR_NEG_RUNOFF = 4
  integer(c_int), parameter, public :: CSK_ERR_BAD_INPUT  = 11

  ! ---- Bug-fix switches (bits of options%fixes) ----
  ! Bits are added one per fix; see docs/kernel/fixes.md.
  ! Crop coefficient uses the day's GDD, not the previous day's
  ! (original READWEAT 3693-3697).
  integer, parameter, public :: FIX_KC_GDD_LAG = 1
  ! Snow melts above params%smtmp (default 32 F) instead of an
  ! unset SMTMP of 0 F (original SNOWMELT 3994-3999).
  integer, parameter, public :: FIX_SNOWMELT_BASE = 2
  ! Irrigation count and first irrigation date count real irrigations
  ! (original DEPLT 2123, IRRIGA 2869-2925).
  integer, parameter, public :: FIX_IRRIGATION_COUNT = 4
  ! Rotation deliveries (IRRSCH 3) at most every JDFREQ days
  ! (original DEPLT 2111, JDFREQ read but never used).
  integer, parameter, public :: FIX_ROTATION_FREQUENCY = 8
  ! Alfalfa and hay use the current cutting cycle as the growth stage
  ! in the water balance (original DEPLT 1880, 1953; ICUT stuck at 1).
  integer, parameter, public :: FIX_FORAGE_CUTTING_STAGE = 16
  ! Alfalfa with two cuttings measures its final regrowth from cutting 2
  ! (original CROPCO 3137).
  integer, parameter, public :: FIX_ALFALFA_REGROWTH = 32
  ! Reported transpiration equals the water taken from the soil
  ! (original DEPLT 2267-2310).
  integer, parameter, public :: FIX_TRANSPIRATION_LIMIT = 64
  ! Wetland, riparian and open-water ET is taken from the soil water,
  ! with any shortfall reported as supply (original DEPLT 2347-2357).
  integer, parameter, public :: FIX_WETLAND_BALANCE = 128
  ! Water held back from drainage is spread over exactly the layers
  ! that receive it (original DEPLT 2386-2432).
  integer, parameter, public :: FIX_DRAINAGE_SPREAD = 256
  ! Known-date irrigation runs (IRRTYP 2) keep runoff and snow out of
  ! effective rain (original DEPLT 2032).
  integer, parameter, public :: FIX_KNOWN_DATE_RAIN = 512
  ! After maturity the residue factor is applied to the curve number
  ! once, not twice (original EFPRECIP 1641).
  integer, parameter, public :: FIX_RESIDUE_CN = 1024

  ! ------------------------------------------------------------------
  !  Parameters (BLOCK.DAT and TILLAGE.DAT contents).
  ! ------------------------------------------------------------------
  type, bind(c), public :: csk_params_t
    real(c_float)  :: etrfact
    integer(c_int) :: nfday, ytrend
    real(c_float)  :: depth(NLAY)
    real(c_float)  :: ydens(NCROP), resrat(NCROP), spgrav(NCROP)
    integer(c_int) :: fragil(NCROP), restyp(NCROP)
    real(c_float)  :: cc(NCROP,3,10)
    real(c_float)  :: kcl(NCROP), kcu(NCROP), tbase(NCROP), tceil(NCROP)
    real(c_float)  :: sftmp, smfmx, smfmn, snocovmx, snocov1, snocov2, timp
    real(c_float)  :: cnfallow(4), cn(NCROP,4)
    real(c_float)  :: tilfac(80,2)
    ! Snow melt base temperature (F). The original never set it, so it
    ! was 0 F; it is used only with FIX_SNOWMELT_BASE.
    real(c_float)  :: smtmp
  end type csk_params_t

  ! ------------------------------------------------------------------
  !  SIM file contents. Same layout as CS_SIM_T in cropsim_api.f90.
  ! ------------------------------------------------------------------
  type, bind(c), public :: csk_sim_t
    integer(c_int) :: crop, layers
    integer(c_int) :: implt, idplt, imbg, idbg, imend, idend
    real(c_float)  :: gddveg, gddflo, gddripe, gyform, gddefc, gddmat
    integer(c_int) :: ncut
    integer(c_int) :: jdycut(5)
    real(c_float)  :: rzmin, rzmax, tbreak, gddroot, rzmgmt
    integer(c_int) :: iyield
    real(c_float)  :: ymax, ycoeff
    integer(c_int) :: iterrc
    real(c_float)  :: chand, chanw, tintrv
    integer(c_int) :: ntills, itflag
    integer(c_int) :: itiltm(NTILL), tilday(NTILL), tilcod(NTILL)
    integer(c_int) :: irrtyp
    real(c_float)  :: pad(5), rainal(5), syscap, iper(5)
    real(c_float)  :: apmin(5), apmax(5), smalli(5)
    real(c_float)  :: gstart, gstop
    integer(c_int) :: irrsch, jfirst, jstopi, jgoi, jdfreq
    real(c_float)  :: ddepth
    real(c_float)  :: eapp(5), ereuse(5), prunof(5)
    real(c_float)  :: alpha1, airdry(2), fieldc(NLAY), pwp(NLAY), bulkd
    integer(c_int) :: kirr
    ! fdirrig(:,k) = day of year, gross depth (in), fraction infiltrated
    real(c_float)  :: fdirrig(3,NEVENT)
  end type csk_sim_t

  type, bind(c), public :: csk_soil_t
    integer(c_int) :: soil
    real(c_float)  :: bulkd, orgm, fieldc(NLAY), pwp(NLAY), airdry(2)
    real(c_float)  :: drncoe, drnday
  end type csk_soil_t

  type, bind(c), public :: csk_weather_t
    integer(c_int) :: year, imstr, idstr, ndays
    real(c_float)  :: lat, long, elev
    real(c_float)  :: tmax(NDAY), tmin(NDAY), precip(NDAY)
    real(c_float)  :: epan(NDAY), etr(NDAY)
  end type csk_weather_t

  type, bind(c), public :: csk_state_t
    real(c_float)  :: theta(NLAY)
    integer(c_int) :: oldcrp, livecrop
    real(c_float)  :: oldres, snotmp, snoh2o, soilt(NLAY)
  end type csk_state_t

  type, bind(c), public :: csk_options_t
    integer(c_int) :: fixes          ! FIX_* bits
    integer(c_int) :: livecond       ! 1: original LIVECOND rule applies
    integer(c_int) :: legacy_round   ! 1: round state like INITIAL.DAT
    integer(c_int) :: reserved
  end type csk_options_t

  ! ------------------------------------------------------------------
  !  Results. The first block matches CS_RESULT_T; new values follow.
  ! ------------------------------------------------------------------
  type, bind(c), public :: csk_result_t
    integer(c_int) :: status
    integer(c_int) :: crop_yr, crop_mon
    integer(c_int) :: imbg, imend
    integer(c_int) :: jdyplt, jfirst, jdyefc, jdymat, jdyfrz, irigno
    integer(c_int) :: itflag
    real(c_float)  :: yield, yldratio, bvalue, etmax, etyld
    real(c_float)  :: ets, etrs, es, ts
    real(c_float)  :: sgrirr, snirr, precips, eprecips, drains
    real(c_float)  :: dplbg, totrof
    real(c_float)  :: etrmon(12), emon(12), tmon(12), etmon(12)
    real(c_float)  :: ermon(12), ramon(12), rofmon(12), ronmon(12)
    real(c_float)  :: irnmon(12), irgmon(12), infmon(12), dramon(12)
    real(c_float)  :: dplmon(12)
    integer(c_int) :: numirr(12)
    real(c_float)  :: etrwk(53), etwk(53), erwk(53), rawk(53)
    real(c_float)  :: irnwk(53), irgwk(53)
    ! ---- added by the kernel ----
    integer(c_int) :: jdybg, jdyend      ! days simulated
    ! Water supplied to wetlands and open water to hold them at field
    ! capacity (only nonzero with FIX_WETLAND_BALANCE), inches.
    real(c_float)  :: wetsups, wsmon(12)
    ! Water balance error for the year, inches: storage change minus
    ! (inflows - outflows). Zero when the balance closes.
    real(c_float)  :: balerr
    ! Daily values, index = day of year (0 outside jdybg..jdyend).
    real(c_float)  :: d_gdd(NDAY), d_kc(NDAY), d_rzd(NDAY), d_etr(NDAY)
    real(c_float)  :: d_precip(NDAY), d_eprecip(NDAY), d_runoff(NDAY)
    real(c_float)  :: d_runon(NDAY), d_grirr(NDAY), d_nirr(NDAY)
    real(c_float)  :: d_irrinf(NDAY), d_e(NDAY), d_t(NDAY), d_et(NDAY)
    real(c_float)  :: d_drain(NDAY), d_wetsup(NDAY), d_snow(NDAY)
    real(c_float)  :: d_soilw(NDAY), d_dpln(NDAY), d_awdpln(NDAY)
    real(c_float)  :: d_balerr(NDAY)
  end type csk_result_t

  ! ------------------------------------------------------------------
  !  Working values for one run. Names follow the original variables.
  !  A csk_work_t is created fresh for every run (see csk_kernel), so
  !  nothing carries over from one run to the next.
  ! ------------------------------------------------------------------
  type, public :: csk_work_t
    integer :: fixes = 0
    integer :: status = 0
    ! parameters
    real    :: etrfact = 0.
    integer :: nfday = 0, ytrend = 0
    real    :: depth(NLAY) = 0.
    real    :: ydens(NCROP) = 0., resrat(NCROP) = 0., spgrav(NCROP) = 0.
    integer :: fragil(NCROP) = 0, restyp(NCROP) = 0
    real    :: cc(NCROP,3,10) = 0.
    real    :: kcl(NCROP) = 0., kcu(NCROP) = 0., tbase(NCROP) = 0., tceil(NCROP) = 0.
    real    :: sftmp = 0., smfmx = 0., smfmn = 0., snocovmx = 0., snocov1 = 0.
    real    :: snocov2 = 0., timp = 0., smtmp = 0.
    real    :: cnfallow(4) = 0., cn(NCROP,4) = 0.
    real    :: tilfac(80,2) = 0.
    ! SIM
    integer :: crop = 0, layers = 0
    integer :: implt = 0, idplt = 0, imbg = 0, idbg = 0, imend = 0, idend = 0
    real    :: gddveg = 0., gddflo = 0., gddripe = 0., gyform = 0., gddefc = 0., gddmat = 0.
    integer :: ncut = 0, jdycut(5) = 0
    real    :: rzmin = 0., rzmax = 0., tbreak = 0., gddroot = 0., rzmgmt = 0.
    integer :: iyield = 0
    real    :: ymax = 0., ycoeff = 0.
    integer :: iterrc = 0
    real    :: chand = 0., chanw = 0., tintrv = 0.
    integer :: ntills = 0, itflag = 0
    integer :: itiltm(NTILL) = 0, tilday(NTILL) = 0, tilcod(NTILL) = 0
    integer :: irrtyp = 1
    real    :: pad(5) = 0., rainal(5) = 0., syscap = 0., iper(5) = 0.
    real    :: apmin(5) = 0., apmax(5) = 0., smalli(5) = 0., gstart = 0., gstop = 0.
    integer :: irrsch = 1, jfirst = 0, jstopi = 0, jgoi = 0, jdfreq = 0
    real    :: ddepth = 0., eapp(5) = 0., ereuse(5) = 0., prunof(5) = 0.
    real    :: alpha1 = 0.
    integer :: kirr = 0
    real    :: fdirrig(NEVENT+1,3) = 0.
    ! soil
    integer :: soil = 0, ihygrp = 0
    real    :: bulkd = 0., orgm = 0., satwc = 0.
    real    :: fieldc(NLAY) = 0., pwp(NLAY) = 0., airdry(2) = 0.
    real    :: avmft(NLAY) = 0., pawft(NLAY) = 0., center(NLAY) = 0., totdep = 0.
    real    :: draind = 0., dcoeff = 0.
    ! carryover state
    real    :: theta(NLAY) = 0.
    integer :: oldcrp = 0, livecrop = 0, livecond = 0
    real    :: oldres = 0., residue = 0., snotmp = 0., snoh2o = 0., soilt(NLAY) = 0.
    ! weather, by day of year (padded past 366 with zeros)
    integer :: iyear = 0, imstr = 1, idstr = 1, ndays = 0, jdystr = 1, jdystp = 0
    real    :: lat = 0., long = 0., elev = 0.
    integer :: wx_ndays = 0
    real    :: wx_tmax(NDAY) = 0., wx_tmin(NDAY) = 0., wx_precip(NDAY) = 0., wx_etr(NDAY) = 0.
    real    :: tmax(NDAY) = 0., tmin(NDAY) = 0., precip(NFCST) = 0., etr(NFCST) = 0.
    real    :: gdds(0:NDAY) = 0., cropkc(NFCST) = 0., solar(NDAY) = 0.
    real    :: tanual = 0.
    ! dates
    integer :: jdybg = 0, jdyend = 0, jdyplt = 0, jfplt = 0
    integer :: jdyefc = 0, jdymat = 0, jdyfrz = 0, jdyflo = 0, jdyripe = 0, jdyveg = 0
    ! crop coefficient (CROPCO) day-to-day values
    real    :: kc = 0., pct = 0., gddcut = 0., gdd = 0.
    integer :: iefc = 1, icut = 1
    ! daily water balance values
    integer :: jday = 0, kstg = 0, irigno = 0, ievent = 1
    real    :: today = 0., jnexti = 0., tavg = 0.
    real    :: rain = 0., eprecip = 0., runoff = 0., runon = 0., dinf = 0., infday = 0.
    real    :: netirr = 0., groirr = 0., irrinf = 0.
    real    :: ep = 0., epmax = 0., e1 = 0., e2 = 0., time = 0., cume = 0., tp = 0.
    real    :: awater = 0., paw = 0., rzd = 0., perrzd(NLAY) = 0., rdf(NLAY) = 0.
    real    :: dpln = 0., awdpln = 0., dpla = 0., totwat = 0.
    real    :: curvno = 0.
    real    :: wetsup = 0.
    ! seasonal totals
    real    :: drains = 0., eprecips = 0., es = 0., etmax = 0., etrs = 0., ets = 0.
    real    :: etyld = 0., eveg = 0., precips = 0., runons = 0., sgrirr = 0., snirr = 0.
    real    :: tdefs = 0., ts = 0., tveg = 0., tdef(5) = 0., tps(5) = 0., dplbg = 0.
    real    :: wetsups = 0., balerr = 0.
    real    :: yield = 0., yldratio = 0., bvalue = 0.
    ! monthly and weekly totals
    real    :: etrmon(12) = 0., emon(12) = 0., tmon(12) = 0., etmon(12) = 0.
    real    :: ermon(12) = 0., ramon(12) = 0., rofmon(12) = 0., ronmon(12) = 0.
    real    :: irnmon(12) = 0., irgmon(12) = 0., infmon(12) = 0., dramon(12) = 0.
    real    :: dplmon(12) = 0., wsmon(12) = 0.
    integer :: numirr(12) = 0
    real    :: etrwk(53) = 0., etwk(53) = 0., erwk(53) = 0., rawk(53) = 0.
    real    :: irnwk(53) = 0., irgwk(53) = 0.
  end type csk_work_t

  public :: fix_on

contains

  ! True when bug fix FLAG is switched on for this run.
  pure logical function fix_on(w, flag)
    type(csk_work_t), intent(in) :: w
    integer, intent(in) :: flag
    fix_on = iand(w%fixes, flag) /= 0
  end function fix_on

end module csk_types
