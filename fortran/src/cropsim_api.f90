!=======================================================================
!  cropsim_api.f90 - C-callable interface to the CropSim v8.0 engine.
!
!  This replaces the file-driven PROGRAM CROPSIMv7 (original lines
!  555-1442) with three calls that Python reaches through ctypes:
!
!    cs_set_block    - the crop and model parameters from BLOCK.DAT
!    cs_set_tillage  - the tillage residue factors from TILLAGE.DAT
!    cs_run_year     - one year for one SIM (crop/irrigation/tillage),
!                      one soil and one weather year, with the carryover
!                      soil state passed in and handed back explicitly.
!
!  No files are read or written. The per-year statements below are the
!  ones from the original main program, in the same order; comments give
!  the original line numbers. The water balance itself is the unchanged
!  v8.0 subroutines in cropsim_engine.f90.
!
!  Carryover: the original kept the end-of-year state in INITIAL.DAT,
!  one file shared by every soil and weather site. Here the caller owns
!  the state, so each soil on each parcel carries its own state and
!  nothing leaks between soils or sites.
!
!  The engine keeps its working values in module variables, so it is not
!  thread-safe. Run parallel work in separate processes.
!=======================================================================

      MODULE CROPSIM_API

      USE, INTRINSIC :: ISO_C_BINDING
      USE PARM
      USE PARM_SNAPSHOT

      IMPLICIT NONE

      INTEGER(C_INT), PARAMETER :: CS_API_VERSION = 1

!     Status codes returned by the API (engine codes 1-4 come from the
!     original STOP checks; see tools/make_engine.py).
      INTEGER(C_INT), PARAMETER :: CS_OK              = 0
      INTEGER(C_INT), PARAMETER :: CS_ERR_RUNOFF      = 1
      INTEGER(C_INT), PARAMETER :: CS_ERR_EFF_PRECIP  = 2
      INTEGER(C_INT), PARAMETER :: CS_ERR_TRANS_CONV  = 3
      INTEGER(C_INT), PARAMETER :: CS_ERR_NEG_RUNOFF  = 4
      INTEGER(C_INT), PARAMETER :: CS_ERR_NO_BLOCK    = 10
      INTEGER(C_INT), PARAMETER :: CS_ERR_BAD_INPUT   = 11

!     ------------------------------------------------------------------
!     SIM file contents (one crop / irrigation / tillage combination).
!     Field names follow the original variables.
!     ------------------------------------------------------------------
      TYPE, BIND(C) :: CS_SIM_T
        INTEGER(C_INT) :: CROP, LAYERS
        INTEGER(C_INT) :: IMPLT, IDPLT, IMBG, IDBG, IMEND, IDEND
        REAL(C_FLOAT)  :: GDDVEG, GDDFLO, GDDRIPE, GYFORM, GDDEFC, GDDMAT
        INTEGER(C_INT) :: NCUT
        INTEGER(C_INT) :: JDYCUT(5)
        REAL(C_FLOAT)  :: RZMIN, RZMAX, TBREAK, GDDROOT, RZMGMT
        INTEGER(C_INT) :: IYIELD
        REAL(C_FLOAT)  :: YMAX, YCOEFF
        INTEGER(C_INT) :: ITERRC
        REAL(C_FLOAT)  :: CHAND, CHANW, TINTRV
        INTEGER(C_INT) :: NTILLS, ITFLAG
        INTEGER(C_INT) :: ITILTM(20), TILDAY(20), TILCOD(20)
        INTEGER(C_INT) :: IRRTYP
        REAL(C_FLOAT)  :: PAD(5), RAINAL(5), SYSCAP, IPER(5)
        REAL(C_FLOAT)  :: APMIN(5), APMAX(5), SMALLI(5)
        REAL(C_FLOAT)  :: GSTART, GSTOP
        INTEGER(C_INT) :: IRRSCH, JFIRST, JSTOPI, JGOI, JDFREQ
        REAL(C_FLOAT)  :: DDEPTH
        REAL(C_FLOAT)  :: EAPP(5), EREUSE(5), PRUNOF(5)
!       Used only when IRRTYP = 2 (historical / known irrigation):
        REAL(C_FLOAT)  :: ALPHA1, AIRDRY(2), FIELDC(10), PWP(10), BULKD
        INTEGER(C_INT) :: KIRR
!       Irrigation events: FDIRRIG(1,k) = day of year, (2,k) = gross
!       depth (in), (3,k) = fraction infiltrated.
        REAL(C_FLOAT)  :: FDIRRIG(3,50)
      END TYPE CS_SIM_T

!     ------------------------------------------------------------------
!     Soil properties (one NESOILS.DAT row plus the drainage values the
!     original looked up by soil index).
!     ------------------------------------------------------------------
      TYPE, BIND(C) :: CS_SOIL_T
        INTEGER(C_INT) :: SOIL
        REAL(C_FLOAT)  :: BULKD, ORGM, FIELDC(10), PWP(10), AIRDRY(2)
        REAL(C_FLOAT)  :: DRNCOE, DRNDAY
      END TYPE CS_SOIL_T

!     ------------------------------------------------------------------
!     One year of daily weather (the .WEA file). Values start on the
!     day IMSTR/IDSTR and run for NDAYS days.
!     ------------------------------------------------------------------
      TYPE, BIND(C) :: CS_WEATHER_T
        INTEGER(C_INT) :: YEAR, IMSTR, IDSTR, NDAYS
        REAL(C_FLOAT)  :: LAT, LONG, ELEV
        REAL(C_FLOAT)  :: TMAX(366), TMIN(366), PRECIP(366)
        REAL(C_FLOAT)  :: EPAN(366), ETR(366)
      END TYPE CS_WEATHER_T

!     ------------------------------------------------------------------
!     Carryover state (the INITIAL.DAT contents).
!     ------------------------------------------------------------------
      TYPE, BIND(C) :: CS_STATE_T
        REAL(C_FLOAT)  :: THETA(10)
        INTEGER(C_INT) :: OLDCRP, LIVECROP
        REAL(C_FLOAT)  :: OLDRES, SNOTMP, SNOH2O, SOILT(10)
      END TYPE CS_STATE_T

!     ------------------------------------------------------------------
!     Results for the year.
!     ------------------------------------------------------------------
      TYPE, BIND(C) :: CS_RESULT_T
        INTEGER(C_INT) :: STATUS
!       Crop codes as the original COHYST output files would label them
!       (winter wheat fallow years are reported as 15).
        INTEGER(C_INT) :: CROP_YR, CROP_MON
        INTEGER(C_INT) :: IMBG, IMEND
        INTEGER(C_INT) :: JDYPLT, JFIRST, JDYEFC, JDYMAT, JDYFRZ, IRIGNO
!       ITFLAG as used for the year (the engine zeroes it for some wheat
!       years).
        INTEGER(C_INT) :: ITFLAG
        REAL(C_FLOAT)  :: YIELD, YLDRATIO, BVALUE, ETMAX, ETYLD
        REAL(C_FLOAT)  :: ETS, ETRS, ES, TS
        REAL(C_FLOAT)  :: SGRIRR, SNIRR, PRECIPS, EPRECIPS, DRAINS
        REAL(C_FLOAT)  :: DPLBG, TOTROF
!       Monthly totals (inches), index = calendar month.
        REAL(C_FLOAT)  :: ETRMON(12), EMON(12), TMON(12), ETMON(12)
        REAL(C_FLOAT)  :: ERMON(12), RAMON(12), ROFMON(12), RONMON(12)
        REAL(C_FLOAT)  :: IRNMON(12), IRGMON(12), INFMON(12), DRAMON(12)
        REAL(C_FLOAT)  :: DPLMON(12)
        INTEGER(C_INT) :: NUMIRR(12)
!       Weekly totals (inches), index = week of year.
        REAL(C_FLOAT)  :: ETRWK(53), ETWK(53), ERWK(53), RAWK(53)
        REAL(C_FLOAT)  :: IRNWK(53), IRGWK(53)
      END TYPE CS_RESULT_T

      LOGICAL, SAVE :: BLOCK_SET = .FALSE.

      CONTAINS

!=======================================================================
      FUNCTION CS_VERSION() BIND(C, NAME='cs_version') RESULT(V)
      INTEGER(C_INT) :: V
      V = CS_API_VERSION
      END FUNCTION CS_VERSION

!=======================================================================
!     Byte size of each interface type, so the Python side can check its
!     structure layouts: 1 SIM, 2 SOIL, 3 WEATHER, 4 STATE, 5 RESULT.
!=======================================================================
      FUNCTION CS_STRUCT_SIZE(WHICH) BIND(C, NAME='cs_struct_size')     &
          RESULT(NBYTES)
      INTEGER(C_INT), VALUE :: WHICH
      INTEGER(C_INT) :: NBYTES
      TYPE(CS_SIM_T)     :: A
      TYPE(CS_SOIL_T)    :: B
      TYPE(CS_WEATHER_T) :: C
      TYPE(CS_STATE_T)   :: E
      TYPE(CS_RESULT_T)  :: F
      SELECT CASE (WHICH)
        CASE (1); NBYTES = INT(C_SIZEOF(A), C_INT)
        CASE (2); NBYTES = INT(C_SIZEOF(B), C_INT)
        CASE (3); NBYTES = INT(C_SIZEOF(C), C_INT)
        CASE (4); NBYTES = INT(C_SIZEOF(E), C_INT)
        CASE (5); NBYTES = INT(C_SIZEOF(F), C_INT)
        CASE DEFAULT; NBYTES = -1
      END SELECT
      END FUNCTION CS_STRUCT_SIZE

!=======================================================================
!     BLOCK.DAT (original lines 596-645). CC is passed in Fortran order
!     CC(22,3,10); CN as CN(22,4); SNOW = SFTMP, SMFMX, SMFMN, SNOCOVMX,
!     SNOCOV1, SNOCOV2, TIMP.
!=======================================================================
      FUNCTION CS_SET_BLOCK(P_ETRFACT, P_NFDAY, P_YTREND, P_DEPTH,      &
          P_YDENS, P_RESRAT, P_SPGRAV, P_FRAGIL, P_RESTYP, P_CC,        &
          P_KCL, P_KCU, P_TBASE, P_TCEIL, P_SNOW, P_CNFALLOW, P_CN)     &
          BIND(C, NAME='cs_set_block') RESULT(ISTAT)
      REAL(C_FLOAT),  VALUE      :: P_ETRFACT
      INTEGER(C_INT), VALUE      :: P_NFDAY, P_YTREND
      REAL(C_FLOAT),  INTENT(IN) :: P_DEPTH(10)
      REAL(C_FLOAT),  INTENT(IN) :: P_YDENS(22), P_RESRAT(22), P_SPGRAV(22)
      INTEGER(C_INT), INTENT(IN) :: P_FRAGIL(22), P_RESTYP(22)
      REAL(C_FLOAT),  INTENT(IN) :: P_CC(22,3,10)
      REAL(C_FLOAT),  INTENT(IN) :: P_KCL(22), P_KCU(22)
      REAL(C_FLOAT),  INTENT(IN) :: P_TBASE(22), P_TCEIL(22)
      REAL(C_FLOAT),  INTENT(IN) :: P_SNOW(7), P_CNFALLOW(4), P_CN(22,4)
      INTEGER(C_INT) :: ISTAT

      ETRFACT = P_ETRFACT
      NFDAY   = P_NFDAY
      YTREND  = P_YTREND
      DEPTH   = P_DEPTH
      YDENS   = P_YDENS
      RESRAT  = P_RESRAT
      SPGRAV  = P_SPGRAV
      FRAGIL  = P_FRAGIL
      RESTYP  = P_RESTYP
      CC      = P_CC
      KCL     = P_KCL
      KCU     = P_KCU
      TBASE   = P_TBASE
      TCEIL   = P_TCEIL
      SFTMP    = P_SNOW(1)
      SMFMX    = P_SNOW(2)
      SMFMN    = P_SNOW(3)
      SNOCOVMX = P_SNOW(4)
      SNOCOV1  = P_SNOW(5)
      SNOCOV2  = P_SNOW(6)
      TIMP     = P_SNOW(7)
      CNFALLOW = P_CNFALLOW
      CN       = P_CN

      BLOCK_SET = .TRUE.
      CALL PARM_SAVE
      ISTAT = CS_OK
      END FUNCTION CS_SET_BLOCK

!=======================================================================
!     TILLAGE.DAT (original lines 650-660): factors by tillage code 1-80.
!=======================================================================
      FUNCTION CS_SET_TILLAGE(N, CODES, FAC1, FAC2)                     &
          BIND(C, NAME='cs_set_tillage') RESULT(ISTAT)
      INTEGER(C_INT), VALUE      :: N
      INTEGER(C_INT), INTENT(IN) :: CODES(N)
      REAL(C_FLOAT),  INTENT(IN) :: FAC1(N), FAC2(N)
      INTEGER(C_INT) :: ISTAT
      INTEGER :: K

      ISTAT = CS_OK
      DO K = 1, N
        IF ((CODES(K).LT.1).OR.(CODES(K).GT.80)) THEN
          ISTAT = CS_ERR_BAD_INPUT
          RETURN
        END IF
        TILFAC(CODES(K),1) = FAC1(K)
        TILFAC(CODES(K),2) = FAC2(K)
      END DO
      CALL PARM_SAVE
      END FUNCTION CS_SET_TILLAGE

!=======================================================================
!     Round the carryover state exactly as writing and re-reading
!     INITIAL.DAT did (formats 476-478), so results can match the
!     original program digit for digit.
!=======================================================================
      SUBROUTINE ROUND_STATE_LIKE_INITIAL_DAT(ST)
      TYPE(CS_STATE_T), INTENT(INOUT) :: ST
      CHARACTER(LEN=200) :: BUF
      INTEGER :: K

      WRITE(BUF,476) (ST%THETA(K),K=1,10)
      READ(BUF,*) (ST%THETA(K),K=1,10)
      WRITE(BUF,477) ST%OLDCRP, ST%OLDRES, ST%LIVECROP
      READ(BUF,*) ST%OLDCRP, ST%OLDRES, ST%LIVECROP
      WRITE(BUF,478) ST%SNOTMP, ST%SNOH2O, (ST%SOILT(K),K=1,10)
      READ(BUF,*) ST%SNOTMP, ST%SNOH2O, (ST%SOILT(K),K=1,10)
476   FORMAT(10(2X,F6.3))
477   FORMAT(2X,I4,2X,F9.1,2X,I4)
478   FORMAT(2X,F8.1,4X,F6.2,4X,10(2X,F5.1))
      END SUBROUTINE ROUND_STATE_LIKE_INITIAL_DAT

!=======================================================================
!     Run one year.
!
!     LIVECOND   1 when the original would set it: the same SIM file as
!                the previous run with an earlier year (original 789-801).
!     LEGACY_ROUND  1 to round the returned state the way INITIAL.DAT
!                did (needed to match the original program exactly).
!=======================================================================
      FUNCTION CS_RUN_YEAR(SIMP, SOILP, WX, STATE_IN, LIVECONDP,        &
          LEGACY_ROUND, STATE_OUT, RES)                                 &
          BIND(C, NAME='cs_run_year') RESULT(ISTAT)
      TYPE(CS_SIM_T),     INTENT(IN)  :: SIMP
      TYPE(CS_SOIL_T),    INTENT(IN)  :: SOILP
      TYPE(CS_WEATHER_T), INTENT(IN)  :: WX
      TYPE(CS_STATE_T),   INTENT(IN)  :: STATE_IN
      INTEGER(C_INT), VALUE           :: LIVECONDP, LEGACY_ROUND
      TYPE(CS_STATE_T),   INTENT(OUT) :: STATE_OUT
      TYPE(CS_RESULT_T),  INTENT(OUT) :: RES
      INTEGER(C_INT) :: ISTAT
      INTEGER :: K, ZZL, LIVECROP_DEPLT

      ISTAT = CS_OK
      RES%STATUS = CS_OK
      STATE_OUT = STATE_IN

      IF (.NOT.BLOCK_SET) THEN
        ISTAT = CS_ERR_NO_BLOCK
        RES%STATUS = ISTAT
        RETURN
      END IF
      IF ((SIMP%CROP.LT.1).OR.(SIMP%CROP.GT.22).OR.                     &
          (SIMP%LAYERS.LT.1).OR.(SIMP%LAYERS.GT.10).OR.                 &
          (SIMP%IRRTYP.LT.1).OR.(SIMP%IRRTYP.GT.5).OR.                  &
          (SIMP%NTILLS.LT.0).OR.(SIMP%NTILLS.GT.20).OR.                 &
          (SIMP%KIRR.LT.0).OR.(SIMP%KIRR.GT.50).OR.                     &
          (WX%NDAYS.LT.1).OR.(WX%NDAYS.GT.366).OR.                      &
          (STATE_IN%OLDCRP.LT.1).OR.(STATE_IN%OLDCRP.GT.22)) THEN
        ISTAT = CS_ERR_BAD_INPUT
        RES%STATUS = ISTAT
        RETURN
      END IF

!     Start from the values saved when the parameters were set, so
!     nothing is left over from an earlier run.
      CALL PARM_RESTORE

!     Library mode: no text files, no printed output.
      LIBMODE   = .TRUE.
      CS_STATUS = 0
      IPFLAG    = 0
      INPRIN    = 1
      IPSOIL    = -1
      NPRSITE   = 0
      OUTPUTFORMAT = 1
      ISIM      = 1
      WSITE     = '    '
      WEAFILE(1) = ' '
      SIMFILE(1) = ' '
      DO K = 1, 80
        LOCATE(K) = ' '
      END DO

      IYEAR    = WX%YEAR
      LIVECOND = LIVECONDP

!     ---- original lines 812-822 ----
      IRIGNO = 0
      DO K = 1, 20
        ITILTM(K) = 0
        TILDAY(K) = 0
        TILCOD(K) = 0
      END DO

!     ---- SIM file, original lines 828-910 ----
      CROP   = SIMP%CROP
      LAYERS = SIMP%LAYERS
      IMPLT  = SIMP%IMPLT
      IDPLT  = SIMP%IDPLT
      IMBG   = SIMP%IMBG
      IDBG   = SIMP%IDBG
      IMEND  = SIMP%IMEND
      IDEND  = SIMP%IDEND
      GDDVEG  = SIMP%GDDVEG
      GDDFLO  = SIMP%GDDFLO
      GDDRIPE = SIMP%GDDRIPE
      GYFORM  = SIMP%GYFORM
      GDDEFC  = SIMP%GDDEFC
      GDDMAT  = SIMP%GDDMAT
      NCUT    = SIMP%NCUT
      JDYCUT  = SIMP%JDYCUT
      RZMIN   = SIMP%RZMIN
      RZMAX   = SIMP%RZMAX
      TBREAK  = SIMP%TBREAK
      GDDROOT = SIMP%GDDROOT
      RZMGMT  = SIMP%RZMGMT
      IYIELD  = SIMP%IYIELD
      YMAX    = SIMP%YMAX
      YCOEFF  = SIMP%YCOEFF

!     Root zone adjustment by soil (original 849-856).
      SOIL = SOILP%SOIL
      IF ((CROP .NE. 12) .AND. (CROP .NE. 13)) THEN
        SOILRZ = SOIL/100
        RZFACT = AMIN1((0.6+0.4*(SOILRZ-3.0)/4.0),1.0)
        RZMGMT = RZMGMT * RZFACT
        RZMAX  = RZMAX  * RZFACT
      END IF

      ITERRC = SIMP%ITERRC
      CHAND  = SIMP%CHAND
      CHANW  = SIMP%CHANW
      TINTRV = SIMP%TINTRV
      NTILLS = SIMP%NTILLS
      ITFLAG = SIMP%ITFLAG
      DO K = 1, NTILLS
        ITILTM(K) = SIMP%ITILTM(K)
        TILDAY(K) = SIMP%TILDAY(K)
        TILCOD(K) = SIMP%TILCOD(K)
      END DO
      IRRTYP = SIMP%IRRTYP
      PAD    = SIMP%PAD
      RAINAL = SIMP%RAINAL
      SYSCAP = SIMP%SYSCAP
      IPER   = SIMP%IPER
      APMIN  = SIMP%APMIN
      APMAX  = SIMP%APMAX
      SMALLI = SIMP%SMALLI
      GSTART = SIMP%GSTART
      GSTOP  = SIMP%GSTOP
      IRRSCH = SIMP%IRRSCH
      JFIRST = SIMP%JFIRST
      JSTOPI = SIMP%JSTOPI
      JGOI   = SIMP%JGOI
      JDFREQ = SIMP%JDFREQ
      DDEPTH = SIMP%DDEPTH
      EAPP   = SIMP%EAPP
      EREUSE = SIMP%EREUSE
      PRUNOF = SIMP%PRUNOF

!     ---- Soil properties, original lines 913-984 ----
      IF (IRRTYP.EQ.2) THEN
        ALPHA1    = SIMP%ALPHA1
        AIRDRY    = SIMP%AIRDRY
        FIELDC    = SIMP%FIELDC
        PWP       = SIMP%PWP
        BULKD     = SIMP%BULKD
        TOTDEP = 0.0
        DO I = 1, LAYERS
          AVMFT(I) = (FIELDC(I)-PWP(I))*DEPTH(I)
          PAWFT(I) = AVMFT(I)
          TOTDEP = TOTDEP+DEPTH(I)
        END DO
!       The original read these from FDFILE as FDIRRIG(J,I), which put
!       them in the wrong index order for the way IRRIGA/DEPLT read them
!       (FDIRRIG(IRIGNO,1..3)). They are stored here in the order the
!       engine reads them.
        KIRR = SIMP%KIRR
        FDIRRIG = 0.0
        DO K = 1, KIRR
          FDIRRIG(K,1) = SIMP%FDIRRIG(1,K)
          FDIRRIG(K,2) = SIMP%FDIRRIG(2,K)
          FDIRRIG(K,3) = SIMP%FDIRRIG(3,K)
        END DO
      ELSE
        ALPHA1 = 0.0
        BULKD  = SOILP%BULKD
        ORGM   = SOILP%ORGM
        FIELDC = SOILP%FIELDC
        PWP    = SOILP%PWP
        AIRDRY = SOILP%AIRDRY
      END IF

      IHYGRP = SOIL/10 - 10*(SOIL/100)
      SATWC  = 1.0 - BULKD/2.65

      DRNCOE = SOILP%DRNCOE
      DRNDAY = SOILP%DRNDAY
      TOTDEP = 0.

      DO I = 1, LAYERS
        CENTER(I) = TOTDEP+DEPTH(I)*0.5
        RDEPTH = CENTER(I)/RZMAX
        IF (RDEPTH.GT.1.) RDEPTH = 1.
        D = EXP(-2.303*RDEPTH**4.462)
        AVMFT(I) = (FIELDC(I)-PWP(I))*DEPTH(I)
        PWP(I) = PWP(I)+(FIELDC(I)-PWP(I))*(1.-D)
        PAWFT(I) = (FIELDC(I)-PWP(I))*DEPTH(I)
        TOTDEP = TOTDEP+DEPTH(I)
      END DO

!     ---- Carryover state, original lines 986-998 ----
      THETA    = STATE_IN%THETA
      OLDCRP   = STATE_IN%OLDCRP
      OLDRES   = STATE_IN%OLDRES
      LIVECROP = STATE_IN%LIVECROP
      SNOTMP   = STATE_IN%SNOTMP
      SNOH2O   = STATE_IN%SNOH2O
      SOILT    = STATE_IN%SOILT

      IF (LIVECOND.EQ.1) LIVECROP = 1

      IF (CROP.LT.10) THEN
        RESIDUE = OLDRES
      ELSE
        RESIDUE = 100.
      END IF

!     ---- Winter wheat, original lines 1005-1035 ----
      IF (CROP.EQ.7) THEN
        IMFPLT = IMPLT
        IDFPLT = IDPLT
        CALL DAYOFYR(JDYPLT,IMPLT,IDPLT)
        JFPLT = JDYPLT
        IF ((IRRTYP.GT.1).OR.(ITFLAG.GT.2)) THEN
          LIVECROP = 1
        ELSE
          IF (LIVECROP.EQ.0) ITFLAG = 0
        END IF
        IF (LIVECROP.EQ.1) THEN
          IMPLT = 3
          IDPLT = 15
          IF ((IRRTYP.EQ.1).AND.(ITFLAG.LT.3)) JFPLT = -999
        END IF
      ELSE
        LIVECROP = 0
        JFPLT = -999
      END IF

      DPLBG = 0.0
      DO I = 1, LAYERS
        DPLBG = DPLBG+(FIELDC(I)-THETA(I))*DEPTH(I)
      END DO

      DRAIND = DRNDAY
      DCOEFF = DRNCOE

!     ---- Weather, original lines 1049-1053 ----
      CALL DAYOFYR(JDYBG,IMBG,IDBG)
      CALL DAYOFYR(JDYEND,IMEND,IDEND)
      CALL DAYOFYR(JDYPLT,IMPLT,IDPLT)

      IMSTR = WX%IMSTR
      IDSTR = WX%IDSTR
      NDAYS = WX%NDAYS
      LAT   = WX%LAT
      LONG  = WX%LONG
      ELEV  = WX%ELEV
      WX_NDAYS  = WX%NDAYS
      WX_TMAX   = WX%TMAX
      WX_TMIN   = WX%TMIN
      WX_PRECIP = WX%PRECIP
      WX_EPAN   = WX%EPAN
      WX_ETR    = WX%ETR
      CALL READWEAT

!     ---- Tillage dates, original lines 1059-1081 ----
      DO I = 1, NTILLS
        IF (CROP.NE.7) THEN
          IF (ITILTM(I).EQ.1) TILDAY(I) = JDYPLT - TILDAY(I)
          IF (ITILTM(I).EQ.2) TILDAY(I) = JDYPLT + TILDAY(I)
          IF (ITILTM(I).EQ.3) TILDAY(I) = JDYMAT + TILDAY(I)
        ELSE
          IF (LIVECROP.EQ.0) THEN
            IF (ITILTM(I).EQ.1) TILDAY(I) = JDYPLT - TILDAY(I)
            IF (ITILTM(I).EQ.2) TILDAY(I) = JDYPLT + TILDAY(I)
            IF (ITILTM(I).EQ.3) TILDAY(I) = 367 + TILDAY(I)
          ELSE
            IF (ITILTM(I).EQ.1) TILDAY(I) = -999 - TILDAY(I)
            IF (ITILTM(I).EQ.2) TILDAY(I) = -999 + TILDAY(I)
            IF (ITILTM(I).EQ.3) TILDAY(I) = JDYMAT + TILDAY(I)
          END IF
        END IF
      END DO

!     ---- Water balance, original lines 1116-1127 ----
      LIVECROP_DEPLT = LIVECROP
      CALL DEPLT

      IF (ITFLAG.GT.0) THEN
        CALL YIELDS
      ELSE
        YIELD = 0.0
        YLDRATIO = 0.0
      END IF

!     ---- Winter wheat live-crop flag for next year, 1131-1149 ----
      IF (CROP.EQ.7) THEN
        IF ((IRRTYP.EQ.1).AND.(ITFLAG.LT.3)) THEN
          IF (LIVECROP.EQ.1) THEN
            LIVECROP = 0
          ELSE
            LIVECROP = 1
          END IF
        ELSE
          LIVECROP = 1
        END IF
      ELSE
        LIVECROP = 0
      END IF

!     ---- End-of-year state (was written to INITIAL.DAT, 1154-1168) ----
      STATE_OUT%THETA    = THETA
      STATE_OUT%OLDCRP   = CROP
      STATE_OUT%OLDRES   = RESIDUE
      STATE_OUT%LIVECROP = LIVECROP
      STATE_OUT%SNOTMP   = SNOTMP
      STATE_OUT%SNOH2O   = SNOH2O
      STATE_OUT%SOILT    = SOILT
      IF (LEGACY_ROUND.NE.0) CALL ROUND_STATE_LIKE_INITIAL_DAT(STATE_OUT)

!     ---- Results ----
!     COHYST crop labels: YR file (original 1187-1190) and MON file
!     (DEPLT, original 2719-2722) report fallow wheat years as 15.
      RES%CROP_YR = CROP
      IF ((CROP.EQ.7).AND.(LIVECROP.EQ.1).AND.(IRRTYP.EQ.1).AND.        &
          (ITFLAG.NE.3)) RES%CROP_YR = 15
      RES%CROP_MON = CROP
      IF ((CROP.EQ.7).AND.(LIVECROP_DEPLT.EQ.0).AND.(IRRTYP.EQ.1).AND.  &
          (ITFLAG.NE.3)) RES%CROP_MON = 15

      TOTROF = 0.
      DO ZZL = IMBG, IMEND
        TOTROF = TOTROF + ROFMON(ZZL)
      END DO

      RES%IMBG   = IMBG
      RES%IMEND  = IMEND
      RES%JDYPLT = JDYPLT
      RES%JFIRST = JFIRST
      RES%JDYEFC = JDYEFC
      RES%JDYMAT = JDYMAT
      RES%JDYFRZ = JDYFRZ
      RES%IRIGNO = IRIGNO
      RES%ITFLAG = ITFLAG
      RES%YIELD    = YIELD
      RES%YLDRATIO = YLDRATIO
      RES%BVALUE   = BVALUE
      RES%ETMAX    = ETMAX
      RES%ETYLD    = ETYLD
      RES%ETS      = ETS
      RES%ETRS     = ETRS
      RES%ES       = ES
      RES%TS       = TS
      RES%SGRIRR   = SGRIRR
      RES%SNIRR    = SNIRR
      RES%PRECIPS  = PRECIPS
      RES%EPRECIPS = EPRECIPS
      RES%DRAINS   = DRAINS
      RES%DPLBG    = DPLBG
      RES%TOTROF   = TOTROF
      RES%ETRMON = ETRMON
      RES%EMON   = EMON
      RES%TMON   = TMON
      RES%ETMON  = ETMON
      RES%ERMON  = ERMON
      RES%RAMON  = RAMON
      RES%ROFMON = ROFMON
      RES%RONMON = RONMON
      RES%IRNMON = IRNMON
      RES%IRGMON = IRGMON
      RES%INFMON = INFMON
      RES%DRAMON = DRAMON
      RES%DPLMON = DPLMON
      RES%NUMIRR = NUMIRR
      RES%ETRWK  = ETRWK
      RES%ETWK   = ETWK
      RES%ERWK   = ERWK
      RES%RAWK   = RAWK
      RES%IRNWK  = IRNWK
      RES%IRGWK  = IRGWK

      ISTAT = CS_STATUS
      RES%STATUS = ISTAT
      LIBMODE = .FALSE.
      END FUNCTION CS_RUN_YEAR

      END MODULE CROPSIM_API
