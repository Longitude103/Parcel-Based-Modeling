!=======================================================================
!  CropSim v8.0 engine for the cropsim Python package.
!
!  GENERATED FILE - DO NOT EDIT. Produced by tools/make_engine.py from the
!  frozen original fortran/original/CROPSIM_V8.0.F90. Lines changed from
!  the original are marked with  !LIB  comments.
!=======================================================================
!**********************************************************************
!-----------------------------------------------------------------------
!  PARAMETER MODULE
!-----------------------------------------------------------------------
! Basic Information
!
!   Crops: 1. Spring Small Grains      Soils: Identified By A 3 Digit
!          2. Edible Beans                    Code That Represents The
!          3. Soybeans                        Available Water Holding
!          4. Potatoes                        Capacity (In Quarter Of
!          5. Sugar Beets                     Inch/Foot), Hydrologic
!          6. Sorghum (MILO)                  Group (1=a,...4=d), And
!          7. Winter Wheat                    Depth To Groundwater
!          8. Corn                            Indicator (1<6ft, 2>6ft)
!          9. Sunflower
!         10. Alfalfa
!         11. Irrigated Hay            Irrigation  1. Dryland
!         12. Irrigated Pasture        Types:      2. Fixed Irrig. Dates
!         13. Native Pasture/Grass                 3. Pivot - Sprinkler
!         14. Urban Turf                           4. Furrow Irrigation
!         15. Summer Fallow                        5. Other
!         16. Riparian Woodlands
!         17. Non-Riparian Woodlands
!         18. Wetlands-Cattails,Bulrush (Killing Frost)
!         19. Wetlands-Reed Swamp Mixed
!         20. Open Water - Shallow (< 2 m deep)
!         21. Open Water - Deep ( > 5 m deep)
!         22. Residential / Roads / Farmsteads
!-----------------------------------------------------------------------
!
!  ---------------------------------------------------------------------
!   VARIABLE LIST:
!  ---------------------------------------------------------------------
!   AIRDRY(2)     - AIR DRY VOLUMETRIC WATER CONTENT FOR TOP THREE LAYERS
!   APMAX(5)      - MAXIMUM IRRIGATION APPLICATION IN EACH STAGE
!   APMIN(5)      - MINIMUM IRRIGATION APPLICATION IN EACH STAGE
!   AVMFT(10)     - AVAILABLE VOLUMETRIC MOISTURE IN EACH LAYER
!   CC(22,3,10)   - CROP COEFFICIENTS FOR 22 CROPS
!   CN(22,4)      - CURVE NUMBER FOR EACH CROP AND HYDROLOGIC SOIL GROUP
!   CROP          - CROP TYPE
!	CROPKC(366)	  -	DAILY VALUE OF CROP COEFFICIENT
!   DCOEFF        - DRAINAGE COEFFICIENT FOR CURRENT SOIL
!   DDEPTH        - DELIEVERED DEPTH OF WATER
!   DEPTH(10)     - THICKNESS OF EACH SOIL LAYER
!   DPLA		  - ALLOWABLE DEPLETION
!   DRAIND        - DRAINAGE TIME FOR CURRENT SOIL
!   DRAINS        - TOTAL DRAINAGE
!   DRNCOE        - DRAINAGE COEFFICIENT A SOIL
!   DCOFSOIL(28)  - DRAINAGE COEFFICIENT FOR EACH SOIL TYPE
!	DDAYSOIL(28)  - DRAINAGE DURATION FOR EACH SOIL TYPE
!   DRNDAY        - DRAINAGE TIME FOR A SOIL
!   EAPP(5)       - APPLICATION EFFICIENCY FOR EACH GROWTH STAGE
!   EPAN(366)     - DAILY PAN EVAPORATION WHERE AVAILABLE (IN/D)
!   ERAINS        - SEASONAL EFFECTIVE RAINFALL
!   EREUSE(5)     - EFFICIENCY OF REUSE FOR EACH GROWTH STAGE
!   ES            - SEASONAL EVAPORATION
!   ETR(366)      - REFERENCE CROP EVAPOTRANSPIRATION (ET)
!   ETRFACT       - FACTOR TO REDUCE REFERENCE CROP ET FOR FIELD CONDITIONS
!   ETRS          - SEASONAL REFERENCE CROP ET
!   EVEG          - EVAPORATION DURING VEGETATIVE STAGE
!   FIELDC(10)    - FIELD CAPACITY (FC) FOR 10 SOIL LAYERS
!	FORCRAIN	  - RAIN DURING FUTURE FORECAST PERIOD
!   GDDEFC        - GROWING DEGREE DAYS (GDD) TO EFFECTIVE COVER
!   GDDFLO        - GDD TO FLOWERING STAGE
!   GDDMAT        - GDD TO MATURITY
!   GDDRIPE       - GDD TO RIPENING STAGE
!   GDDS(366)     - CUMMULATIVE GDD
!   GDDVEG        - GDD TO VEGETATIVE STAGE
!   GDROOT        - GDD TO MAXIMUM ROOT DEPTH
!   GSTART        - GDD WHEN IRRIGATIONS BEGIN
!   GSTOP         - GDD WHEN IRRIGATIONS STOP
!   GYFORM        - GDD TO YIELD FORMATION
!
!   FDIRRIG       - 2 dimensional array for storing historical data
!       1-DOY of Irrigation,
!       2- Gross Irrigation Depth in inches,
!       3-Fraction Infiltrated.
!
!   IPER(5)       - DECIMAL PERCENT OF OPERATING TIME FOR EACH STAGE
!   IRRSCH        - THE TYPE OF WATER SUPPLY FOR IRRIGATION
!   IRRTYP        - TYPE OF IRRIGATION SYSTEM
!   JDFREQ        - FREQUENCY OF IRRIGATION ROTATION
!   JDSCH		  -	COUNTER FOR FORECAST PERIOD
!   JDYEFC        - DAY TO EFFECTIVE COVER
!   JDYFLO        - DAY OF START OF FLOWERING STAGE
!   JDYMAT        - DAY OF MATURITY
!   JDYPLT        - DAY OF PLANTING
!   JDYRIPE       - DAY RIPE
!   JDYVEG        - DAY OF START OF VEGETATIVE STAGE
!   JFIRST        - FIRST DAY OF IRRIGATION ON FIXED ROTATION
!   JGOI          - DAY OF YEAR TO RESUME IRRIGATION IN FALL FOR ALFALFA OR PASTURE
!   JSTOPI        - DAY OF YEAR FOR SUMMER IRRIGATION CUTOFF FOR ALFALFA OR PASTURE
!   KCL(22)       - LOWER LIMIT FOR CROP COEFFICIENT
!   KCU(22)       - UPPER LIMIT FOR CROP COEFFICIENT
!   LAYERS        - NUMBER OF SOIL LAYERS
!   LOCATE        - LOCATION
!   NWSSITE       - LIST OF AVAILALBE NWS WEATHER SITES IN NWSXSOIL.DAT FILE
!	NFDAY		  -	NUMBER OF DAYS IN THE FORECAST PERIOD FOR RAIN
!   PAD(5)        - PERCENT ALLOWABLE DEPLETION
!   PAWFT(10)     - PLANT AVAILABLE WATER (PAW) FOR EACH LAYER
!   PRUNOF(5)     - PERCENT RUNOFF FOR EACH GROWTH STAGE
!   PWP(10)       - PERMANENT WILTING POINT (PWP) FOR 10 SOIL LAYERS
!   RAIN          - DAILY RAINFALL, INCHES
!   RAINAL(5)     - RAINFALL ALLOWANCE FOR EACH GROWTH STAGE
!   RXMIN         - MINIMUM ROOT ZONE DEPTH
!   RZMAX         - MAXIMUM ROOT ZONE DEPTH
!   RZMGMT		  - ROOT ZONE DEPTH FOR IRRIGATION SCHEDULING
!   SATWC         - SATURATED SOIL WATER CONTENT
!   SGRIRR        - SEASONAL GROSS IRRIGATION
!   SMALLI(5)     - SMALLEST IRRIGATION POSSIBLE IN EACH STAGE
!   SNIRR         - SEASONAL NET IRRIGATIONS
!   SOIL          - SOIL CODE
!	SOILSIM		  - FLAG TO INDICATE THE SOIL IS SIMULATED AT A SITE (> 0 = YES)
!	SOILTYP		  - TYPES OF SOIL THAT CAN BE SIMULATED
!   SYSCAP        - SYSTEM CAPACITY
!   TBASE(22)     - GDD BASE TEMPERATURE
!   TBREAK        - PERCENT OF PAW
!   TCEIL(22)     - GDD CEILING TEMPERATURE
!   TDEF(5)       - TRANSPIRATION DEFICIT DURING EACH STAGE
!   TDEFS         - SEASONAL TRANSPIRATION DEFICIT
!   THETA(10)     - INITAL VOLUMETRIC WATER CONTENT FOR EACH LAYER
!   TMAX(366)     - MAXIMUM TEMPERATURE
!   TMIN(366)     - MINIMUM TEMPERATURE
!   TOTDEP        - TOTAL DEPTH OF SOIL PROFILE
!   TPS(5)        - SEASONAL POTENTAL TRANSPIRATION
!   TS            - SEASONAL TRANSPIRATION
!   TVEG          - TRANSPIRATION DURING THE VEGETATIVE STAGE
!   YTREND		  - VARIABLE FOR LONG-TERM YIELD TRENDS (=1 INCLUDE TREND)
!   YADJ          - FRACTIONI OF 2001 YIELD WHEN YTREND IS ON
!***********************************************************************

      MODULE PARM

      REAL ::      AIRDRY(2)
      REAL ::      AIRMAX
      REAL ::      AIRMIN
      REAL ::      ALPHA1
      REAL ::      APMAX(5)
      REAL ::      APMIN(5)
      REAL ::      AWATER
	  REAL ::      AWDPLN
      REAL ::      AVMFT(10)
	  REAL ::      BOTDEP
      REAL ::      BULKD
	  REAL ::      BVALUE
      REAL ::      CC(22,3,10)
      REAL ::      CENTER(10)
      REAL ::      CHAND
      REAL ::      CHANW
	  REAL ::      CROPKC(366)
      REAL ::      CN(22,4)
      REAL ::      CNFALLOW(4)
      REAL ::      CUME
      REAL ::      CURVNO
	  REAL ::      CURVN1
	  REAL ::      CURVN3
      REAL ::      D
      REAL ::      DCOEFF
	  REAL ::      DCOFSOIL(28)
	  REAL ::      DDAYSOIL(28)
      REAL ::      DDEPTH
      REAL ::      DEPL(10)
      REAL ::      DEPTH(10)
      REAL ::      DINF
	  REAL ::      DPLA
      REAL ::      DPLBG
      REAL ::      DPLMON(12)
      REAL ::      DPLN
      REAL ::      DPLPER
      REAL ::      DRAIND
      REAL ::      DRAINS
      REAL ::      DRAMON(12)
      REAL ::      DRNCOE
      REAL ::      DRNDAY
      REAL ::      DRNIN
      REAL ::      E1
      REAL ::      E2
      REAL ::      EAPP(5)
      REAL ::      EIN
	  REAL ::      ELEV
      REAL ::      EMON(12)
      REAL ::      EP
	  REAL ::      EPAN(366)
      REAL ::      EPRECIP
      REAL ::      EPRECIPS
      REAL ::      EREUSE(5)
      REAL ::      ERMON(12)
      REAL ::      ES
      REAL ::      ETIN
	  REAL ::      ETRFACT
      REAL ::      ETMAX
      REAL ::      ETMON(12)
      REAL ::      ETR(366)
      REAL ::      ETRA
      REAL ::      ETRIN
      REAL ::      ETRMON(12)
      REAL ::      ETRS
      REAL ::      ETS
      REAL ::      ETYLD
      REAL ::      EVEG
	  REAL ::      FC
	  REAL ::      FDEPTH
      REAL ::      FDIRRIG(50, 4)
      REAL ::      FIELDC(10)
	  REAL ::	   FORCRAIN
      REAL ::      GDD
      REAL ::      GDDEFC
      REAL ::      GDDFLO
      REAL ::      GDDMAT
      REAL ::      GDDRIPE
      REAL ::      GDDROOT
      REAL ::      GDDS(366)
      REAL ::      GDDVEG
      REAL ::      GROIRR
      REAL ::      GRZROT
      REAL ::      GSTART
      REAL ::      GSTOP
      REAL ::      GYFORM
      REAL ::      INFMON(12)
      REAL ::      IPER(5)
      REAL ::      IRGMON(12)
      REAL ::      IRNMON(12)
	  REAL ::      JNEXTI
      REAL ::      KC
      REAL ::      KCL(22)
      REAL ::      KCU(22)
      REAL ::      LAT
	  REAL ::	   LONG
      REAL ::      NETIRR
      REAL ::      OLDRES
      REAL ::      ORGM
      REAL ::      PAD(5)
      REAL ::      PAW
      REAL ::      PAWFT(10)
      REAL ::      PERDEP(10)
      REAL ::      PERRZD(10)
      REAL ::      PRECIP(366)
      REAL ::      PRECIPA
      REAL ::      PRECIPS
      REAL ::      PRUNOF(5)
      REAL ::      PWP(10)
      REAL ::      RAIN
      REAL ::      RAINAL(5)
      REAL ::      RAMON(12)
      REAL ::      RDEPTH
      REAL ::      RDF(10)
      REAL ::      RESIDUE
      REAL ::      RESRAT(22)
      REAL ::      RESREM
      REAL ::      RNIN
      REAL ::      ROFMON(12)
      REAL ::      RONMON(12)
      REAL ::      RRUNOFF
      REAL ::      RUNOFF
      REAL ::      RUNON
      REAL ::      RZD
      REAL ::      RZFACT
      REAL ::      RZMAX
      REAL ::      RZMGMT
      REAL ::      RZMIN
	  REAL ::      SATWC
	  REAL ::      SAT
      REAL ::      SFTMP
      REAL ::      SGRIRR
      REAL ::      SMALLI(5)
	  REAL ::      SMAX
      REAL ::      SMFMX
      REAL ::      SMFMN
      REAL ::      SMTMP
      REAL ::      SNIRR
      REAL ::      SNOCOV
      REAL ::      SNOCOVMX
      REAL ::      SNOCOV1
      REAL ::      SNOCOV2
      REAL ::      SNOFALL
      REAL ::      SNOH2O
      REAL ::      SNOMLT
      REAL ::      SNOTMP
      REAL ::      SOILRAD
	  REAL ::      SOILRZ
      REAL ::      SOILT(10)
      REAL ::      SOLAR(366)
      REAL ::      SPGRAV(22)
      REAL ::      SURFTEMP
	  REAL ::      SW
      REAL ::      SYSCAP
	  REAL ::      S3
      REAL ::      T1
      REAL ::      T2
      REAL ::      TAMP
      REAL ::      TANUAL
      REAL ::      TAVG
      REAL ::      TBARE
      REAL ::      TBASE(22)
      REAL ::      TBREAK
      REAL ::      TCEIL(22)
      REAL ::      TDEF(5)
      REAL ::      TDEFS
      REAL ::      THETA(10)
      REAL ::      TILFAC(80,2)
      REAL ::      TIME
      REAL ::      TIMP
      REAL ::      TIN
      REAL ::      TINTRV
      REAL ::      TMAX(366)
      REAL ::      TMAXA
      REAL ::      TMIN(366)
      REAL ::      TMINA
      REAL ::      TMON(12)
	  REAL ::      TODAY
	  REAL ::      TOPDEP
      REAL ::      TOTDEP
      REAL ::      TOTWAT
      REAL ::      TPS(5)
      REAL ::      TS
      REAL ::      TVEG
      REAL ::      WINF
	  REAL ::      YACT
      REAL ::      YCOEFF
      REAL ::      YDENS(22)
      REAL ::      YIELD
	  REAL ::      YLDRATIO
      REAL ::      YMAX
	  REAL ::      W1
	  REAL ::      W2

      REAL ::      ETRWK(53) 
      REAL ::      ETWK(53)  
      REAL ::      ERWK(53)  
      REAL ::      RAWK(53)  
      REAL ::      IRNWK(53) 
      REAL ::      IRGWK(53) 

	  REAL ::      TOTROF	!Added for Annual RO Number
      REAL ::      EPMAX    
      INTEGER ::   IWEEK

      INTEGER ::   CLIMZONE
      INTEGER ::   CROP
      INTEGER ::   FRAGIL(22)
      INTEGER ::   I
      INTEGER ::   IADD
      INTEGER ::   IC
      INTEGER ::   ICUT
      INTEGER ::   IDATE
      INTEGER ::   IDAY
      INTEGER ::   IDBG
      INTEGER ::   IDEFC
      INTEGER ::   IDEND
      INTEGER ::   IDFLO
      INTEGER ::   IDFPLT
      INTEGER ::   IDMAT
      INTEGER ::   IDPLT
      INTEGER ::   IDRIPE
      INTEGER ::   IDSTR
      INTEGER ::   IDVEG
      INTEGER ::   IHYDC
      INTEGER ::   IHYGRP
      INTEGER ::   II
	  INTEGER ::   ILAY
      INTEGER ::   IMBG
      INTEGER ::   IMEFC
      INTEGER ::   IMEND
      INTEGER ::   IMFLO
      INTEGER ::   IMFPLT
      INTEGER ::   IMMAT
      INTEGER ::   IMON
      INTEGER ::   IMPLT
      INTEGER ::   IMRIPE
      INTEGER ::   IMSTR
      INTEGER ::   IMVEG
      INTEGER ::   INPRIN
      INTEGER ::   IPFLAG
	  INTEGER ::   IPR
      INTEGER ::   IPSOIL
      INTEGER ::   IRIGNO
      INTEGER ::   IRRSCH
      INTEGER ::   IRRTYP
      INTEGER ::   ISCODE
      INTEGER ::   ISIM
	  INTEGER ::   ISOIL
      INTEGER ::   ITC
      INTEGER ::   ITERRC
      INTEGER ::   ITFLAG
      INTEGER ::   ITILTM(20)
      INTEGER ::   IYEAR
      INTEGER ::   IYIELD
      INTEGER ::   IZONE
      INTEGER ::   J
      INTEGER ::   JDAY
      INTEGER ::   JDFREQ
	  INTEGER ::   JDSCH
      INTEGER ::   JDYBG
      INTEGER ::   JDYCUT(5)
      INTEGER ::   JDYEFC
      INTEGER ::   JDYEND
      INTEGER ::   JDYFLO
      INTEGER ::   JDYFRZ
      INTEGER ::   JDYMAT
      INTEGER ::   JDYPLT
      INTEGER ::   JDYRIPE
      INTEGER ::   JDYSTP
      INTEGER ::   JDYSTR
      INTEGER ::   JDYVEG
      INTEGER ::   JFIRST
      INTEGER ::   JFPLT
      INTEGER ::   JGOI
	  INTEGER ::   JPRSTP
	  INTEGER ::   JPRSTR
      INTEGER ::   JSTOPI
      INTEGER ::   JULDAY
      INTEGER ::   K
      INTEGER ::   KIRR
      INTEGER ::   KSTG
	  INTEGER ::   LASTYR
      INTEGER ::   LAYERS
	  INTEGER ::   LIVECOND
      INTEGER ::   LIVECROP
      INTEGER ::   NCUT
      INTEGER ::   NDAYS
      INTEGER ::   NDEF
	  INTEGER ::   NFDAY
	  INTEGER ::   NMUID
      INTEGER ::   NORUNS
	  INTEGER ::   NPRSITE
      INTEGER ::   NTILLS
      INTEGER ::   NUMIRR(12)
      INTEGER ::   OLDCRP
	  INTEGER ::   OUTPUTFORMAT	!1=COHYST  2=REPUBLICAN RIVER (original v7)	
      INTEGER ::   RESTYP(22)
      INTEGER ::   SOIL
	  INTEGER ::   SOILSIM(28)
	  INTEGER ::   SOILTYP(28)
      INTEGER ::   TILCOD(20)
      INTEGER ::   TILDAY(20)
      INTEGER ::   YR(3500)
	  INTEGER ::   YEAR1
	  INTEGER ::   YTREND
	  INTEGER ::   ZZ		!Added for Annual RO


      CHARACTER*50 BLOCFILE   
	  CHARACTER*50 CNTRFILE  
	  CHARACTER*2  COLSH 
	  CHARACTER*50 CROPFILE
      CHARACTER*50 DIR
	  CHARACTER*50 DRIVE
      CHARACTER*21 ETHEAD
      CHARACTER*50 FDFILE
      CHARACTER*8  ICROP(22)
	  CHARACTER*50 INITFILE
      CHARACTER*1  INUMS(10)
      CHARACTER*10 ITYPE(5)
	  CHARACTER*8  LASTSIMF
      CHARACTER*1  LOCATE(80)
	  CHARACTER*4  PRSITE(8)
	  CHARACTER*4  NWSSITE
      CHARACTER*8  OEXT
      CHARACTER*50 OUTDIR
      CHARACTER*50 PROFILE
	  CHARACTER*50 PRTFILE
      CHARACTER*4  SIM
      CHARACTER*8  SIMFILE(3500)
	  CHARACTER*60 SOILFILE
	  CHARACTER*3  SOILNAM(28)
	  CHARACTER*55 SOILPROP
      CHARACTER*21 TILTYP(80)
	  CHARACTER*50 TILLFILE
      CHARACTER*4  TXT
      CHARACTER*50 WEAFILE(3500)
      CHARACTER*4  WSITE
	  CHARACTER*50 WSITEDIR
	  CHARACTER*4  YRFILE
	  CHARACTER*50 ZONE(5)

	  DATA CROPFILE/'Cropping2013.csv'/
      DATA CNTRFILE/'CSMODEL\WsiteInfo_ALL2013.txt'/
      
	  DATA COLSH/''/
      DATA SIM/'.SIM'/
      DATA OEXT/'_OUT.TXT'/
      DATA TXT/'.TXT'/
!	  DATA BLOCFILE/'CROPSIM\INPUTFILES\BLOCK.DAT'/
	  DATA BLOCFILE/'CSMODEL\BLOCK.DAT'/
!	  DATA CNTRFILE/'WEATHER\NWSFILES\WSITESINFO_ISAAC'/
!     DATA DIR/'WEATHER\NWSFILES\WEA\'/
	  DATA DIR/'CSMODEL\WEA\'/
!	  DATA INITFILE/'CROPSIM\INPUTFILES\INITIAL1.DAT'/
	  DATA INITFILE/'CSMODEL\INITIAL.DAT'/
	  DATA SOILPROP/'CSMODEL\SOIL\NESOILS.DAT'/
      
	  DATA PRTFILE/'CSMODEL\PRFILE'/

!     DATA SOILFILE/'CROPSIM\INPUTFILES\WOPTSOIL.CSV'/
	  DATA SOILFILE/'CSMODEL\SOIL\NE_allsoil.CSV'/
!	  DATA SOILFILE/'CSMODEL\SOIL\STNxSOIL_R10.CSV'/

	  DATA TILLFILE/'CSMODEL\TILLAGE.DAT'/

      DATA OUTDIR /'Results\Update2013\98\'/
      DATA PROFILE/'RESULTS\PROFILE.TXT'/

      DATA ZONE/  'CSModel\SIM\98\ZONE1\',                         &
				  'CSModel\SIM\98\ZONE2\',                         &
				  'CSModel\SIM\98\ZONE3\',                         &
				  'CSModel\SIM\98\ZONE4\',                         &
				  'CSModel\SIM\98\ZONE5\'    /                     

!                 'CROPSIM\ZONES\ZONE2\',                         &
!                 'CROPSIM\ZONES\ZONE3\',                         &
!                 'CROPSIM\ZONES\ZONE4\',                         &
!                 'CROPSIM\ZONES\ZONE5\'     /

      DATA ITYPE/'DRYLAND','HISTORIC.','C. PIVOT','FURROWS',         &
        'BORDER/C'/

      DATA ICROP/'SM.GRAIN','ED BEANS','SOYBEANS','POTATOES',        &
        'S. BEETS','SORGHUM','W. WHEAT','CORN','SUNFLOWR','ALFALFA', &
        'IRR HAY','IRR PAST','N. RANGE','TURF','FALLOW','R. WOODS',  &
        'NR. WOOD','CATTAILS','REED/RUSH','SHAL H2O','DEEP H2O',     &
        'FARMSTED'/

      DATA INUMS/'0','1','2','3','4','5','6','7','8','9'/

	  DATA SOILTYP/411,412,421,422,431,432,442,512,521,522,532,542,612,621,	 &
				   622,631,632,642,721,722,731,732,821,822,831,832,  &
				   921,922/

	  DATA SOILNAM/'411','412','421','422','431','432','442','512','521',	 &
	               '522','532','542','612','621','622','631','632','642',  &
				   '721','722','731','732','821','822','831','832',  &
				   '921','922'/


	  DATA DCOFSOIL/28*0.50/


	  DATA DDAYSOIL/2.0, 2.0, 2.0, 2.0, 4.0, 4.0, 6.0, 2.0, 2.0, 2.0, 4.0, &
	                6.0, 3.0, 3.0, 3.0, 4.0, 4.0, 6.0, 3.0, 3.0, 4.0, 4.0, &
				    4.0, 4.0, 6.0, 6.0, 4.0, 4.0/


	  DATA DRIVE/'S:\Cropsim\Run004\'/

	  DATA OUTPUTFORMAT/1/		!1=COHYST	2=REPUBLICAN RIVER (oringal v7 format)

!LIB  ---- Library-mode state (added by tools/make_engine.py) ----
      LOGICAL ::   LIBMODE = .FALSE.   !LIB  .TRUE. when called through cropsim_api
      INTEGER ::   CS_STATUS = 0       !LIB  first error code raised in library mode
      INTEGER ::   WX_NDAYS            !LIB  number of daily weather values supplied
      REAL ::      WX_TMAX(366)        !LIB  daily weather supplied by the caller,
      REAL ::      WX_TMIN(366)        !LIB  starting on the weather start day
      REAL ::      WX_PRECIP(366)      !LIB
      REAL ::      WX_EPAN(366)        !LIB
      REAL ::      WX_ETR(366)         !LIB
      END MODULE PARM

!LIB  ---- Generated by tools/make_engine.py ----
!LIB  Saved copy of every MODULE PARM variable. PARM_SAVE is called once
!LIB  the block and tillage parameters are set; PARM_RESTORE before each
!LIB  library run, so a run never sees values left by an earlier run.
      MODULE PARM_SNAPSHOT
      USE PARM
      REAL :: S_AIRDRY(2)
      REAL :: S_AIRMAX
      REAL :: S_AIRMIN
      REAL :: S_ALPHA1
      REAL :: S_APMAX(5)
      REAL :: S_APMIN(5)
      REAL :: S_AWATER
      REAL :: S_AWDPLN
      REAL :: S_AVMFT(10)
      REAL :: S_BOTDEP
      REAL :: S_BULKD
      REAL :: S_BVALUE
      REAL :: S_CC(22,3,10)
      REAL :: S_CENTER(10)
      REAL :: S_CHAND
      REAL :: S_CHANW
      REAL :: S_CROPKC(366)
      REAL :: S_CN(22,4)
      REAL :: S_CNFALLOW(4)
      REAL :: S_CUME
      REAL :: S_CURVNO
      REAL :: S_CURVN1
      REAL :: S_CURVN3
      REAL :: S_D
      REAL :: S_DCOEFF
      REAL :: S_DCOFSOIL(28)
      REAL :: S_DDAYSOIL(28)
      REAL :: S_DDEPTH
      REAL :: S_DEPL(10)
      REAL :: S_DEPTH(10)
      REAL :: S_DINF
      REAL :: S_DPLA
      REAL :: S_DPLBG
      REAL :: S_DPLMON(12)
      REAL :: S_DPLN
      REAL :: S_DPLPER
      REAL :: S_DRAIND
      REAL :: S_DRAINS
      REAL :: S_DRAMON(12)
      REAL :: S_DRNCOE
      REAL :: S_DRNDAY
      REAL :: S_DRNIN
      REAL :: S_E1
      REAL :: S_E2
      REAL :: S_EAPP(5)
      REAL :: S_EIN
      REAL :: S_ELEV
      REAL :: S_EMON(12)
      REAL :: S_EP
      REAL :: S_EPAN(366)
      REAL :: S_EPRECIP
      REAL :: S_EPRECIPS
      REAL :: S_EREUSE(5)
      REAL :: S_ERMON(12)
      REAL :: S_ES
      REAL :: S_ETIN
      REAL :: S_ETRFACT
      REAL :: S_ETMAX
      REAL :: S_ETMON(12)
      REAL :: S_ETR(366)
      REAL :: S_ETRA
      REAL :: S_ETRIN
      REAL :: S_ETRMON(12)
      REAL :: S_ETRS
      REAL :: S_ETS
      REAL :: S_ETYLD
      REAL :: S_EVEG
      REAL :: S_FC
      REAL :: S_FDEPTH
      REAL :: S_FDIRRIG(50, 4)
      REAL :: S_FIELDC(10)
      REAL :: S_FORCRAIN
      REAL :: S_GDD
      REAL :: S_GDDEFC
      REAL :: S_GDDFLO
      REAL :: S_GDDMAT
      REAL :: S_GDDRIPE
      REAL :: S_GDDROOT
      REAL :: S_GDDS(366)
      REAL :: S_GDDVEG
      REAL :: S_GROIRR
      REAL :: S_GRZROT
      REAL :: S_GSTART
      REAL :: S_GSTOP
      REAL :: S_GYFORM
      REAL :: S_INFMON(12)
      REAL :: S_IPER(5)
      REAL :: S_IRGMON(12)
      REAL :: S_IRNMON(12)
      REAL :: S_JNEXTI
      REAL :: S_KC
      REAL :: S_KCL(22)
      REAL :: S_KCU(22)
      REAL :: S_LAT
      REAL :: S_LONG
      REAL :: S_NETIRR
      REAL :: S_OLDRES
      REAL :: S_ORGM
      REAL :: S_PAD(5)
      REAL :: S_PAW
      REAL :: S_PAWFT(10)
      REAL :: S_PERDEP(10)
      REAL :: S_PERRZD(10)
      REAL :: S_PRECIP(366)
      REAL :: S_PRECIPA
      REAL :: S_PRECIPS
      REAL :: S_PRUNOF(5)
      REAL :: S_PWP(10)
      REAL :: S_RAIN
      REAL :: S_RAINAL(5)
      REAL :: S_RAMON(12)
      REAL :: S_RDEPTH
      REAL :: S_RDF(10)
      REAL :: S_RESIDUE
      REAL :: S_RESRAT(22)
      REAL :: S_RESREM
      REAL :: S_RNIN
      REAL :: S_ROFMON(12)
      REAL :: S_RONMON(12)
      REAL :: S_RRUNOFF
      REAL :: S_RUNOFF
      REAL :: S_RUNON
      REAL :: S_RZD
      REAL :: S_RZFACT
      REAL :: S_RZMAX
      REAL :: S_RZMGMT
      REAL :: S_RZMIN
      REAL :: S_SATWC
      REAL :: S_SAT
      REAL :: S_SFTMP
      REAL :: S_SGRIRR
      REAL :: S_SMALLI(5)
      REAL :: S_SMAX
      REAL :: S_SMFMX
      REAL :: S_SMFMN
      REAL :: S_SMTMP
      REAL :: S_SNIRR
      REAL :: S_SNOCOV
      REAL :: S_SNOCOVMX
      REAL :: S_SNOCOV1
      REAL :: S_SNOCOV2
      REAL :: S_SNOFALL
      REAL :: S_SNOH2O
      REAL :: S_SNOMLT
      REAL :: S_SNOTMP
      REAL :: S_SOILRAD
      REAL :: S_SOILRZ
      REAL :: S_SOILT(10)
      REAL :: S_SOLAR(366)
      REAL :: S_SPGRAV(22)
      REAL :: S_SURFTEMP
      REAL :: S_SW
      REAL :: S_SYSCAP
      REAL :: S_S3
      REAL :: S_T1
      REAL :: S_T2
      REAL :: S_TAMP
      REAL :: S_TANUAL
      REAL :: S_TAVG
      REAL :: S_TBARE
      REAL :: S_TBASE(22)
      REAL :: S_TBREAK
      REAL :: S_TCEIL(22)
      REAL :: S_TDEF(5)
      REAL :: S_TDEFS
      REAL :: S_THETA(10)
      REAL :: S_TILFAC(80,2)
      REAL :: S_TIME
      REAL :: S_TIMP
      REAL :: S_TIN
      REAL :: S_TINTRV
      REAL :: S_TMAX(366)
      REAL :: S_TMAXA
      REAL :: S_TMIN(366)
      REAL :: S_TMINA
      REAL :: S_TMON(12)
      REAL :: S_TODAY
      REAL :: S_TOPDEP
      REAL :: S_TOTDEP
      REAL :: S_TOTWAT
      REAL :: S_TPS(5)
      REAL :: S_TS
      REAL :: S_TVEG
      REAL :: S_WINF
      REAL :: S_YACT
      REAL :: S_YCOEFF
      REAL :: S_YDENS(22)
      REAL :: S_YIELD
      REAL :: S_YLDRATIO
      REAL :: S_YMAX
      REAL :: S_W1
      REAL :: S_W2
      REAL :: S_ETRWK(53)
      REAL :: S_ETWK(53)
      REAL :: S_ERWK(53)
      REAL :: S_RAWK(53)
      REAL :: S_IRNWK(53)
      REAL :: S_IRGWK(53)
      REAL :: S_TOTROF
      REAL :: S_EPMAX
      INTEGER :: S_IWEEK
      INTEGER :: S_CLIMZONE
      INTEGER :: S_CROP
      INTEGER :: S_FRAGIL(22)
      INTEGER :: S_I
      INTEGER :: S_IADD
      INTEGER :: S_IC
      INTEGER :: S_ICUT
      INTEGER :: S_IDATE
      INTEGER :: S_IDAY
      INTEGER :: S_IDBG
      INTEGER :: S_IDEFC
      INTEGER :: S_IDEND
      INTEGER :: S_IDFLO
      INTEGER :: S_IDFPLT
      INTEGER :: S_IDMAT
      INTEGER :: S_IDPLT
      INTEGER :: S_IDRIPE
      INTEGER :: S_IDSTR
      INTEGER :: S_IDVEG
      INTEGER :: S_IHYDC
      INTEGER :: S_IHYGRP
      INTEGER :: S_II
      INTEGER :: S_ILAY
      INTEGER :: S_IMBG
      INTEGER :: S_IMEFC
      INTEGER :: S_IMEND
      INTEGER :: S_IMFLO
      INTEGER :: S_IMFPLT
      INTEGER :: S_IMMAT
      INTEGER :: S_IMON
      INTEGER :: S_IMPLT
      INTEGER :: S_IMRIPE
      INTEGER :: S_IMSTR
      INTEGER :: S_IMVEG
      INTEGER :: S_INPRIN
      INTEGER :: S_IPFLAG
      INTEGER :: S_IPR
      INTEGER :: S_IPSOIL
      INTEGER :: S_IRIGNO
      INTEGER :: S_IRRSCH
      INTEGER :: S_IRRTYP
      INTEGER :: S_ISCODE
      INTEGER :: S_ISIM
      INTEGER :: S_ISOIL
      INTEGER :: S_ITC
      INTEGER :: S_ITERRC
      INTEGER :: S_ITFLAG
      INTEGER :: S_ITILTM(20)
      INTEGER :: S_IYEAR
      INTEGER :: S_IYIELD
      INTEGER :: S_IZONE
      INTEGER :: S_J
      INTEGER :: S_JDAY
      INTEGER :: S_JDFREQ
      INTEGER :: S_JDSCH
      INTEGER :: S_JDYBG
      INTEGER :: S_JDYCUT(5)
      INTEGER :: S_JDYEFC
      INTEGER :: S_JDYEND
      INTEGER :: S_JDYFLO
      INTEGER :: S_JDYFRZ
      INTEGER :: S_JDYMAT
      INTEGER :: S_JDYPLT
      INTEGER :: S_JDYRIPE
      INTEGER :: S_JDYSTP
      INTEGER :: S_JDYSTR
      INTEGER :: S_JDYVEG
      INTEGER :: S_JFIRST
      INTEGER :: S_JFPLT
      INTEGER :: S_JGOI
      INTEGER :: S_JPRSTP
      INTEGER :: S_JPRSTR
      INTEGER :: S_JSTOPI
      INTEGER :: S_JULDAY
      INTEGER :: S_K
      INTEGER :: S_KIRR
      INTEGER :: S_KSTG
      INTEGER :: S_LASTYR
      INTEGER :: S_LAYERS
      INTEGER :: S_LIVECOND
      INTEGER :: S_LIVECROP
      INTEGER :: S_NCUT
      INTEGER :: S_NDAYS
      INTEGER :: S_NDEF
      INTEGER :: S_NFDAY
      INTEGER :: S_NMUID
      INTEGER :: S_NORUNS
      INTEGER :: S_NPRSITE
      INTEGER :: S_NTILLS
      INTEGER :: S_NUMIRR(12)
      INTEGER :: S_OLDCRP
      INTEGER :: S_OUTPUTFORMAT
      INTEGER :: S_RESTYP(22)
      INTEGER :: S_SOIL
      INTEGER :: S_SOILSIM(28)
      INTEGER :: S_SOILTYP(28)
      INTEGER :: S_TILCOD(20)
      INTEGER :: S_TILDAY(20)
      INTEGER :: S_YR(3500)
      INTEGER :: S_YEAR1
      INTEGER :: S_YTREND
      INTEGER :: S_ZZ
      CHARACTER*50 S_BLOCFILE
      CHARACTER*50 S_CNTRFILE
      CHARACTER*2 S_COLSH
      CHARACTER*50 S_CROPFILE
      CHARACTER*50 S_DIR
      CHARACTER*50 S_DRIVE
      CHARACTER*21 S_ETHEAD
      CHARACTER*50 S_FDFILE
      CHARACTER*8 S_ICROP(22)
      CHARACTER*50 S_INITFILE
      CHARACTER*1 S_INUMS(10)
      CHARACTER*10 S_ITYPE(5)
      CHARACTER*8 S_LASTSIMF
      CHARACTER*1 S_LOCATE(80)
      CHARACTER*4 S_PRSITE(8)
      CHARACTER*4 S_NWSSITE
      CHARACTER*8 S_OEXT
      CHARACTER*50 S_OUTDIR
      CHARACTER*50 S_PROFILE
      CHARACTER*50 S_PRTFILE
      CHARACTER*4 S_SIM
      CHARACTER*8 S_SIMFILE(3500)
      CHARACTER*60 S_SOILFILE
      CHARACTER*3 S_SOILNAM(28)
      CHARACTER*55 S_SOILPROP
      CHARACTER*21 S_TILTYP(80)
      CHARACTER*50 S_TILLFILE
      CHARACTER*4 S_TXT
      CHARACTER*50 S_WEAFILE(3500)
      CHARACTER*4 S_WSITE
      CHARACTER*50 S_WSITEDIR
      CHARACTER*4 S_YRFILE
      CHARACTER*50 S_ZONE(5)
      CONTAINS
      SUBROUTINE PARM_SAVE
      S_AIRDRY = AIRDRY
      S_AIRMAX = AIRMAX
      S_AIRMIN = AIRMIN
      S_ALPHA1 = ALPHA1
      S_APMAX = APMAX
      S_APMIN = APMIN
      S_AWATER = AWATER
      S_AWDPLN = AWDPLN
      S_AVMFT = AVMFT
      S_BOTDEP = BOTDEP
      S_BULKD = BULKD
      S_BVALUE = BVALUE
      S_CC = CC
      S_CENTER = CENTER
      S_CHAND = CHAND
      S_CHANW = CHANW
      S_CROPKC = CROPKC
      S_CN = CN
      S_CNFALLOW = CNFALLOW
      S_CUME = CUME
      S_CURVNO = CURVNO
      S_CURVN1 = CURVN1
      S_CURVN3 = CURVN3
      S_D = D
      S_DCOEFF = DCOEFF
      S_DCOFSOIL = DCOFSOIL
      S_DDAYSOIL = DDAYSOIL
      S_DDEPTH = DDEPTH
      S_DEPL = DEPL
      S_DEPTH = DEPTH
      S_DINF = DINF
      S_DPLA = DPLA
      S_DPLBG = DPLBG
      S_DPLMON = DPLMON
      S_DPLN = DPLN
      S_DPLPER = DPLPER
      S_DRAIND = DRAIND
      S_DRAINS = DRAINS
      S_DRAMON = DRAMON
      S_DRNCOE = DRNCOE
      S_DRNDAY = DRNDAY
      S_DRNIN = DRNIN
      S_E1 = E1
      S_E2 = E2
      S_EAPP = EAPP
      S_EIN = EIN
      S_ELEV = ELEV
      S_EMON = EMON
      S_EP = EP
      S_EPAN = EPAN
      S_EPRECIP = EPRECIP
      S_EPRECIPS = EPRECIPS
      S_EREUSE = EREUSE
      S_ERMON = ERMON
      S_ES = ES
      S_ETIN = ETIN
      S_ETRFACT = ETRFACT
      S_ETMAX = ETMAX
      S_ETMON = ETMON
      S_ETR = ETR
      S_ETRA = ETRA
      S_ETRIN = ETRIN
      S_ETRMON = ETRMON
      S_ETRS = ETRS
      S_ETS = ETS
      S_ETYLD = ETYLD
      S_EVEG = EVEG
      S_FC = FC
      S_FDEPTH = FDEPTH
      S_FDIRRIG = FDIRRIG
      S_FIELDC = FIELDC
      S_FORCRAIN = FORCRAIN
      S_GDD = GDD
      S_GDDEFC = GDDEFC
      S_GDDFLO = GDDFLO
      S_GDDMAT = GDDMAT
      S_GDDRIPE = GDDRIPE
      S_GDDROOT = GDDROOT
      S_GDDS = GDDS
      S_GDDVEG = GDDVEG
      S_GROIRR = GROIRR
      S_GRZROT = GRZROT
      S_GSTART = GSTART
      S_GSTOP = GSTOP
      S_GYFORM = GYFORM
      S_INFMON = INFMON
      S_IPER = IPER
      S_IRGMON = IRGMON
      S_IRNMON = IRNMON
      S_JNEXTI = JNEXTI
      S_KC = KC
      S_KCL = KCL
      S_KCU = KCU
      S_LAT = LAT
      S_LONG = LONG
      S_NETIRR = NETIRR
      S_OLDRES = OLDRES
      S_ORGM = ORGM
      S_PAD = PAD
      S_PAW = PAW
      S_PAWFT = PAWFT
      S_PERDEP = PERDEP
      S_PERRZD = PERRZD
      S_PRECIP = PRECIP
      S_PRECIPA = PRECIPA
      S_PRECIPS = PRECIPS
      S_PRUNOF = PRUNOF
      S_PWP = PWP
      S_RAIN = RAIN
      S_RAINAL = RAINAL
      S_RAMON = RAMON
      S_RDEPTH = RDEPTH
      S_RDF = RDF
      S_RESIDUE = RESIDUE
      S_RESRAT = RESRAT
      S_RESREM = RESREM
      S_RNIN = RNIN
      S_ROFMON = ROFMON
      S_RONMON = RONMON
      S_RRUNOFF = RRUNOFF
      S_RUNOFF = RUNOFF
      S_RUNON = RUNON
      S_RZD = RZD
      S_RZFACT = RZFACT
      S_RZMAX = RZMAX
      S_RZMGMT = RZMGMT
      S_RZMIN = RZMIN
      S_SATWC = SATWC
      S_SAT = SAT
      S_SFTMP = SFTMP
      S_SGRIRR = SGRIRR
      S_SMALLI = SMALLI
      S_SMAX = SMAX
      S_SMFMX = SMFMX
      S_SMFMN = SMFMN
      S_SMTMP = SMTMP
      S_SNIRR = SNIRR
      S_SNOCOV = SNOCOV
      S_SNOCOVMX = SNOCOVMX
      S_SNOCOV1 = SNOCOV1
      S_SNOCOV2 = SNOCOV2
      S_SNOFALL = SNOFALL
      S_SNOH2O = SNOH2O
      S_SNOMLT = SNOMLT
      S_SNOTMP = SNOTMP
      S_SOILRAD = SOILRAD
      S_SOILRZ = SOILRZ
      S_SOILT = SOILT
      S_SOLAR = SOLAR
      S_SPGRAV = SPGRAV
      S_SURFTEMP = SURFTEMP
      S_SW = SW
      S_SYSCAP = SYSCAP
      S_S3 = S3
      S_T1 = T1
      S_T2 = T2
      S_TAMP = TAMP
      S_TANUAL = TANUAL
      S_TAVG = TAVG
      S_TBARE = TBARE
      S_TBASE = TBASE
      S_TBREAK = TBREAK
      S_TCEIL = TCEIL
      S_TDEF = TDEF
      S_TDEFS = TDEFS
      S_THETA = THETA
      S_TILFAC = TILFAC
      S_TIME = TIME
      S_TIMP = TIMP
      S_TIN = TIN
      S_TINTRV = TINTRV
      S_TMAX = TMAX
      S_TMAXA = TMAXA
      S_TMIN = TMIN
      S_TMINA = TMINA
      S_TMON = TMON
      S_TODAY = TODAY
      S_TOPDEP = TOPDEP
      S_TOTDEP = TOTDEP
      S_TOTWAT = TOTWAT
      S_TPS = TPS
      S_TS = TS
      S_TVEG = TVEG
      S_WINF = WINF
      S_YACT = YACT
      S_YCOEFF = YCOEFF
      S_YDENS = YDENS
      S_YIELD = YIELD
      S_YLDRATIO = YLDRATIO
      S_YMAX = YMAX
      S_W1 = W1
      S_W2 = W2
      S_ETRWK = ETRWK
      S_ETWK = ETWK
      S_ERWK = ERWK
      S_RAWK = RAWK
      S_IRNWK = IRNWK
      S_IRGWK = IRGWK
      S_TOTROF = TOTROF
      S_EPMAX = EPMAX
      S_IWEEK = IWEEK
      S_CLIMZONE = CLIMZONE
      S_CROP = CROP
      S_FRAGIL = FRAGIL
      S_I = I
      S_IADD = IADD
      S_IC = IC
      S_ICUT = ICUT
      S_IDATE = IDATE
      S_IDAY = IDAY
      S_IDBG = IDBG
      S_IDEFC = IDEFC
      S_IDEND = IDEND
      S_IDFLO = IDFLO
      S_IDFPLT = IDFPLT
      S_IDMAT = IDMAT
      S_IDPLT = IDPLT
      S_IDRIPE = IDRIPE
      S_IDSTR = IDSTR
      S_IDVEG = IDVEG
      S_IHYDC = IHYDC
      S_IHYGRP = IHYGRP
      S_II = II
      S_ILAY = ILAY
      S_IMBG = IMBG
      S_IMEFC = IMEFC
      S_IMEND = IMEND
      S_IMFLO = IMFLO
      S_IMFPLT = IMFPLT
      S_IMMAT = IMMAT
      S_IMON = IMON
      S_IMPLT = IMPLT
      S_IMRIPE = IMRIPE
      S_IMSTR = IMSTR
      S_IMVEG = IMVEG
      S_INPRIN = INPRIN
      S_IPFLAG = IPFLAG
      S_IPR = IPR
      S_IPSOIL = IPSOIL
      S_IRIGNO = IRIGNO
      S_IRRSCH = IRRSCH
      S_IRRTYP = IRRTYP
      S_ISCODE = ISCODE
      S_ISIM = ISIM
      S_ISOIL = ISOIL
      S_ITC = ITC
      S_ITERRC = ITERRC
      S_ITFLAG = ITFLAG
      S_ITILTM = ITILTM
      S_IYEAR = IYEAR
      S_IYIELD = IYIELD
      S_IZONE = IZONE
      S_J = J
      S_JDAY = JDAY
      S_JDFREQ = JDFREQ
      S_JDSCH = JDSCH
      S_JDYBG = JDYBG
      S_JDYCUT = JDYCUT
      S_JDYEFC = JDYEFC
      S_JDYEND = JDYEND
      S_JDYFLO = JDYFLO
      S_JDYFRZ = JDYFRZ
      S_JDYMAT = JDYMAT
      S_JDYPLT = JDYPLT
      S_JDYRIPE = JDYRIPE
      S_JDYSTP = JDYSTP
      S_JDYSTR = JDYSTR
      S_JDYVEG = JDYVEG
      S_JFIRST = JFIRST
      S_JFPLT = JFPLT
      S_JGOI = JGOI
      S_JPRSTP = JPRSTP
      S_JPRSTR = JPRSTR
      S_JSTOPI = JSTOPI
      S_JULDAY = JULDAY
      S_K = K
      S_KIRR = KIRR
      S_KSTG = KSTG
      S_LASTYR = LASTYR
      S_LAYERS = LAYERS
      S_LIVECOND = LIVECOND
      S_LIVECROP = LIVECROP
      S_NCUT = NCUT
      S_NDAYS = NDAYS
      S_NDEF = NDEF
      S_NFDAY = NFDAY
      S_NMUID = NMUID
      S_NORUNS = NORUNS
      S_NPRSITE = NPRSITE
      S_NTILLS = NTILLS
      S_NUMIRR = NUMIRR
      S_OLDCRP = OLDCRP
      S_OUTPUTFORMAT = OUTPUTFORMAT
      S_RESTYP = RESTYP
      S_SOIL = SOIL
      S_SOILSIM = SOILSIM
      S_SOILTYP = SOILTYP
      S_TILCOD = TILCOD
      S_TILDAY = TILDAY
      S_YR = YR
      S_YEAR1 = YEAR1
      S_YTREND = YTREND
      S_ZZ = ZZ
      S_BLOCFILE = BLOCFILE
      S_CNTRFILE = CNTRFILE
      S_COLSH = COLSH
      S_CROPFILE = CROPFILE
      S_DIR = DIR
      S_DRIVE = DRIVE
      S_ETHEAD = ETHEAD
      S_FDFILE = FDFILE
      S_ICROP = ICROP
      S_INITFILE = INITFILE
      S_INUMS = INUMS
      S_ITYPE = ITYPE
      S_LASTSIMF = LASTSIMF
      S_LOCATE = LOCATE
      S_PRSITE = PRSITE
      S_NWSSITE = NWSSITE
      S_OEXT = OEXT
      S_OUTDIR = OUTDIR
      S_PROFILE = PROFILE
      S_PRTFILE = PRTFILE
      S_SIM = SIM
      S_SIMFILE = SIMFILE
      S_SOILFILE = SOILFILE
      S_SOILNAM = SOILNAM
      S_SOILPROP = SOILPROP
      S_TILTYP = TILTYP
      S_TILLFILE = TILLFILE
      S_TXT = TXT
      S_WEAFILE = WEAFILE
      S_WSITE = WSITE
      S_WSITEDIR = WSITEDIR
      S_YRFILE = YRFILE
      S_ZONE = ZONE
      END SUBROUTINE PARM_SAVE
      SUBROUTINE PARM_RESTORE
      AIRDRY = S_AIRDRY
      AIRMAX = S_AIRMAX
      AIRMIN = S_AIRMIN
      ALPHA1 = S_ALPHA1
      APMAX = S_APMAX
      APMIN = S_APMIN
      AWATER = S_AWATER
      AWDPLN = S_AWDPLN
      AVMFT = S_AVMFT
      BOTDEP = S_BOTDEP
      BULKD = S_BULKD
      BVALUE = S_BVALUE
      CC = S_CC
      CENTER = S_CENTER
      CHAND = S_CHAND
      CHANW = S_CHANW
      CROPKC = S_CROPKC
      CN = S_CN
      CNFALLOW = S_CNFALLOW
      CUME = S_CUME
      CURVNO = S_CURVNO
      CURVN1 = S_CURVN1
      CURVN3 = S_CURVN3
      D = S_D
      DCOEFF = S_DCOEFF
      DCOFSOIL = S_DCOFSOIL
      DDAYSOIL = S_DDAYSOIL
      DDEPTH = S_DDEPTH
      DEPL = S_DEPL
      DEPTH = S_DEPTH
      DINF = S_DINF
      DPLA = S_DPLA
      DPLBG = S_DPLBG
      DPLMON = S_DPLMON
      DPLN = S_DPLN
      DPLPER = S_DPLPER
      DRAIND = S_DRAIND
      DRAINS = S_DRAINS
      DRAMON = S_DRAMON
      DRNCOE = S_DRNCOE
      DRNDAY = S_DRNDAY
      DRNIN = S_DRNIN
      E1 = S_E1
      E2 = S_E2
      EAPP = S_EAPP
      EIN = S_EIN
      ELEV = S_ELEV
      EMON = S_EMON
      EP = S_EP
      EPAN = S_EPAN
      EPRECIP = S_EPRECIP
      EPRECIPS = S_EPRECIPS
      EREUSE = S_EREUSE
      ERMON = S_ERMON
      ES = S_ES
      ETIN = S_ETIN
      ETRFACT = S_ETRFACT
      ETMAX = S_ETMAX
      ETMON = S_ETMON
      ETR = S_ETR
      ETRA = S_ETRA
      ETRIN = S_ETRIN
      ETRMON = S_ETRMON
      ETRS = S_ETRS
      ETS = S_ETS
      ETYLD = S_ETYLD
      EVEG = S_EVEG
      FC = S_FC
      FDEPTH = S_FDEPTH
      FDIRRIG = S_FDIRRIG
      FIELDC = S_FIELDC
      FORCRAIN = S_FORCRAIN
      GDD = S_GDD
      GDDEFC = S_GDDEFC
      GDDFLO = S_GDDFLO
      GDDMAT = S_GDDMAT
      GDDRIPE = S_GDDRIPE
      GDDROOT = S_GDDROOT
      GDDS = S_GDDS
      GDDVEG = S_GDDVEG
      GROIRR = S_GROIRR
      GRZROT = S_GRZROT
      GSTART = S_GSTART
      GSTOP = S_GSTOP
      GYFORM = S_GYFORM
      INFMON = S_INFMON
      IPER = S_IPER
      IRGMON = S_IRGMON
      IRNMON = S_IRNMON
      JNEXTI = S_JNEXTI
      KC = S_KC
      KCL = S_KCL
      KCU = S_KCU
      LAT = S_LAT
      LONG = S_LONG
      NETIRR = S_NETIRR
      OLDRES = S_OLDRES
      ORGM = S_ORGM
      PAD = S_PAD
      PAW = S_PAW
      PAWFT = S_PAWFT
      PERDEP = S_PERDEP
      PERRZD = S_PERRZD
      PRECIP = S_PRECIP
      PRECIPA = S_PRECIPA
      PRECIPS = S_PRECIPS
      PRUNOF = S_PRUNOF
      PWP = S_PWP
      RAIN = S_RAIN
      RAINAL = S_RAINAL
      RAMON = S_RAMON
      RDEPTH = S_RDEPTH
      RDF = S_RDF
      RESIDUE = S_RESIDUE
      RESRAT = S_RESRAT
      RESREM = S_RESREM
      RNIN = S_RNIN
      ROFMON = S_ROFMON
      RONMON = S_RONMON
      RRUNOFF = S_RRUNOFF
      RUNOFF = S_RUNOFF
      RUNON = S_RUNON
      RZD = S_RZD
      RZFACT = S_RZFACT
      RZMAX = S_RZMAX
      RZMGMT = S_RZMGMT
      RZMIN = S_RZMIN
      SATWC = S_SATWC
      SAT = S_SAT
      SFTMP = S_SFTMP
      SGRIRR = S_SGRIRR
      SMALLI = S_SMALLI
      SMAX = S_SMAX
      SMFMX = S_SMFMX
      SMFMN = S_SMFMN
      SMTMP = S_SMTMP
      SNIRR = S_SNIRR
      SNOCOV = S_SNOCOV
      SNOCOVMX = S_SNOCOVMX
      SNOCOV1 = S_SNOCOV1
      SNOCOV2 = S_SNOCOV2
      SNOFALL = S_SNOFALL
      SNOH2O = S_SNOH2O
      SNOMLT = S_SNOMLT
      SNOTMP = S_SNOTMP
      SOILRAD = S_SOILRAD
      SOILRZ = S_SOILRZ
      SOILT = S_SOILT
      SOLAR = S_SOLAR
      SPGRAV = S_SPGRAV
      SURFTEMP = S_SURFTEMP
      SW = S_SW
      SYSCAP = S_SYSCAP
      S3 = S_S3
      T1 = S_T1
      T2 = S_T2
      TAMP = S_TAMP
      TANUAL = S_TANUAL
      TAVG = S_TAVG
      TBARE = S_TBARE
      TBASE = S_TBASE
      TBREAK = S_TBREAK
      TCEIL = S_TCEIL
      TDEF = S_TDEF
      TDEFS = S_TDEFS
      THETA = S_THETA
      TILFAC = S_TILFAC
      TIME = S_TIME
      TIMP = S_TIMP
      TIN = S_TIN
      TINTRV = S_TINTRV
      TMAX = S_TMAX
      TMAXA = S_TMAXA
      TMIN = S_TMIN
      TMINA = S_TMINA
      TMON = S_TMON
      TODAY = S_TODAY
      TOPDEP = S_TOPDEP
      TOTDEP = S_TOTDEP
      TOTWAT = S_TOTWAT
      TPS = S_TPS
      TS = S_TS
      TVEG = S_TVEG
      WINF = S_WINF
      YACT = S_YACT
      YCOEFF = S_YCOEFF
      YDENS = S_YDENS
      YIELD = S_YIELD
      YLDRATIO = S_YLDRATIO
      YMAX = S_YMAX
      W1 = S_W1
      W2 = S_W2
      ETRWK = S_ETRWK
      ETWK = S_ETWK
      ERWK = S_ERWK
      RAWK = S_RAWK
      IRNWK = S_IRNWK
      IRGWK = S_IRGWK
      TOTROF = S_TOTROF
      EPMAX = S_EPMAX
      IWEEK = S_IWEEK
      CLIMZONE = S_CLIMZONE
      CROP = S_CROP
      FRAGIL = S_FRAGIL
      I = S_I
      IADD = S_IADD
      IC = S_IC
      ICUT = S_ICUT
      IDATE = S_IDATE
      IDAY = S_IDAY
      IDBG = S_IDBG
      IDEFC = S_IDEFC
      IDEND = S_IDEND
      IDFLO = S_IDFLO
      IDFPLT = S_IDFPLT
      IDMAT = S_IDMAT
      IDPLT = S_IDPLT
      IDRIPE = S_IDRIPE
      IDSTR = S_IDSTR
      IDVEG = S_IDVEG
      IHYDC = S_IHYDC
      IHYGRP = S_IHYGRP
      II = S_II
      ILAY = S_ILAY
      IMBG = S_IMBG
      IMEFC = S_IMEFC
      IMEND = S_IMEND
      IMFLO = S_IMFLO
      IMFPLT = S_IMFPLT
      IMMAT = S_IMMAT
      IMON = S_IMON
      IMPLT = S_IMPLT
      IMRIPE = S_IMRIPE
      IMSTR = S_IMSTR
      IMVEG = S_IMVEG
      INPRIN = S_INPRIN
      IPFLAG = S_IPFLAG
      IPR = S_IPR
      IPSOIL = S_IPSOIL
      IRIGNO = S_IRIGNO
      IRRSCH = S_IRRSCH
      IRRTYP = S_IRRTYP
      ISCODE = S_ISCODE
      ISIM = S_ISIM
      ISOIL = S_ISOIL
      ITC = S_ITC
      ITERRC = S_ITERRC
      ITFLAG = S_ITFLAG
      ITILTM = S_ITILTM
      IYEAR = S_IYEAR
      IYIELD = S_IYIELD
      IZONE = S_IZONE
      J = S_J
      JDAY = S_JDAY
      JDFREQ = S_JDFREQ
      JDSCH = S_JDSCH
      JDYBG = S_JDYBG
      JDYCUT = S_JDYCUT
      JDYEFC = S_JDYEFC
      JDYEND = S_JDYEND
      JDYFLO = S_JDYFLO
      JDYFRZ = S_JDYFRZ
      JDYMAT = S_JDYMAT
      JDYPLT = S_JDYPLT
      JDYRIPE = S_JDYRIPE
      JDYSTP = S_JDYSTP
      JDYSTR = S_JDYSTR
      JDYVEG = S_JDYVEG
      JFIRST = S_JFIRST
      JFPLT = S_JFPLT
      JGOI = S_JGOI
      JPRSTP = S_JPRSTP
      JPRSTR = S_JPRSTR
      JSTOPI = S_JSTOPI
      JULDAY = S_JULDAY
      K = S_K
      KIRR = S_KIRR
      KSTG = S_KSTG
      LASTYR = S_LASTYR
      LAYERS = S_LAYERS
      LIVECOND = S_LIVECOND
      LIVECROP = S_LIVECROP
      NCUT = S_NCUT
      NDAYS = S_NDAYS
      NDEF = S_NDEF
      NFDAY = S_NFDAY
      NMUID = S_NMUID
      NORUNS = S_NORUNS
      NPRSITE = S_NPRSITE
      NTILLS = S_NTILLS
      NUMIRR = S_NUMIRR
      OLDCRP = S_OLDCRP
      OUTPUTFORMAT = S_OUTPUTFORMAT
      RESTYP = S_RESTYP
      SOIL = S_SOIL
      SOILSIM = S_SOILSIM
      SOILTYP = S_SOILTYP
      TILCOD = S_TILCOD
      TILDAY = S_TILDAY
      YR = S_YR
      YEAR1 = S_YEAR1
      YTREND = S_YTREND
      ZZ = S_ZZ
      BLOCFILE = S_BLOCFILE
      CNTRFILE = S_CNTRFILE
      COLSH = S_COLSH
      CROPFILE = S_CROPFILE
      DIR = S_DIR
      DRIVE = S_DRIVE
      ETHEAD = S_ETHEAD
      FDFILE = S_FDFILE
      ICROP = S_ICROP
      INITFILE = S_INITFILE
      INUMS = S_INUMS
      ITYPE = S_ITYPE
      LASTSIMF = S_LASTSIMF
      LOCATE = S_LOCATE
      PRSITE = S_PRSITE
      NWSSITE = S_NWSSITE
      OEXT = S_OEXT
      OUTDIR = S_OUTDIR
      PROFILE = S_PROFILE
      PRTFILE = S_PRTFILE
      SIM = S_SIM
      SIMFILE = S_SIMFILE
      SOILFILE = S_SOILFILE
      SOILNAM = S_SOILNAM
      SOILPROP = S_SOILPROP
      TILTYP = S_TILTYP
      TILLFILE = S_TILLFILE
      TXT = S_TXT
      WEAFILE = S_WEAFILE
      WSITE = S_WSITE
      WSITEDIR = S_WSITEDIR
      YRFILE = S_YRFILE
      ZONE = S_ZONE
      END SUBROUTINE PARM_RESTORE
      END MODULE PARM_SNAPSHOT
!**********************************************************************
!
!  CROPSIMv7.f90    - CROP WATER USE MODEL
!
!   Revised 3/6/2007
!-----------------------------------------------------------------------

!LIB  PROGRAM CROPSIMv7 (original lines 555-1442) removed: the per-year
!LIB  logic is in cropsim_api.f90, subroutine CS_RUN_YEAR.







!***********************************************************************
!                       SUBROUTINE CALDAY



    SUBROUTINE CALDAY(JDAY,IMON,IDAY)

    INTEGER IDAYS(12)
    DATA IDAYS/0,31,59,90,120,151,181,212,243,273,304,334/

    DO  J=1,12
     IF(JDAY.LE.IDAYS(J)) GOTO 20
    END DO

    J=13
20  IMON=J-1
    IDAY=JDAY-IDAYS(IMON)
    IF(JDAY.LE.366) GOTO 30
    IMON=13
    IDAY=0

30  RETURN
	END SUBROUTINE CALDAY


!***********************************************************************
!                      SUBROUTINE EVAP

       SUBROUTINE EVAP

      USE PARM
      REAL ALPHA,AVAIL,AVAIL2,RESDEP,REDF

      IF(ALPHA1.NE.0.0) THEN
          ALPHA=ALPHA1
        ELSE
          ALPHA=0.303*(FIELDC(1)-AIRDRY(1))*DEPTH(1) + 0.0547
       ENDIF



       E1=0.0
       E2=0.0
       IF(EP.LE.0.0) GOTO 20
       IF(ABS(THETA(1)-AIRDRY(1)).LE.0.0001) GOTO 10

!---   Adjust Potential Evaporation By The Amount Of Residue Cover

	   IF(RESIDUE.GT.0.0) THEN
             RESDEP = 1.123E-07 * RESIDUE / SPGRAV(OLDCRP)
	         REDF = MIN(-0.99-0.236*LOG(RESDEP),1.0)
			 IF(REDF.LT.0.0) REDF = 0.0
		  ELSE
		     RESDEP = 0.0
			 REDF = 1.0
	   ENDIF

       EP = EP * REDF

!-----      Stage 1 Drying

       TIME = FLOAT(JDAY)
       AVAIL=(THETA(1)-AIRDRY(1))*DEPTH(1)
       IF(AVAIL.LT.EP) GOTO 5
       E1=EP
       GOTO 20

!-----      TRANSITION FROM STAGE 1 TO STAGE 2

5      TIME=FLOAT(JDAY-1)+AVAIL/EP
       E1=AVAIL
       E2=ALPHA*SQRT(1.0-AVAIL/EP)
       AVAIL2=(THETA(2)-AIRDRY(2))*DEPTH(2)
       IF(E2.GT.AVAIL2)E2=AVAIL2
       IF((E1+E2).LE.EP) GOTO 20
       E2=EP-E1
       TIME=FLOAT(JDAY)-(E2/ALPHA)**2.0
       GOTO 20

!-----      Stage 2 Drying

10     IF(THETA(2).LE.AIRDRY(2)) GOTO 20
15     E2=ALPHA*(SQRT(FLOAT(JDAY)-TIME)-SQRT(FLOAT(JDAY-1)-TIME))
       IF(E2.GT.EP)E2=EP
       AVAIL2=(THETA(2)-AIRDRY(2))*DEPTH(2)
       IF(E2.GT.AVAIL2)E2=AVAIL2

20    IF(E1.LT.0.0) E1 = 0.0
      IF(E2.LT.0.0) E2 = 0.0
      CUME=CUME+E1+E2

       RETURN
       END SUBROUTINE EVAP


!***********************************************************************
!                           SUBROUTINE DAYOFYR


       SUBROUTINE DAYOFYR(JDAY,IMON,IDAY)

	   INTEGER IDAYS(12)
       DATA IDAYS/0,31,59,90,120,151,181,212,243,273,304,334/
       JDAY=IDAY+IDAYS(IMON)
       RETURN
       END SUBROUTINE DAYOFYR


!***********************************************************************
!                 SUBROUTINE NTHET

       SUBROUTINE NTHET

       USE PARM

       REAL DINFL,AMT,THETUP

!-----   Calculate The Amount Of Water That Can Be Added To Each Layer
!-----     DINF  = the depth of water that infiltrated
!-----     DINFL = the amount of water added to a layer
!-----     AMT   = the amount of water that can be added to a layer

       DO  I=1,LAYERS
         IF(DINF.EQ.0.) GOTO 50
         AMT=(FIELDC(I)-THETA(I))*DEPTH(I)
         IF(AMT.LT.0.0) AMT = 0.0

         IF(AMT.GE.DINF) THEN
             DINFL=DINF
             DINF=0.
          ELSE
           DINFL=AMT
           DINF=DINF-AMT
         ENDIF

!------  Add Water To The Layer
20       THETUP=DINFL/DEPTH(I)
         THETA(I)=THETA(I)+THETUP
       END DO

!-----   If Any Water Is Left Then Add An Equal Amount To Every Layer

       THETUP=DINF/TOTDEP
       DO  I=1,LAYERS
         THETA(I)=THETA(I)+THETUP
       END DO

       DINF = 0.
       
50     CONTINUE

       RETURN
       END SUBROUTINE NTHET

!***********************************************************************
!        SUBROUTINE EFPRECIP

      SUBROUTINE EFPRECIP

      USE PARM
      REAL CNUMB,CNAVG,CNFALO,CNPEAK,CNFACT
	  
!--- Adjust Curve Number For Residue Cover
!    Restyp = 1 For All But Corn And Sorghum, = 2 For Corn And Sorghum
!    Adjustments Based On Onstad Procedure.
!    Adjust CN only for small grain and row crops, not forage, etc.

      IF(CROP.LT.10) THEN

          IF(RESTYP(OLDCRP).EQ.1) THEN
              CNFACT = (12.648 - 4.7000/SQRT(0.001123 * RESIDUE))/100.
            ELSE
              CNFACT = (12.456 - 6.4098/SQRT(0.001123 * RESIDUE))/100.
          ENDIF

          CNFACT = MAX(CNFACT, 0.0)

          CNPEAK= (2.0*CN(CROP,IHYGRP)-CNFALLOW(IHYGRP)) * (1.0-CNFACT)
          CNAVG = CN(CROP,IHYGRP)  * (1.0-CNFACT)
          CNFALO= CNFALLOW(IHYGRP) * (1.0-CNFACT)

          IF(GDD.LE.GDDVEG) THEN
             CNUMB = CNFALO
           ELSE
            IF(GDD.LE.GDDEFC) THEN
               CNUMB=CNFALO+(CNAVG-CNFALO)*(GDD-GDDVEG)/(GDDEFC-GDDVEG)
              ELSE
               CNUMB=CNAVG+(CNPEAK-CNAVG)*(GDD-GDDEFC)/(GDDMAT-GDDEFC)
            ENDIF
          ENDIF

          IF(GDD.GT.GDDMAT) CNUMB = CNFALO * (1.0-CNFACT)

        ELSE
          CNFACT=0.0
          CNUMB = CN(CROP,IHYGRP)
      ENDIF

!---  Calculate The Runoff Fraction From The Antecedent Moisture

      CURVNO = CNUMB
      CURVN1 = 4.2*CNUMB/(10.-0.058*CNUMB)
      CURVN3 = 23.* CNUMB/(10.+0.13 * CNUMB)
      SMAX   = 25.4 * (1000./CURVN1  - 10.)
      S3     = 25.4 * (1000./CURVN3  - 10.)

      SW  = 0.0
      SAT = 0.0
      FC  = 0.0
      RUNDEP = 12.
      TOTRDP = 0.
      
	  DO ILAY = 1, LAYERS
          TOTRDP = TOTRDP + DEPTH(ILAY)
	    IF (TOTRDP.LT.RUNDEP) THEN         
            SW  = SW  + (THETA(ILAY)-PWP(ILAY))*25.4*DEPTH(ILAY)
            SAT = SAT + (SATWC-PWP(ILAY))*25.4*DEPTH(ILAY)
		    FC  = FC  + (FIELDC(ILAY) - PWP(ILAY))*25.4*DEPTH(ILAY)
	      ELSE
            SW  = SW  + (THETA(ILAY)-PWP(ILAY))*25.4*(RUNDEP-(TOTRDP-DEPTH(ILAY)))
		    SAT = SAT + (SATWC-PWP(ILAY))*25.4*(RUNDEP-(TOTRDP-DEPTH(ILAY)))
		    FC  = FC  + (FIELDC(ILAY) - PWP(ILAY))*25.4*(RUNDEP-(TOTRDP-DEPTH(ILAY)))
             GOTO 100
        END IF
	  END DO
      
100	  W2 = (LOG(FC/(1.0 - S3/SMAX) - FC) - LOG( SAT/(1.0-2.54/SMAX) - SAT))/ (SAT-FC)
	  W1 = LOG( FC/ (1.0-S3/SMAX) - FC ) + W2 * FC
	  S = AMAX1(2.54,SMAX * ( 1 - SW / (SW + EXP(W1 - W2*SW))))
	  CURVNO = 25400. / ( S + 254.)
	  S = S / 25.4

      P=RAIN

!-----Compute The Relative Runoff -- Fraction Of Precipitation

      IF(0.2*S.GT.P) THEN
          RRUNOF= 0.0
        ELSE
          RRUNOF=( (P-0.2*S)**2. / (P+0.8*S) )  / P
      ENDIF


!---- Calculate The Effective Precip. Increase the depth in the channel
!---- portion of conservation terraces.
!       RUNOFF= DEPTH OF WATER THAT RUNS OFF, INCHES 
!       RUNON = DEPTH OF WATER THAT RUNS ONTO TERRACE CHANNEL,INCHES
!       DPOND = DEPTH OF PONDED WATER IN THE CHANNEL,FEET
!       ITERRC= 0 NOT A TERRACE CHANNEL, >1 IS A TERRACE CHANNEL
!       CHAND = DEPTH OF WATER THAT CAN BE STORED IN TERRACE CHANNEL, FEET
!       CHANW = WIDTH OF TERRACE CHANNEL, FEET
!       TINTRV= TERRACE INTERVAL ON HILLSLOPE, FEET

      IF(ITERRC.EQ.0) THEN
          EPRECIP = RAIN * (1.0 - RRUNOF)
          RUNON = 0.0
		  RUNOFF = RAIN - EPRECIP
        ELSE
          RUNON = RAIN * RRUNOF * (TINTRV-CHANW)/CHANW
          DPOND = (RAIN * RRUNOF + RUNON)/12.

          IF (DPOND.LE.CHAND) THEN
              EPRECIP = RUNON + RAIN
			  RUNOFF = 0.0
            ELSE
              EPRECIP = RAIN * (1.0 - RRUNOF)  +  CHAND * 12.
			  RUNOFF  = (DPOND - CHAND) * 12.
          ENDIF
      ENDIF

	  IF((RUNOFF.LT.0.0).OR.((EPRECIP.GT.RAIN).AND.(ITERRC.EQ.0))) THEN
        IF (LIBMODE) THEN                       !LIB
          IF (CS_STATUS.EQ.0) CS_STATUS = 1       !LIB
        ELSE                                    !LIB
	     WRITE(6,*) ' @ 1487:',JDAY,CROP,SOIL,P,S,CURVNO,RRUNOF,EPRECIP,RAIN, &
		              RUNOFF,ITERRC,SIMFILE(I)
         STOP
        END IF                                  !LIB
	  END IF


      RETURN
      END SUBROUTINE EFPRECIP

!***********************************************************************
!  SUBROUTINE ROOTZN

       SUBROUTINE ROOTZN

      USE PARM

!-----   Root Distribution Function

       RDIST(Z2,Z1)=2.0633*(Z2-Z1)-1.622*(Z2*Z2-Z1*Z1)+0.5587* &
          (Z2**3.0-Z1**3.0)

       RZD = (RZMAX-RZMIN)*(GDD-GDDROOT)/(GDDFLO-GDDROOT)  + RZMIN
       IF(RZD.GT.RZMAX)RZD=RZMAX
       IF(RZD.LT.RZMIN)RZD=RZMIN

!-----   Calculate The Percent Of Each Layer Filled With Roots

       REMAIN=RZD

       DO  I=1,LAYERS
         REMAIN=REMAIN-DEPTH(I)
         IF(REMAIN.GE.0.)PERRZD(I)=1.
         IF(REMAIN.LT.0.0.AND.REMAIN.GT.-DEPTH(I))						&
               PERRZD(I)=(DEPTH(I)+REMAIN)/DEPTH(I)
         IF(REMAIN.LT.0.)REMAIN=0.
       END DO

!-----  Compute the available water in the irrigation management zone 
!       that extends through the RZMGMT depth and the plant available 
!       water in the whole root zone. TOPDEP and BOTDEP are the top 
!       and bottom depths of a soil layer. When RZMGMT lies between the
!       top and bottom the fraction of the layer that contributes to 
!       available water is the distance from the top to RZMGMT if the
!       roots are below RZMGMT, or PERRZD if the roots are above RZMGMT.

       PAW    = 0.0
       AWATER = 0.0
	   TOPDEP = 0.0
	   BOTDEP = 0.0
	   
       DO  I=1,LAYERS
         TOPDEP = BOTDEP
		 BOTDEP = BOTDEP + DEPTH(I)
	     
	     IF(BOTDEP.LE.RZMGMT) AWATER=AWATER+AVMFT(I)*PERRZD(I)

		 IF((RZMGMT.GT.TOPDEP).AND.(RZMGMT.LT.BOTDEP)) THEN

		   IF(RZD.GE.RZMGMT) THEN 
		       FDEPTH = (RZMGMT-TOPDEP)/DEPTH(I)
             ELSE 
               FDEPTH = PERRZD(I)
		   ENDIF
		   AWATER=AWATER+AVMFT(I)*FDEPTH
	     ENDIF

         PAW=PAW+PAWFT(I)*PERRZD(I)
       END DO

       ZU=0.0
       ZL=DEPTH(1)/RZD
       IF(ZL.GT.1.0)ZL=1.0
       RDF(1)=RDIST(ZL,ZU)

       DO I=2,10
         ZU=ZL
         ZL=ZL+DEPTH(I)/RZD
         IF(ZL.GT.1.0)ZL=1.0
         RDF(I)=RDIST(ZL,ZU)
       END DO

       RETURN
       END SUBROUTINE ROOTZN


!***********************************************************************
!                       SUBROUTINE YIELDS

       SUBROUTINE YIELDS

       USE PARM
       REAL AC(11), BC(11), YEAR

!   Coefficients to adjust maximum yields over time for grains, tuber
!   and forage crops
!
!	YADJ is the fraction of the yield for the specified year versus 
!	what the yield would have been in 2001
!	
!	Yields are only adjusted if YTREND = 1
!

       DATA AC/-22.963,-13.156,-18.249,1.000,1.000,-11.008,-22.963,    &
               -24.578,-17.165,-12.562,-20.334/
       DATA BC/0.01199,0.00708,0.00963,0.00000,0.00000,0.00601,0.01199,&
               0.01280,0.00909,0.00678,0.01067/

       YEAR = IYEAR

	   IF(YTREND.EQ.1) THEN
           YADJ = AMAX1( AC(CROP) + BC(CROP) * YEAR, 0.0)
         ELSE
		   YADJ = 1.0
	   ENDIF
  
       IF(CROP.LT.12) THEN
           IF(IYIELD.EQ.1) THEN
              TR=TDEF(1)+TDEF(2)+TDEF(3) + TDEF(4) + TDEF(5)
              TA=TPS(1)+TPS(2)+TPS(3) + TPS(4) + TPS(5)
              YIELD=YADJ*YMAX*(1.0-YCOEFF*TR/TA)
            ELSE
              YIELD=YADJ*YMAX*((1.0-YCOEFF)+YCOEFF*ETYLD/ETMAX)
           ENDIF
         ELSE
           YIELD = YMAX
       ENDIF

       IF(YIELD.LT.0.0) YIELD = 0.0

       BVALUE   = YADJ*YMAX*YCOEFF/ETMAX
	   YLDRATIO = YIELD / (YADJ*YMAX)

       RETURN
       END SUBROUTINE YIELDS

!***********************************************************************
!   DEPLT -- DAILY SOIL WATER BALANCE-DEPLETION SUBROUTINE

      SUBROUTINE DEPLT

      USE PARM
                                                                       !
!-----Initialize Parameter Values

      AWATER= 0.
      CUME  = 0.
      DRAINS= 0.
      DRNOFF= 0.
      EOFF  = 0.
      EPRECIPS= 0.
      ES    = 0.
      ET    = 0.
      ETMAX = 0.
      ETOFF = 0.
      ETROFF= 0.
      ETRS  = 0.
      ETS   = 0.
      ETYLD = 0.
      EVEG  = 0.
      ICUT  = 1
      IPRINT= 0
      IRIGNO= 0
      JNEXTI= 1
      JDYWET= JDYBG-1
      KSTG  = 0
      PRECIPS = 0.
      RNOFF = 0.
      RUNONS= 0.
      RZD   = RZMIN
      SGRIRR= 0.
      SNIRR = 0.
      TDEFS = 0.
      TIME  = JDYWET
      TOFF  = 0.
      TOT1  = 0.
      TOT2  = 0.
      TOT3  = 0.
      TOT4  = 0.
      TOT5  = 0.
      TOT6  = 0.
      TOT7  = 0.
      TOT8  = 0.
      TOT9  = 0.
      TOT10 = 0.
      TOTRO = 0.
      TOTWAT= 0.
      TS    = 0.
      TVEG  = 0.

      DO  M= 1,5
        TDEF(M)= 0.
        TPS(M) = 0.
      END DO

      DO  K=1,10
        PERRZD(K)=0.
      END DO

      TUP=KCL(CROP)/(KCU(CROP)-KCL(CROP))

      DO I=1,LAYERS
        TOTWAT=TOTWAT+THETA(I) * DEPTH(I)
      END DO

! ----Initialize The Monthly Arrays
      DO  K=1,12
        ETRMON(K) =0.0
        EMON(K)   =0.0
        TMON(K)   =0.0
        ETMON(K)  =0.0
        ERMON(K)  =0.0
        RAMON(K)  =0.0
		ROFMON(K) =0.0
        RONMON(K) =0.0
        IRNMON(K) =0.0
        IRGMON(K) =0.0
        INFMON(K) =0.0
        DRAMON(K) =0.0
      END DO

! ----Initialize The Weekly Arrays
      DO  K=1,53
        ETRWK(K) =0.0
        ETWK(K)  =0.0
        ERWK(K)  =0.0
        RAWK(K)  =0.0
        IRNWK(K) =0.0
        IRGWK(K) =0.0
      END DO


!-----Print Headers

      IF((IPFLAG.GT.0).AND.(IPSOIL.EQ.SOIL)) THEN
	    DO IPR = 1, NPRSITE
		  IF(WSITE.EQ.PRSITE(IPR).AND.(IYEAR.GE.JPRSTR).AND.(IYEAR.LE.JPRSTP)) THEN
            WRITE(7,50) SNOH2O,TOTWAT
            WRITE(8,55)
		  END IF
        END DO
      ENDIF

50    FORMAT(8X,'DAILY  TOTAL  TOTAL  TOTAL  TOTAL   NET',             &
      '   GROSS  GROSS   NET    SNOW',31X,'TOTAL CROP TOTAL',1X,	   &
	  'AWATER',7X,'ROOT',' PLANT  HOLD TOTAL'						   &
	  /'  DATE   ETR    ETR    EVAP  TRANS    ET ',					   &
      '  IRRIG  IRRIG PRECIP PRECIP    H2O   RUNON  CURVE  RESIDUE',   &
      '   GDD DRAIN COEF  DEPL  DEPL  DEPL DEPTH WATER  CAPA WATER',   &
      / 5X,11(5X,'IN'),6X,'NO.',3X,'LB/AC',5X,'F',5X,'IN',9X,2('IN',   &
      4X),'% ',4(4X,'IN') /159('-')/70X,F6.3,77X,F6.2)

55    FORMAT(' DATE  DFRACT EXTRA DIST  DET DRAIN DNETIR DINF RUNON',  &
       'AWDPLN',' DPLA',                                               &
        16X,'VOLUMETRIC WATER CONTENTS',30X,'SOIL TEMPERATURE, F'      &
         /,163('-'))

!=======================================================================
!     Start Of The Daily Loop

!	  WRITE(6,5559) II,ISOIL,IYEAR,CROP,SOIL,WSITE,SIMFILE(II)
!5559  FORMAT(' @ 1622 ',I7,4I5,2X,A4,2X,A12)

      DO 330 JDAY=JDYBG,JDYEND

        TODAY = JDAY
        JULDAY= JDAY
        EPRECIP = 0.0
        E     = 0.0
        T     = 0.0
        ET    = 0.0
	    RUNOFF= 0.0
        RUNON = 0.0
        GDD   = GDDS(JDAY)
        TAVG  = 0.5 * ( TMAX(JDAY) + TMIN (JDAY) )

        IF ((iyear .eq. 1999).AND.(Jday .eq. 149)) THEN
            CONTINUE
        END IF
        
!   Determine the growth stage for grain, tuber and forage crops

        IF(CROP.LT.12) THEN
            KSTG=1
            IF(GDD.GT.GDDFLO)KSTG=2
            IF(GDD.GT.GDDRIPE)KSTG=3
            IF((CROP.EQ.10) .OR. (CROP.EQ.11) ) KSTG=ICUT
          ELSE
            KSTG = 1
            IF(GDD.GT.GDDEFC) KSTG = 2
        ENDIF

!   Compute Root Depth for the Day

        IF((RZD.LT.RZMAX).OR.(AWATER.LE.0.0)) CALL ROOTZN

!-  Calculate Effective Rainfall Amount, and Redistribute Infiltration

60      IF((PRECIP(JDAY).GT.0.).OR.(SNOH2O.GT.0.0)) THEN
!          WRITE(7,*) ' AT 1773: ', JDAY,PRECIP(JDAY),SNOH2O,SNOTMP
          RAIN = PRECIP(JDAY)
          CALL SNOWMELT

          CALL EFPRECIP


		  IF((EPRECIP.GT.RAIN).AND.(ITERRC.EQ.0)) THEN
        IF (LIBMODE) THEN                       !LIB
          IF (CS_STATUS.EQ.0) CS_STATUS = 2       !LIB
        ELSE                                    !LIB
		    WRITE(7,*) ' @ 1729: ', JDAY,IYEAR,IMON,ITERRC,PRECIP(JDAY),	&
						RAIN,SNOH2O,EPRECIP
			STOP
        END IF                                  !LIB
		  ENDIF

          IF(IRRTYP.EQ.2) EPRECIP=PRECIP(JDAY)
            DINF=EPRECIP
            JDYWET=JDAY
            CALL NTHET
          ENDIF

!   Compute Available Water Depletion to see if irrigation is needed

        AWDPLN = 0.0
		TOPDEP = 0.0
		BOTDEP = 0.0

        DO I=1,LAYERS
		  TOPDEP = BOTDEP
		  BOTDEP = BOTDEP + DEPTH(I)

		  IF(BOTDEP.LE.RZMGMT) THEN
              DEPL(I)=(FIELDC(I)-THETA(I))*DEPTH(I)*PERRZD(I)
			  AWDPLN = AWDPLN+DEPL(I)
		      IF(RZMGMT.EQ.BOTDEP) GOTO 65
		  ENDIF

          IF((RZMGMT.GT.TOPDEP).AND.(RZMGMT.LT.BOTDEP)) THEN 
              IF(RZD.GE.RZMGMT) THEN
			      FDEPTH = (RZMGMT - TOPDEP)/DEPTH(I)
			    ELSE
				  FDEPTH = PERRZD(I)
			  ENDIF
			  DEPL(I)=(FIELDC(I)-THETA(I))*DEPTH(I)*FDEPTH
			  AWDPLN = AWDPLN+DEPL(I)
			  GOTO 65
          ENDIF

        END DO

65      DPLA=AWATER*PAD(KSTG)


!=======================================================================
!  Determine if Irrigation is needed base on the type of irrigation.
!
!    IRRTYP = 1-Dryland, 2-Historical Dates, 3-Pivots, 4-Furrow, 5-Other
!
!  And the method of scheduling
!
!   IRRSCH = 1-Groundwater or other full demand systems, 
!            2-District/Demand based scheduling, 
!	         3-District/Rotation System With Fixed Delivery Schedules 
!              and Gross Depth. Don't Allow Irrigation If Before The First 
!              Delivery Date. If After November 1 For Alfalfa And Grass Or If 
!              After The Maturity Date For Other Crops.
!            4 - Simulation for known future weather for NOAA project
!
!  For Stress Irrigation of Alfalfa And Grass There Is Also a Period
!  Between JSTOPI And JGOI When Irrigation Is Not Allowed
!
!  Used Smallest Irrigation To Schedule The First Irrigation.
!  After That The Irrigation Date Is Set By The Rotation System.
!-----------------------------------------------------------------------

        IF(IRRTYP.EQ.1) GOTO 120

!-----------------------------------------------------------------------
!	Scheduling Method 3 -- Fixed Rotation and Fixed Depth
!-----------------------------------------------------------------------
        IF(IRRSCH.EQ.3) THEN
          IF(JDAY.LT.JFIRST) GOTO 120

          IF((CROP.GE.10).AND.(CROP.LE.12)) THEN
              IF((JDAY.GT.JSTOPI).AND.(JDAY.LT.JGOI)) GOTO 120
              IF(JDAY.GT.304) GOTO 120
            ELSE
              IF(JDAY.GT.JDYMAT) GOTO 120
          ENDIF

          IF(IRIGNO.LT.1) THEN
              CALL IRRIGA
              IF(IRIGNO.LT.1) GOTO 120
            ELSE
              IF(JDAY.LT.JNEXTI )  GOTO 120
              CALL IRRIGA
          END IF
          GOTO 110
        ENDIF


!-----------------------------------------------------------------------
!- Fixed Irrigation Date And Amount For Simulating Experiments
!- FDIRRIG = 1 - fixed irrig date, 2 - gross depth, 3 - application eff
!-----------------------------------------------------------------------

        IF (IRIGNO .LT. 1) IRIGNO = 1
        IF(IRRTYP.EQ.2) THEN
          IF(INT(FDIRRIG(IRIGNO,1)).NE.JDAY) GOTO 120
          GROIRR=FDIRRIG(IRIGNO,2)
          NETIRR=GROIRR*FDIRRIG(IRIGNO,3)
          DINF=NETIRR
          IRIGNO=IRIGNO+1
        ENDIF

!-----------------------------------------------------------------------
!   Management Allowed Depletion (i.e. Demand Based) Scheduling
!     ISCH = 1, 2, 4 or 5
!-----------------------------------------------------------------------

        IF(IRRTYP.GT.2) THEN
          IF((GDD.LT.GSTART).OR.(GDD.GT.GSTOP)) GOTO 120
          CALL IRRIGA
        ENDIF

!   Add Irrigation To Seasonal Totals and Redistribute The Infiltration

110     SGRIRR=SGRIRR+GROIRR
        SNIRR=SNIRR+NETIRR
        JDYWET=JDAY
        CALL NTHET

!=======================================================================
!  Call subroutine for crop coefficients
!120   CALL CROPCO

120	    KC = CROPKC(JDAY)

!----------------------------------------------------------------------
!  Adjust the amount of residue cover for tillage on row crops & grains
!  after crop maturity
!-----------------------------------------------------------------------
        IF(CROP.LT.10) THEN
          IF(JDAY.EQ.JDYMAT) THEN
            IF((CROP.NE.7).OR.(LIVECROP.EQ.1)) THEN
              CALL YIELDS
              RESIDUE = YIELD * YDENS(CROP) * RESRAT(CROP)
              OLDCRP  = CROP
            ENDIF
          ENDIF
          DO ITILL = 1, NTILLS
            IF(JDAY.EQ.TILDAY(ITILL)) THEN
              RESIDUE=RESIDUE*TILFAC(TILCOD(ITILL),FRAGIL(OLDCRP))/100.
            ENDIF
          END DO
        ENDIF

!----------------------------------------------------------------------
!  Compute Soil Temperatures


!	  WRITE(6,1210)  JDAY, THETA
!1210  FORMAT(' @  1773:',I4,10F6.3)

        CALL SOILTEMP

!----------------------------------------------------------------------
!  Evaporation Routine
!----------------------------------------------------------------------

!   Use crop coefficient directly for ET for Riparian Woodlands,
!   wetlands, and open water
!	WRITE(6,*) ' @ 1785 :',JDAY, CROP, SOIL, ETR(JDAY)


        IF( (CROP.EQ.16).OR.(CROP.EQ.18).OR.(CROP.EQ.19).OR.           &
          (CROP.EQ.20).OR.(CROP.EQ.21) ) GO TO 250

        IF(ETR(JDAY).LE.0.) GOTO 260

        EP=ETR(JDAY)*AMIN1((KCU(CROP)+KCL(CROP)-KC),1.0)
        EPMAX = EP

        IF(EP.LE.0.)EP=0.001
        IF(EP.LE.0.001 )GOTO 200

        CALL EVAP

        THETA(1)=THETA(1)-E1/DEPTH(1)
        THETA(2)=THETA(2)-E2/DEPTH(2)

        E=E1+E2

!   Skip transpiration calculation for summer fallow
        IF(CROP.EQ.15) GOTO 248
!----------------------------------------------------------------------
!      Transpiration Routine
!----------------------------------------------------------------------

200     TP=ETR(JDAY)*(KC-KCL(CROP))
        IF(EP.GT.0.0) TP=TP*(1.0+TUP*(EPMAX-E)/EPMAX)
        IF(TP.LE.0.0) GOTO 260

        TWEIGH = 0.0
        DPLN   = 0.0
        WAVAIL = 0.0

        DO I=1,LAYERS
          DEPL(I)=(FIELDC(I)-THETA(I))*DEPTH(I)*PERRZD(I)
          IF(DEPL(I).LT.0.0)          DEPL(I) = 0.0
          DPLN=DPLN+DEPL(I)

          IF(PERRZD(I).GT.0.0) THEN
              PERDEP(I)=DEPL(I)/(PAWFT(I)*PERRZD(I))
              IF(PERDEP(I).GT.1.0)    PERDEP(I)=1.0

              IF(THETA(I).GT.PWP(I)) THEN
                WAVAIL=WAVAIL+(THETA(I)-PWP(I))*DEPTH(I)*PERRZD(I)
                TWEIGH=TWEIGH+RDF(I)*(1.0-PERDEP(I))
              ENDIF
            ELSE
              PERDEP(I) = 0.0
          ENDIF
        END DO

!  Compute The Stress Factor

!	   WRITE(6,2001) JDAY, THETA
!2001   FORMAT(' @ 1838:',I5,10F6.3)

        AV=(1.-DPLN/PAW)*100.
        IF(AV.LT.0.)AV=0.
        SR=AV/TBREAK
        IF(AV.GT.TBREAK)SR=1.0
        T=TP*SR
        IF(T.LE.0.0) GOTO 248

!----------------------------------------------------------------------
!       Uptake Section
!----------------------------------------------------------------------

        TRANS  = T
        TUSE   = 0.0
        DPLN   = 0.0
        TWAIT  = 0.0
        TFLAG  = 0.0
        ITRIES = 1
        IF(WAVAIL.GT.T) GOTO 220

!-----Transpiration Demand > Water Available

        DO  I=1,LAYERS
          THETA(I)=PWP(I)*PERRZD(I)+THETA(I)*(1.0-PERRZD(I))
          PERDEP(I)=1.0
        END DO

        DPLN=PAW
        TUSE=WAVAIL
        GOTO 248

!-----More Than Enough Water To Meet Transpiration Demand

220     DO I=1,LAYERS
          UPTAKE=TRANS*(1.0-PERDEP(I))*RDF(I)/TWEIGH
          IF(UPTAKE.LT.0.0) UPTAKE=0.0
          WAVAIL=(THETA(I)-PWP(I))*DEPTH(I)*PERRZD(I)
          IF(WAVAIL.LT.0.0) WAVAIL=0.0
          IF(UPTAKE.GT.WAVAIL) GOTO 230
          TUSE=TUSE+UPTAKE
          THETA(I)=THETA(I)-UPTAKE/DEPTH(I)
          GOTO 235

!-----Tflag = 1 --> Not Enough Layer Water For Needed Uptake

230       TUSE=TUSE+WAVAIL
          THETA(I)=PWP(I)*PERRZD(I)+THETA(I)*(1.0-PERRZD(I))
          TFLAG=1.0
235       PERDEP(I)=(FIELDC(I)-THETA(I))*DEPTH(I)/PAWFT(I)
          IF(PERDEP(I).GT.1.0) PERDEP(I)=1.0
          DPLN=DPLN+(FIELDC(I)-THETA(I))*DEPTH(I)*PERRZD(I)
          TWAIT=TWAIT+RDF(I)*(1.0-PERDEP(I))
        END DO

        IF(TFLAG.EQ.0.0) GOTO 248
        TWEIGH=TWAIT
        TRANS=T-TUSE
        IF(ABS(TRANS) .LT. 0.001) GOTO 248
        DPLN=0.0
        TWAIT=0.0
        ITRIES = ITRIES + 1
        TFLAG=0.0
        IF( ITRIES .GT. 20)  GOTO 245
        GOTO 220

245     IF (LIBMODE) THEN                       !LIB
          IF (CS_STATUS.EQ.0) CS_STATUS = 3       !LIB
        ELSE                                    !LIB
        WRITE(*,246)JDAY,TRANS
246     FORMAT(/2X,'********  CONVERGENCE ERROR IN TRANS LOOP DAY=', &
        I4,5X,'TRANS=',F6.2)
        STOP
        END IF                                  !LIB

!=======================================================================
!   Add daily evaporation and transpiration to seasonal totals
!   Cumulative Values By Growth Stage For Grain/Tuber/Forage Crops

248     CONTINUE


!	WRITE(6,*) ' @ 1912:', ET,THETA

        IF (CROP.LT.10) THEN
            IF ((GDD.GE.GDDVEG) .AND. (GDD.LE.GYFORM)) THEN
              ETMAX     = E1 + E2 + TP + ETMAX
              ETYLD     = E1 + E2 + T  + ETYLD 
              TPS(KSTG) = TPS(KSTG)+TP
              TDEFS     = TDEFS+TP-T
              TDEF(KSTG)= TDEF(KSTG)+TP-T
		    ENDIF
          ELSE

!-----Cumulative Values By Cutting For Forage Crops
            IF((CROP.GT.9).AND.(CROP.LT.12)) THEN
               TPS(ICUT)  = TPS(ICUT)+TP
               TDEFS      = TDEFS+TP-T
               TDEF(ICUT) = TDEF(ICUT)+TP-T
               ETMAX      = E1 + E2 + TP + ETMAX
               ETYLD      = E1 + E2 + T  + ETYLD
            ENDIF
        ENDIF

!-----------------------------------------------------------------------
!   ET computation for riparian woodlands, wetlands, AND water

250     IF( (CROP.EQ.16).OR.(CROP.EQ.18).OR.(CROP.EQ.19).OR.           &
          (CROP.EQ.20).OR.(CROP.EQ.21) ) THEN

          ET = KC * ETR(JDAY)

!	WRITE(6,*) ' @ 1947: ', CROP,ET,KC,JDAY,ETR


          DO I = 1, LAYERS
             THETA(I) = FIELDC(I)
          END DO
        ENDIF

!----------------------------------------------------------------------
!   REDISTRIBUTION ROUTINE
!
!     EXTRA = Water that exceeds field capacity to be distributed
!     DISTD = Depth of profile that is at field capacity
!     AMT   = Depth of water that can be stored in a layer
!     ADDL  = Depth of water to add to a layer
!     THETUP= Increase in volumetric water content for layer
!
!  If layer is above field capacity compute the amount of extra water,
!     and set water content to field capacity.
!
!  If layer is below field capacity increase water content of layer up
!     to field capacity, and decrease amount of extra water.
!----------------------------------------------------------------------

260     EXTRA=0.
        DISTD=0.0

        DO I=1,LAYERS

          IF(THETA(I).GT.FIELDC(I)) THEN
              EXTRA=EXTRA + ( THETA(I)-FIELDC(I) )*DEPTH(I)
              THETA(I)=FIELDC(I)
              DISTD=DISTD+DEPTH(I)
              GOTO 300
            ELSE
              IF(EXTRA.EQ.0.) GOTO 300
              AMT = ( FIELDC(I)-THETA(I) )*DEPTH(I)

              IF(AMT.GE.EXTRA) THEN
                  ADDL=EXTRA
                  EXTRA=0.
                ELSE
                  ADDL=AMT
                  EXTRA=EXTRA-AMT
              ENDIF
          ENDIF

          THETUP   = ADDL/DEPTH(I)
          THETA(I) = THETA(I) + THETUP
          IF(THETA(I).GE.FIELDC(I)) DISTD=DISTD+DEPTH(I)
300     END DO


!----------------------------------------------------------------------
!       DRAINAGE ROUTINE
!
!     DRAIN  = The depth of water that drains that day
!     EXTRA  = Now is the amount of water in excess of field capacity
!              for the profile and equals the water that can drain
!     DFRACT = Drainage fraction = portion of EXTRA that drains per day
!     DRAIND = Days for EXTRA water to drain out of the profile
!     DCOEFF = Coefficient for drainage rate
!     DIST   = Average increase of Water Content for water not drained
!----------------------------------------------------------------------

        DRAIN=0.0
        IF(EXTRA.GT.0.0) THEN
           DFRACT = (FLOAT(JDAY-JDYWET+1)/DRAIND)**DCOEFF
           IF(DFRACT.GT.1.0) DFRACT = 1.0
           DRAIN = EXTRA * DFRACT
           
           IF (drain .GT. 0) THEN
                CONTINUE
           END IF
           
           DIST = (1.0-DFRACT) * EXTRA/DISTD

           DPLN = 0.0
           DO I = 1,LAYERS
             IF(THETA(I).GE.FIELDC(I))  THETA(I) = THETA(I) + DIST
             DPLN = DPLN  + (FIELDC(I)-THETA(I))*DEPTH(I) * PERRZD(I)
           END DO
        ENDIF

!-----Update The Daily Values
!-----Compute Totals For Before May And After Sept

        DPLPER   = (AWDPLN/AWATER)*100.0
        DRAINS   = DRAINS  + DRAIN
        ETRS     = ETRS    + ETR(JDAY)
        ES       = ES      + E
        PRECIPS  = PRECIPS + PRECIP(JDAY)
        EPRECIPS = EPRECIPS+ EPRECIP
        RUNONS   = RUNONS  + RUNON
        TS       = TS      + T

        IF(GDD.LE.GDDVEG)  THEN 
		   EVEG = EVEG + E
		   TVEG = TVEG + T
		ENDIF

!-----   Compute Final Soil Water Depletions

        DPLN = 0.0
        DO I = 1, LAYERS
          DPLN=DPLN + (FIELDC(I)-THETA(I))*DEPTH(I)
		ENDDO

		AWDPLN = 0.0
		TOPDEP = 0.0
		BOTDEP = 0.0

        DO I=1,LAYERS
		  TOPDEP = BOTDEP
		  BOTDEP = BOTDEP + DEPTH(I)

		  IF(BOTDEP.LE.RZMGMT) THEN
              DEPL(I)=(FIELDC(I)-THETA(I))*DEPTH(I)*PERRZD(I)
			  AWDPLN = AWDPLN+DEPL(I)
		      IF(RZMGMT.EQ.BOTDEP) GOTO 305
		  ENDIF

          IF((RZMGMT.GT.TOPDEP).AND.(RZMGMT.LT.BOTDEP)) THEN 
              IF(RZD.GE.RZMGMT) THEN
			      FDEPTH = (RZMGMT - TOPDEP)/DEPTH(I)
			    ELSE
				  FDEPTH = PERRZD(I)
			  ENDIF
			  DEPL(I)=(FIELDC(I)-THETA(I))*DEPTH(I)*FDEPTH
			  AWDPLN = AWDPLN+DEPL(I)
			  GOTO 305
          ENDIF

        END DO

!----------------------------------------------------------------------
!    Compute Seasonal and Off-season summaries

305     IF( (CROP.EQ.16).OR.(CROP.EQ.18).OR.(CROP.EQ.19).OR.           &
             (CROP.EQ.20).OR.(CROP.EQ.21) ) THEN
            ETS = ETS + ET
          ELSE
            ETS=  ES +  TS
        ENDIF

        IF((JDAY.LE.121).OR.(JDAY.GE.274)) THEN
          TOFF = TOFF + T
          EOFF = EOFF + E

          IF( (CROP.EQ.16).OR.(CROP.EQ.18).OR.(CROP.EQ.19).OR.         &
             (CROP.EQ.20).OR.(CROP.EQ.21) ) THEN

              ETOFF = ETOFF + ET
            ELSE
              ETOFF = ETOFF + E + T
          ENDIF

          RNOFF  = RNOFF  + PRECIP(JDAY)
          ETROFF = ETROFF + ETR(JDAY)
          DRNOFF = DRNOFF + DRAIN
        ENDIF

! ---- Compute Weekly Summaries for Production Crops

!		IF(CROP.LE.10) THEN		!Orignal code - changed to evaluate addtional crops
		IF(CROP.LE.22) THEN
          IWEEK = ( JDAY - 1 ) / 7 + 1
          ETRWK(IWEEK) = ETRWK(IWEEK) + ETR(JDAY)
          ETWK(IWEEK)  = ETWK(IWEEK)  + E + T
          ERWK(IWEEK)  = ERWK(IWEEK)  + EPRECIP
          RAWK(IWEEK)  = RAWK(IWEEK)  + PRECIP(JDAY)
          IRNWK(IWEEK) = IRNWK(IWEEK) + NETIRR
          IRGWK(IWEEK) = IRGWK(IWEEK) + GROIRR
		ENDIF

!-----Calculate Monthly Summaries

        CALL CALDAY(JULDAY,IMON,IDAY)
        ETRMON(IMON) = ETRMON(IMON)+ETR(JDAY)
        EMON(IMON)   = EMON(IMON)  + E
        TMON(IMON)   = TMON(IMON)  + T
        ERMON(IMON)  = ERMON(IMON) + EPRECIP
        RAMON(IMON)  = RAMON(IMON) + PRECIP(JDAY)
        ROFMON(IMON) = ROFMON(IMON)+ RUNOFF
        RONMON(IMON) = RONMON(IMON)+ RUNON

        IF(ROFMON(IMON) .LT.0.0) THEN
        IF (LIBMODE) THEN                       !LIB
          IF (CS_STATUS.EQ.0) CS_STATUS = 4       !LIB
        ELSE                                    !LIB
		   WRITE(6,*) ' @ 2150:', IMON,JDAY, IYEAR,SOIL,CROP,RAMON(IMON),&
		      ERMON(IMON),EPRECIP,PRECIP(JDAY),RAIN,SNOH2O
		   STOP
        END IF                                  !LIB
	    ENDIF
	    

        IF( (CROP.EQ.16).OR.(CROP.EQ.18).OR.(CROP.EQ.19).OR.           &
            (CROP.EQ.20).OR.(CROP.EQ.21) ) THEN
            ETMON(IMON) = ETMON(IMON) + ET
          ELSE
            ETMON(IMON) = EMON(IMON) + TMON(IMON)
        ENDIF

        DRAMON(IMON) = DRAMON(IMON) + DRAIN
        IRGMON(IMON) = IRGMON(IMON) + GROIRR
        GROIRR = 0.0
        IRNMON(IMON) = IRNMON(IMON) + NETIRR
        DNETI = NETIRR
        NETIRR = 0.0
        NUMIRR(IMON) = IRIGNO
        INFMON(IMON) = INFMON(IMON) + DINF
        DDINF = DINF
        DINF  = 0.0
        DET   = E + T

        IF (IDAY .GT. 1) GOTO 306
        DPLMON(IMON) = DPLN
        IPRINT = 1
        GOTO 310


!-----Setup Printing Dates For Printout

306     IF ((CROP.EQ.10).OR.(CROP.EQ.11)) THEN
          IF(JDAY.EQ.JDYCUT(ICUT)) GOTO 310
          IF(JDAY.EQ.JDYPLT) GOTO 310
          IF(JDAY.EQ.JDYEND) GOTO 310
        ENDIF

        IF ((CROP.EQ.12).OR.(CROP.EQ.13)) THEN
          IF(JDAY.EQ.JDYEFC) GOTO 310
          IF(JDAY.EQ.JDYMAT) GOTO 310
        ENDIF

        IF ((CROP.LT.10)) THEN
          IF(JDAY.EQ.JDYPLT)  GOTO 310
          IF(JDAY.EQ.JDYEFC)  GOTO 310
          IF(JDAY.EQ.JDYRIPE) GOTO 310
          IF(JDAY.EQ.JDYFLO)  GOTO 310
          IF(JDAY.EQ.JDYMAT)  GOTO 310
        ENDIF

        IF(IPRINT.EQ.INPRIN) IPRINT=0
        IPRINT=IPRINT+1
        IF(IPRINT.EQ.1) GOTO 310
        GOTO 330

310     TOTWAT=0.0
        CALL CALDAY(JULDAY,IMON,IDAY)

        DO I=1,LAYERS
           TOTWAT=TOTWAT+THETA(I)*DEPTH(I)
        END DO


        IF((IPFLAG.GT.1).AND.(IPSOIL.EQ.SOIL)  ) THEN
          DO IPR = 1, NPRSITE
            IF(WSITE.EQ.PRSITE(IPR)) THEN
              WRITE(7,320)IMON,IDAY,ETR(JDAY),ETRS,ES,TS,ETS,SNIRR,SGRIRR, &
                PRECIPS,EPRECIPS,SNOH2O,RUNONS,CURVNO,RESIDUE,GDD,DRAINS,  &
                KC,DPLN,AWDPLN,DPLPER,RZD,PAW,AWATER,TOTWAT
 
              WRITE(8,325)IMON,IDAY,DFRACT,EXTRA,DIST,DET,DRAIN,DNETI,     &
                DDINF,RUNON,AWDPLN,DPLA,THETA,SOILT
 		    END IF
          END DO
        ENDIF



320     FORMAT(2I3,11F7.2,F8.1,F8.0,1X,F6.0,F6.2,F5.2,2F6.2,F6.1,4F6.2)
325     FORMAT(2I3,3(2X,F4.2),1X,F4.2,4(2X,F4.2),2(1X,F4.2),2X,        &
          10(1X,F4.3),3X,10(1X,F4.1))


330   CONTINUE

!-----------------------------------------------------------------------
!                End Of Daily Loop
!-----------------------------------------------------------------------

360   FORMAT(I4,', ',F6.2,', ',6(F4.3,', '),F4.3)


!------ Print Monthly Summaries

      IF((IPFLAG.GT.1).AND.(IPSOIL.EQ.SOIL)  ) THEN
         DO IPR = 1, NPRSITE
          IF(WSITE.EQ.PRSITE(IPR).AND.(IYEAR.GE.JPRSTR).AND.(IYEAR.LE.JPRSTP)) THEN

            WRITE(7,380)
            WRITE(7,390)

            CALL CALDAY(JDYBG,IMBG,IDBG)
            CALL CALDAY(JDYEND,IMEND,IDEND)

            DO I = IMBG, IMEND
              TOT1=TOT1+ETRMON(I)
              TOT2=TOT2+EMON(I)
              TOT3=TOT3+TMON(I)
              TOT4=TOT4+ETMON(I)
              TOT5=TOT5+RAMON(I)
              TOT6=TOT6+ERMON(I)
              TOT7=TOT7+IRGMON(I)
              TOT8=TOT8+IRNMON(I)
              TOT9=TOT9+INFMON(I)
              TOT10=TOT10+DRAMON(I)
              TOTRO=TOTRO+RONMON(I)

              WRITE(7,410)I,ETRMON(I),EMON(I),TMON(I),ETMON(I),RAMON(I),     &
               ERMON(I),RONMON(I),IRGMON(I),IRNMON(I),NUMIRR(I),INFMON(I),  &
               DRAMON(I),DPLMON(I)
            END DO

            WRITE(7,420)

            WRITE(7,430)TOT1,TOT2,TOT3,TOT4,TOT5,TOT6,TOTRO,TOT7,TOT8,TOT9,&
               TOT10
            WRITE(7,435)ETROFF,EOFF,TOFF,ETOFF,RNOFF,DRNOFF

            ETRIN=TOT1-ETROFF
            EIN=TOT2-EOFF
            TIN=TOT3-TOFF
            ETIN=TOT4-ETOFF
            RNIN=TOT5-RNOFF
            DRNIN=TOT10-DRNOFF

            WRITE(7,440)ETRIN,EIN,TIN,ETIN,RNIN,DRNIN

		  END IF
        END DO

      ENDIF

380   FORMAT(139('-')///20X,'MONTHLY WATER BALANCE SUMMARIES')

390   FORMAT(/17X,'ETR',5X,'E'5X,'T',4X,'ET',3X,'PRECIP, in',2X,'RUNON', &
       2X,'IRRIGATION, in',2X,' TOTAL',2X,'INFIL',4X,'DRAIN',2X,       &
       'BEGDPL'/10X,'month',3X,'in',4X,'in',4X,'in',4X,'in',4X,'tot',  &
       3x,'eff',3X,'in',5X,'gross',4X,'net',4X,'# IRR',4X,'in',6X,'in',&
        6X,'in'/  10X,97('-'))

410   FORMAT(10X,I5,7F6.1,2F8.1,6X,I2,3F8.1)
420   FORMAT(10X,104('-'))

430   FORMAT(6X,'TOTALS',3X,7F6.1,2F8.1,8X,3F8.1)
435   FORMAT(/5X,'OFF SEASON',5F6.1,43X,F8.1)
440   FORMAT( 5X,'MAY - SEPT',5F6.1,43X,F8.1//139('=')///)


      IF (OUTPUTFORMAT.EQ.2) THEN		!1=COHYST  2=REPUBLICAN RIVER
!==========================================================================
!Format for Republican River Output Monthly File
!
      IF(IPFLAG.GT.1) WRITE(10,450) WEAFILE(ISIM),IYEAR,SOIL,CROP,ITFLAG,IRRTYP,ITERRC,  &
        (ETMON(I),ERMON(I),IRNMON(I),DRAMON(I),ROFMON(I),RONMON(I),    &
         I=IMBG,IMEND)

450   FORMAT('"',A4,'"',2(',',I5),4(',',I3),12(6(',',F5.1)))
!==========================================================================
      ELSE
!==========================================================================
!Format for COHYST Output Monthly File
!
!If routine included to match cohyst structure.  Livecrop switched between
!monthly printout (in deplt subroutine) and yr file production located
!in main body of program
!
	IF(IYEAR.GT.1938) THEN
		IF( (CROP.EQ.7).AND.(LIVECROP.EQ.0).AND.(IRRTYP.EQ.1).AND.   &
            		(ITFLAG.NE.3))  THEN
            		CROP=15
        	ENDIF

		IF(.NOT.LIBMODE) WRITE(10,451) WEAFILE(ISIM),IYEAR,SOIL,CROP,ITFLAG,IRRTYP,     &  !LIB
          		(ETMON(I),ERMON(I),IRNMON(I),DRAMON(I),ROFMON(I),RAMON(I), I=IMBG,IMEND)

451     	FORMAT(1X,A4,2X,2I5,3I3,12(2X,6F7.2))

		IF( (CROP.EQ.15).AND.(LIVECROP.EQ.0).AND.(IRRTYP.EQ.1).AND.   &
            		(ITFLAG.NE.3))  THEN
            		CROP=7
        	ENDIF
	ENDIF
!==========================================================================
      ENDIF


!--------------------------------------------------------------------------------------
!   Write Weekly Results
!--------------------------------------------------------------------------------------	  

	  DO IWEEK = 1, 52
	    IF(.NOT.LIBMODE) WRITE(14,480) WEAFILE(ISIM),IYEAR,IWEEK,SOIL,CROP,ITFLAG,IRRTYP,ITERRC,          &  !LIB
          ETRWK(IWEEK), ETWK(IWEEK), ERWK(IWEEK), RAWK(IWEEK), IRNWK(IWEEK), IRGWK(IWEEK) 
480     FORMAT(A4,',',I5,',',I3,',',I4,',',I3,',',3(I2,','),6(F7.2,','))
      END DO

!--------------------------------------------------------------------------------------	  
      RETURN
      END SUBROUTINE DEPLT


!***********************************************************************
!                  SUBROUTINE IRRIGA
!              IRRIGATION SCHEDULING ROUTINE
!
!  IRRTYP	= 1-Dryland, 2-Historical Dates, 3-Pivots, 4-Furrow, 5-Other
!
!  IRRSCH	= 1-Full Demand Scheduling, 
!			= 2-District-Demand based, 
!			= 3-Rotation System with Fixed Delivery Schedules and Fixed Gross Depth
!			= 4-Schedule with Known Future Rain
!			= 5-Schedule with Known Future Water Balance
!			= 6-Schedule with Known Future SWD and Capacity Considerations
!
!       Don'T Allow Irrigation If Before The First Delivery Date
!       Of If After November 1 For Alfalfa And Grass Or If After The
!       Maturity Date For Other Crops.
!
! For Stress Irrigation of Alfalfa And Grass There Is Also a Period
! Between JSTOPI And JGOI When Irrigation Is Not Allowed
!-----------------------------------------------------------------------

      SUBROUTINE IRRIGA

      USE PARM
	  REAL    RAINSTOR
      INTEGER ICYCLE,ISTAGE

      NETIRR=0.0
      GROIRR=0.0

      ISTAGE=KSTG
      IF(KSTG .EQ. 0) ISTAGE=ICUT
 
      RAINSTOR = RAINAL(ISTAGE) * DPLA
!-------------------------------------------------------------------------
!   Irrigation Scheduled By Allowable Depletion
!   Only Allow Irrigation If The Gross Irrigation Required Is Larger Than
!   The Smallest Allowable Irrigation.  This Is The Smallest Depth That
!   That Will Be Allowed Even Though Leaching May Occur If The Actual
!   Irrigation With The Existing System Exceeds This Amount.
!   The Smallest Allowable Irrigation Is The Minimum Amount That Would Be
!   Practical With The Irrigation System Regardless Of Crop Needs.
!-------------------------------------------------------------------------


      IF(IRRSCH.LT.3) THEN

        IF(AWDPLN.LT.DPLA) GOTO 900
        IF((GDD.LT.GSTART).OR.(GDD.GE.GSTOP)) GOTO  900
        IF(TODAY+1.LT.JNEXTI) GOTO  900

        NETIRR = DPLN - RAINSTOR
        GROIRR = NETIRR/EAPP(ISTAGE)

!		WRITE(6,*) ' Sched ',jday,jnexti, irrsch, dpla,awdpln,dpln, netirr

        IF(GROIRR.LT.SMALLI(ISTAGE)) THEN
            NETIRR=0.0
            GROIRR=0.0
            DINF=0.0
            GOTO  900

          ELSE

            IF(GROIRR.LT.APMIN(ISTAGE)) GROIRR = APMIN(ISTAGE)
            IF(GROIRR.GT.APMAX(ISTAGE)) GROIRR = APMAX(ISTAGE)
            NETIRR = GROIRR*EAPP(ISTAGE)
        ENDIF


!- For Surface Irrigation Systems Runoff And Reuse Losses Are Considered
        IF(IRRTYP.EQ.4) THEN
              DINF=GROIRR*(1.0-(1.0-EREUSE(ISTAGE))*PRUNOF(ISTAGE))
          ELSE
              DINF=NETIRR
        END IF

        CYCLET = GROIRR /(SYSCAP*IPER(ISTAGE))
        
        JNEXTI = AMAX1(TODAY,JNEXTI) + CYCLET
        
        IRIGNO = IRIGNO + 1
        IF (IRIGNO.EQ.1) JFIRST = JDAY


      END IF

!-------------------------------------------------------------------------
!   Fixed Delivery Schedule For Rotation Systems
!   Check If Water Is Needed.  Irrigate If The Depletion Minus The
!   Rainfall Allowance Exceeds The Smallest Allowable Irrigation.
!-------------------------------------------------------------------------

      IF(IRRSCH.EQ.3) THEN
        SOILMD = AWDPLN - RAINSTOR

        IF(SOILMD.LE.EAPP(ISTAGE)*SMALLI(ISTAGE)) THEN
              NETIRR=0.0
              GROIRR=0.0
              DINF=0.0
            ELSE
              GROIRR=DDEPTH
              NETIRR=DDEPTH*EAPP(ISTAGE)

              IF(IRRTYP.GT.3) THEN
                 DINF=GROIRR*(1.0-(1.0-EREUSE(ISTAGE))*PRUNOF(ISTAGE))
               ELSE
                 DINF=NETIRR
              END IF

              IRIGNO=IRIGNO+1
              IF(IRIGNO.EQ.1) JFIRST=JDAY
         ENDIF
      ENDIF


!=========================================================================
!	SCHEDULING WITH KNOWN FUTURE RAINFALL 
!
!=========================================================================

	  IF (IRRSCH.EQ.4) THEN

        IF(JDAY.LT.JNEXTI) GOTO  900
        IF((GDD.LT.GSTART).OR.(GDD.GE.GSTOP)) GOTO  900

!   Compute rain and crop ET for the forecast period

		FORCRAIN = 0.0

		DO JDSCH = JDAY+1,JDAY + NFDAY
          FORCRAIN = FORCRAIN + PRECIP(JDSCH)
		END DO

!  Can delay irrigation if the forecast rain will meet needs 

        IF((AWDPLN - FORCRAIN).LT.DPLA) THEN 
            NETIRR  =  0.
          ELSE
		    NETIRR  =  AMAX1(DPLN - RAINSTOR, 0.)
        END IF


        GROIRR=NETIRR/EAPP(ISTAGE)

        IF(GROIRR.LT.SMALLI(ISTAGE)) THEN
            NETIRR=0.0
            GROIRR=0.0
            DINF=0.0

          ELSE
            IF(GROIRR.LT.APMIN(ISTAGE))GROIRR=APMIN(ISTAGE)
            IF(GROIRR.GT.APMAX(ISTAGE))GROIRR=APMAX(ISTAGE)
            NETIRR=GROIRR*EAPP(ISTAGE)
        ENDIF


!- For Surface Irrigation Systems Runoff And Reuse Losses Are Considered
        IF(IRRTYP.EQ.4) THEN
              DINF=GROIRR*(1.0-(1.0-EREUSE(ISTAGE))*PRUNOF(ISTAGE))
          ELSE
              DINF=NETIRR
        END IF

        CYCLET=GROIRR/(SYSCAP*IPER(ISTAGE))
         
        JNEXTI = AMAX1(TODAY,JNEXTI) + CYCLET 
 
        IRIGNO = IRIGNO + 1
        IF (IRIGNO.EQ.1) JFIRST = JDAY
 
	  ENDIF

!=========================================================================
!
!	SCHEDULING WITH KNOWN FUTURE RAINFALL AND ET 
!
!=========================================================================

	  IF (IRRSCH.EQ.5) THEN

        IF(JDAY.LT.JNEXTI) GOTO  900
        IF((GDD.LT.GSTART).OR.(GDD.GE.GSTOP)) GOTO  900

!   Compute rain and crop ET for the forecast period

		FORCRAIN = 0.0
		FORCET	 = 0.0

		DO JDSCH = JDAY+1,JDAY + NFDAY
          FORCRAIN = FORCRAIN + PRECIP(JDSCH)
		  FORCET   = FORCET   + ETR(JDSCH)*CROPKC(JDSCH)
		END DO

!  Can delay irrigation if the forecast rain will meet needs 


        IF((AWDPLN.LT.DPLA).OR.(FORCRAIN.GT.1.0)) THEN 
            NETIRR  =  0.
          ELSE
		    NETIRR  =  AMAX1(DPLN - RAINSTOR, 0.)
        END IF


        GROIRR=NETIRR/EAPP(ISTAGE)

        IF(GROIRR.LT.SMALLI(ISTAGE)) THEN
            NETIRR=0.0
            GROIRR=0.0
            DINF=0.0

          ELSE
            IF(GROIRR.LT.APMIN(ISTAGE))GROIRR=APMIN(ISTAGE)
            IF(GROIRR.GT.APMAX(ISTAGE))GROIRR=APMAX(ISTAGE)
            NETIRR=GROIRR*EAPP(ISTAGE)
        ENDIF


!- For Surface Irrigation Systems Runoff And Reuse Losses Are Considered
        IF(IRRTYP.EQ.4) THEN
              DINF=GROIRR*(1.0-(1.0-EREUSE(ISTAGE))*PRUNOF(ISTAGE))
          ELSE
              DINF=NETIRR
        END IF

        CYCLET=GROIRR/(SYSCAP*IPER(ISTAGE))
        JNEXTI = AMAX1(TODAY,JNEXTI) + CYCLET

        IRIGNO = IRIGNO + 1
        IF (IRIGNO.EQ.1) JFIRST = JDAY

	  ENDIF


900   CONTINUE

      RETURN
      END SUBROUTINE IRRIGA

!**********************************************************************
!   CROPCO SUBROUTINE  -- Compute Daily Crop Coefficient

      SUBROUTINE CROPCO

      USE PARM
      REAL KCINI,KCMID,KCEND
 !-----------------------------------------------------------------------
!   Crops 1 - 7 Represent Spring Grains, Edible Beans, Soybeans,
!   Potatoes, Sugar Beets, Grain Sorghum (Milo), Winter Wheat.
!   The Crop Coefficients For These Crops Are Based On Data From
!   Jim Wright (1982)
!-----------------------------------------------------------------------

      IF(CROP.LE.7) THEN
        IF (JDAY.LE.JDYEFC) THEN
            IEFC = 1
            PCT=FLOAT(JDAY-JDYPLT)/FLOAT(JDYEFC-JDYPLT)
          ELSE
            IEFC=2
            PCT=FLOAT(JDAY-JDYEFC)/100.
        ENDIF

        IF ((PCT.GE.0.0).AND.(PCT.LE.1.0)) THEN

            IPCT = PCT/0.10

            IF((IPCT.GT.0).AND.(IPCT.LT.10)) KC=CC(CROP,IEFC,IPCT) +	&
              10*AMOD(PCT,0.1)*(CC(CROP,IEFC,IPCT+1)-CC(CROP,IEFC,IPCT))

            IF((IPCT.EQ.0).AND.(IEFC.EQ.1)) KC=KCL(CROP) +				&
              10*AMOD(PCT,0.1)*(CC(CROP,IEFC,1)-KCL(CROP))

            IF((IEFC.EQ.2).AND.(PCT.LT.0.1)) KC=CC(CROP,IEFC,1)   + 	&
              10*AMOD(PCT,0.1)*(CC(CROP,IEFC,2)-CC(CROP,IEFC,1))

            IF(IPCT.EQ.10) KC = CC(CROP,IEFC,10)
          
		  ELSE
            KC = KCL(CROP)
        ENDIF

        IF (CROP.EQ.7) THEN
            IF((JFPLT.GT.0).AND.(JDAY.GE.JFPLT))   KC = 0.25
        ENDIF
!       JFPLT is the date for fall planting of winter wheat

        IF(KC.GT.KCU(CROP)) KC = KCU(CROP)
		IF(KC.LT.KCL(CROP)) KC = KCL(CROP)

      ENDIF
!=======================================================================

!=======================================================================
!---  Corn = 8     Kc From Bill Kranz
!---  Values From Watts (1982) And Stegman(1988)

      IF (CROP.EQ.8) THEN
        KC=KCU(CROP)
        IF(GDD.LT.0.42*GDDMAT)KC=0.15+.85*(GDD-0.12*GDDMAT)/(0.3*GDDMAT)
        IF(GDD.LE.0.12*GDDMAT)KC=0.15
        IF(GDD.GT.0.78*GDDMAT)KC=1.0-0.7*(GDD-0.78*GDDMAT)/(0.22*GDDMAT)
        IF(GDD.GT.GDDMAT) KC=0.15
        IF(KC.GT.KCU(CROP)) KC=KCU(CROP)
        IF(KC.LT.0.15) KC=0.15
      ENDIF
!=======================================================================

!=======================================================================
!   Crop = 9 Represents Sunflowers.  Crop Coefficients Are Based On
!   development stages from FAO and coefficient Values from Aiken and Lamm

      IF(CROP.EQ.9) THEN
        FS1 = 0.192
        FS2 = 0.462
        FS3 = 0.808

        KCINI = 0.15
        KCMID = 1.00
        KCEND = 0.30

        FGS = GDD/GDDMAT
        IF(FGS.LE.FS1) KC = KCINI

        IF((FGS.GT.FS1).AND.(FGS.LT.FS2))                              &
           KC=KCINI+(KCMID-KCINI)*(FGS-FS1)/(FS2-FS1)

        IF((FGS.GE.FS2).AND.(FGS.LE.FS3)) KC = KCMID

        IF((FGS.GT.FS3).AND.(FGS.LE.1.0))                              &
           KC = KCMID-(KCMID-KCEND)*(FGS-FS3)/(1.0-FS3)

        IF(FGS.GT.1.0) KC = KCINI
      ENDIF
!=======================================================================


!=======================================================================
!------Alfalfa = 10   Kc From Wright (1982)
!     JDYPLT     = Greenup Date
!     JDYCUT(I)  = Julian Date Of Cutting I
!     JDYFRZ     = Freeze Date
!     NCUT       = Number of Cuttings

      IF(CROP.EQ.10) THEN

        IF(JDAY.LT.JDYCUT(1)) THEN
          ICUT = 1
          IEFC = 1
        END IF

        IF((JDAY.GE.JDYCUT(1)).AND.(JDAY.LT.JDYCUT(2))) THEN
          ICUT = 2
          IEFC = 2
        END IF

        IF((JDAY.GT.JDYCUT(2)).AND.(JDAY.LT.JDYCUT(3))) THEN
          ICUT = 3
          IEFC = 2
        END IF

        IF((JDAY.GT.JDYCUT(3)).AND.(JDAY.LT.JDYCUT(4))) THEN
          ICUT = 4
          IEFC = 2
        END IF

        IF((JDAY.GT.JDYCUT(4)).AND.(JDAY.LT.JDYCUT(5))) THEN
          ICUT = 5
          IEFC = 2
        END IF

        IF(JDAY.GE.JDYCUT(NCUT)) THEN
          ICUT = NCUT
          IEFC = 3
        END IF

!-----Compute The Percent Time For Each Stage

        IF((ICUT.EQ.1).AND.(JDAY.GE.JDYPLT))                       &
          PCT=REAL(JDAY-JDYPLT)/REAL(JDYCUT(1)-JDYPLT)

        IF (ICUT.EQ.2) THEN
          IF(IEFC.EQ.2) THEN
              PCT=REAL(JDAY-JDYCUT(1))/ REAL(JDYCUT(2)-JDYCUT(1))
            ELSE
              PCT=REAL(JDAY-JDYCUT(1))/ REAL(305-JDYCUT(1))
          ENDIF
        ENDIF

        IF (ICUT.EQ.3) THEN
          IF(IEFC.EQ.2) THEN
              PCT=REAL(JDAY-JDYCUT(2))/REAL(JDYCUT(3)-JDYCUT(2))
            ELSE
              PCT=REAL(JDAY-JDYCUT(3))/ REAL(305-JDYCUT(3))
          ENDIF
        ENDIF

        IF (ICUT.EQ.4) THEN
          IF(IEFC.EQ.2) THEN
              PCT=REAL(JDAY-JDYCUT(3))/REAL(JDYCUT(4)-JDYCUT(3))
            ELSE
              PCT=REAL(JDAY-JDYCUT(4))/ REAL(305-JDYCUT(4))
          ENDIF
        ENDIF

        IF (ICUT.EQ.5) THEN
          IF(IEFC.EQ.2) THEN
              PCT=REAL(JDAY-JDYCUT(4))/REAL(JDYCUT(5)-JDYCUT(4))
            ELSE
              PCT=REAL(JDAY-JDYCUT(5))/ REAL(305-JDYCUT(5))
          ENDIF
        ENDIF

        IF((JDAY.LE.JDYPLT).OR.(JDAY.GE.305)) KC=KCL(CROP)

        IPCT = INT(PCT/0.1)

        IF((IPCT.GT.0).AND.(IPCT.LT.10))KC=CC(CROP,IEFC,IPCT) +        &
           10*AMOD(PCT,0.1)*(CC(CROP,IEFC,IPCT+1)-CC(CROP,IEFC,IPCT))

        IF( IPCT.EQ.0 ) KC=KCL(CROP)+                                  &
           10*AMOD(PCT,0.1)*(CC(CROP,IEFC,IPCT+1)-KCL(CROP))

        IF( IPCT.EQ.10) KC = CC(CROP,IEFC,10)

      ENDIF
!=======================================================================

!=======================================================================
!   Crop 11 Represents Irrigated Hay That Is Cut Once Annually.
!   Crop Coefficients Are Based On FAO Values Adjusted For An Alfalfa
!   Reference Crop And Weather Conditions Typical Of Nebraska.
!     JDYPLT     = Greenup Date
!     JDYCUT(I)  = Julian Date Of Cutting I
!     JDYFRZ     = Freeze Date

      IF(CROP.EQ.11) THEN

        FS1 = 0.036
        FS2 = 0.109
        FS3 = 0.927

        KCINI = 0.243
        KCMID = 0.750
        KCEND = 0.669

        IF(JDAY.EQ.JDYCUT(1)) GDDCUT = GDD

        IF(JDAY.LT.JDYCUT(1)) THEN
            FGS = GDD/GDDMAT
          ELSE
            FGS = (GDD-GDDCUT)/(GDDMAT-GDDCUT)
        END IF

        IF(FGS.LE.FS1) KC = KCINI

        IF((FGS.GT.FS1).AND.(FGS.LT.FS2))                              &
          KC=KCINI+(KCMID-KCINI)*(FGS-FS1)/(FS2-FS1)

        IF((FGS.GE.FS2).AND.(FGS.LE.FS3)) KC = KCMID

        IF((FGS.GT.FS3).AND.(FGS.LE.1.0))                              &
          KC = KCMID-(KCMID-KCEND)*(FGS-FS3)/(1.0-FS3)

        IF(FGS.GT.1.0) KC = KCINI
      ENDIF
!=======================================================================

!=======================================================================
!   Crop 12 Represents Irrigated Pature. Crop Coefficients Are Based On
!   FAOValues Adjusted For An Alfalfa Reference Crop And Weather
!   Conditions Typical Of Nebraska.

      IF(CROP.EQ.12) THEN
        FS1 = 0.036
        FS2 = 0.109
        FS3 = 0.927

        KCINI = 0.243
        KCMID = 0.750
        KCEND = 0.669

        FGS = GDD/GDDMAT
        IF(FGS.LE.FS1) KC = KCINI

        IF((FGS.GT.FS1).AND.(FGS.LT.FS2))                              &
           KC=KCINI+(KCMID-KCINI)*(FGS-FS1)/(FS2-FS1)

        IF((FGS.GE.FS2).AND.(FGS.LE.FS3)) KC = KCMID

        IF((FGS.GT.FS3).AND.(FGS.LE.1.0))                              &
           KC = KCMID-(KCMID-KCEND)*(FGS-FS3)/(1.0-FS3)

        IF(FGS.GT.1.0) KC = KCINI
      ENDIF
!=======================================================================

!=======================================================================
!   Crop 13 Represents Native Pature. Crop Coefficients Are Based On
!   FAOValues Adjusted For An Alfalfa Reference Crop And Weather
!   Conditions Typical Of Nebraska.

      IF(CROP.EQ.13) THEN
        FS1 = 0.036
        FS2 = 0.109
        FS3 = 0.927

        KCINI = 0.243

!  Original KC values
        KCMID = 0.587
        KCEND = 0.587

!  Adjuste KC values  5-26-03
!        KCMID = 0.65
!        KCEND = 0.65

        FGS = GDD/GDDMAT
        IF(FGS.LE.FS1) KC = KCINI

        IF((FGS.GT.FS1).AND.(FGS.LT.FS2))                              &
           KC=KCINI+(KCMID-KCINI)*(FGS-FS1)/(FS2-FS1)

        IF((FGS.GE.FS2).AND.(FGS.LE.FS3)) KC = KCMID

        IF((FGS.GT.FS3).AND.(FGS.LE.1.0))                              &
           KC = KCMID-(KCMID-KCEND)*(FGS-FS3)/(1.0-FS3)

        IF(FGS.GT.1.0) KC = KCINI
      ENDIF
!=======================================================================

!=======================================================================
!   Crop 14 Represents Urban Turf. Crop Coefficients Are Based On
!   FAOValues Adjusted For An Alfalfa Reference Crop And Weather
!   Conditions Typical Of Nebraska.

      IF(CROP.EQ.14) THEN
        FS1 = 0.036
        FS2 = 0.073
        FS3 = 1.000

        KCINI = 0.688
        KCMID = 0.746
        KCEND = 0.746

        FGS = GDD/GDDMAT
        IF(FGS.LE.FS1) KC = KCINI

        IF((FGS.GT.FS1).AND.(FGS.LT.FS2))                              &
           KC=KCINI+(KCMID-KCINI)*(FGS-FS1)/(FS2-FS1)

        IF((FGS.GE.FS2).AND.(FGS.LE.FS3)) KC = KCMID

        IF((FGS.GT.FS3).AND.(FGS.LE.1.0))                              &
           KC = KCMID-(KCMID-KCEND)*(FGS-FS3)/(1.0-FS3)

        IF(FGS.GT.1.0) KC = KCINI
      ENDIF
!=======================================================================

!=======================================================================
!   Crop 15 Represents Summer Fallow. Crop Coefficients Are Based On
!   FAOValues Adjusted For An Alfalfa Reference Crop And Weather
!   Conditions Typical Of Nebraska.

      IF(CROP.EQ.15) THEN
        FS1 = 0.00
        FS2 = 0.10
        FS3 = 1.00

        KCINI = 0.150
        KCMID = 0.150
        KCEND = 0.150

        FGS = GDD/GDDMAT
        IF(FGS.LE.FS1) KC = KCINI

        IF((FGS.GT.FS1).AND.(FGS.LT.FS2))                              &
           KC=KCINI+(KCMID-KCINI)*(FGS-FS1)/(FS2-FS1)

        IF((FGS.GE.FS2).AND.(FGS.LE.FS3)) KC = KCMID

        IF((FGS.GT.FS3).AND.(FGS.LE.1.0))                              &
           KC = KCMID-(KCMID-KCEND)*(FGS-FS3)/(1.0-FS3)

        IF(FGS.GT.1.0) KC = KCINI
      ENDIF
!=======================================================================

!=======================================================================
!   Crop 16 Represents Riparian Woodlands. Crop Coefficients Are Based On
!   FAOValues Adjusted For An Alfalfa Reference Crop And Weather
!   Conditions Typical Of Nebraska.

      IF(CROP.EQ.16) THEN
        FS1 = 0.105
        FS2 = 0.158
        FS3 = 0.842

        KCINI = 0.364
        KCMID = 1.082
        KCEND = 0.798

        FGS = GDD/GDDMAT
        IF(FGS.LE.FS1) KC = KCINI

        IF((FGS.GT.FS1).AND.(FGS.LT.FS2))                              &
           KC=KCINI+(KCMID-KCINI)*(FGS-FS1)/(FS2-FS1)

        IF((FGS.GE.FS2).AND.(FGS.LE.FS3)) KC = KCMID

        IF((FGS.GT.FS3).AND.(FGS.LE.1.0))                              &
           KC = KCMID-(KCMID-KCEND)*(FGS-FS3)/(1.0-FS3)

        IF(FGS.GT.1.0) KC = KCINI
      ENDIF
!=======================================================================

!=======================================================================
!   Crop 17 Represents Non-riparian Woodlands. Crop Coefficients Are
!   Based On FAO Values Adjusted For An Alfalfa Reference Crop And Weather
!   Conditions Typical Of Nebraska.

      IF(CROP.EQ.17) THEN
        FS1 = 0.105
        FS2 = 0.158
        FS3 = 0.842

        KCINI = 0.547
        KCMID = 0.873
        KCEND = 0.691

        FGS = GDD/GDDMAT
        IF(FGS.LE.FS1) KC = KCINI

        IF((FGS.GT.FS1).AND.(FGS.LT.FS2))                              &
           KC=KCINI+(KCMID-KCINI)*(FGS-FS1)/(FS2-FS1)

        IF((FGS.GE.FS2).AND.(FGS.LE.FS3)) KC = KCMID

        IF((FGS.GT.FS3).AND.(FGS.LE.1.0))                              &
           KC = KCMID-(KCMID-KCEND)*(FGS-FS3)/(1.0-FS3)

        IF(FGS.GT.1.0) KC = KCINI
      ENDIF
!=======================================================================

!=======================================================================
!   Crop 18 Represents Cattail Wetlands. Crop Coefficients Are Based On
!   FAOValues Adjusted For An Alfalfa Reference Crop And Weather
!   Conditions Typical Of Nebraska.

      IF(CROP.EQ.18) THEN
        FS1 = 0.071
        FS2 = 0.286
        FS3 = 0.857

        KCINI = 0.243
        KCMID = 1.011
        KCEND = 0.282

        FGS = GDD/GDDMAT
        IF(FGS.LE.FS1) KC = KCINI

        IF((FGS.GT.FS1).AND.(FGS.LT.FS2))                              &
           KC=KCINI+(KCMID-KCINI)*(FGS-FS1)/(FS2-FS1)

        IF((FGS.GE.FS2).AND.(FGS.LE.FS3)) KC = KCMID

        IF((FGS.GT.FS3).AND.(FGS.LE.1.0))                              &
           KC = KCMID-(KCMID-KCEND)*(FGS-FS3)/(1.0-FS3)

        IF(FGS.GT.1.0) KC = KCINI
      ENDIF
!=======================================================================

!=======================================================================
!   Crop 19 Represents Reed/Swamp Wetlands. Crop Coefficients Are Based
!   OnFAO Values Adjusted For An Alfalfa Reference Crop And Weather
!   Conditions Typical Of Nebraska.

      IF(CROP.EQ.19) THEN
        FS1 = 0.036
        FS2 = 0.109
        FS3 = 1.000

        KCINI = 0.729
        KCMID = 1.011
        KCEND = 0.606

        FGS = GDD/GDDMAT
        IF(FGS.LE.FS1) KC = KCINI

        IF((FGS.GT.FS1).AND.(FGS.LT.FS2))                              &
           KC=KCINI+(KCMID-KCINI)*(FGS-FS1)/(FS2-FS1)

        IF((FGS.GE.FS2).AND.(FGS.LE.FS3)) KC = KCMID

        IF((FGS.GT.FS3).AND.(FGS.LE.1.0))                              &
           KC = KCMID-(KCMID-KCEND)*(FGS-FS3)/(1.0-FS3)

        IF(FGS.GT.1.0) KC = KCINI
      ENDIF
!=======================================================================

!=======================================================================
!   Crop 20 Represents Shallow Open Water. Crop Coefficients Are Based
!   OnFAO Values Adjusted For An Alfalfa Reference Crop And Weather
!   Conditions Typical Of Nebraska.

      IF(CROP.EQ.20) THEN
        FS1 = 0.010
        FS2 = 0.100
        FS3 = 1.000

        KCINI = 0.800
        KCMID = 0.800
        KCEND = 0.800

        FGS = GDD/GDDMAT
        IF(FGS.LE.FS1) KC = KCINI

        IF((FGS.GT.FS1).AND.(FGS.LT.FS2))                              &
           KC=KCINI+(KCMID-KCINI)*(FGS-FS1)/(FS2-FS1)

        IF((FGS.GE.FS2).AND.(FGS.LE.FS3)) KC = KCMID

        IF((FGS.GT.FS3).AND.(FGS.LE.1.0))                              &
           KC = KCMID-(KCMID-KCEND)*(FGS-FS3)/(1.0-FS3)

        IF(FGS.GT.1.0) KC = KCINI
      ENDIF
!=======================================================================

!=======================================================================
!   Crop 21 Represents Deep Open Water. Crop Coefficients Are Based On
!   FAOValues Adjusted For An Alfalfa Reference Crop And Weather
!   Conditions Typical Of Nebraska.

      IF(CROP.EQ.21) THEN
        FS1 = 0.010
        FS2 = 0.100
        FS3 = 1.000

        KCINI = 0.526
        KCMID = 0.526
        KCEND = 1.012

        FGS = GDD/GDDMAT
        IF(FGS.LE.FS1) KC = KCINI

        IF((FGS.GT.FS1).AND.(FGS.LT.FS2))                              &
           KC=KCINI+(KCMID-KCINI)*(FGS-FS1)/(FS2-FS1)

        IF((FGS.GE.FS2).AND.(FGS.LE.FS3)) KC = KCMID

        IF((FGS.GT.FS3).AND.(FGS.LE.1.0))                              &
           KC = KCMID-(KCMID-KCEND)*(FGS-FS3)/(1.0-FS3)

        IF(FGS.GT.1.0) KC = KCINI
      ENDIF
!=======================================================================

!=======================================================================
!   Crop 22 Represents Farmsteads/Residential. Crop Coefficients Are
!   Based On FAO Values Adjusted For An Alfalfa Reference Crop And
!   Weather Conditions Typical Of Nebraska.

      IF(CROP.EQ.22) THEN
        FS1 = 0.036
        FS2 = 0.109
        FS3 = 0.927

        KCINI = 0.243
        KCMID = 0.587
        KCEND = 0.587

        FGS = GDD/GDDMAT
        IF(FGS.LE.FS1) KC = KCINI

        IF((FGS.GT.FS1).AND.(FGS.LT.FS2))                              &
           KC=KCINI+(KCMID-KCINI)*(FGS-FS1)/(FS2-FS1)

        IF((FGS.GE.FS2).AND.(FGS.LE.FS3)) KC = KCMID

        IF((FGS.GT.FS3).AND.(FGS.LE.1.0))                               &
           KC = KCMID-(KCMID-KCEND)*(FGS-FS3)/(1.0-FS3)

        IF(FGS.GT.1.0) KC = KCINI
      ENDIF
!=======================================================================

!    Check Bounds On Crop Coefficients

      IF(JDAY.GT.JDYFRZ)  KC=KCL(CROP)
      IF(KC.LT.KCL(CROP)) KC=KCL(CROP)
      IF(KC.GT.KCU(CROP)) KC=KCU(CROP)

      RETURN
      END SUBROUTINE CROPCO
!========================================================================

!***********************************************************************
        SUBROUTINE READWEAT
!-----------------------------------------------------------------------
!       Read and Process Weather Data
!-----------------------------------------------------------------------
        USE PARM

        IF(.NOT.LIBMODE) READ(1,40)(LOCATE(I), I=1,80)  !LIB
40      FORMAT(80A1)

        IF(.NOT.LIBMODE) READ(1,45)IMSTR,IDSTR,NDAYS,LAT,LONG,ELEV  !LIB
45      FORMAT(2I3,I6,7X,F7.2,8X,F8.2,12X,F8.0)

        CALL DAYOFYR(JDYSTR,IMSTR,IDSTR)
        IF(.NOT.LIBMODE) READ(1,*)ETHEAD  !LIB
		NDAYS = 0

!-----        Set Defaults For First Days Of Simulation For Weather
        TMAXA=55
        TMINA=30
        ETRA=0.10
        PRECIPA=0.0

        DO I=1,366
          ETR(I)=0.
          PRECIP(I)=0.
          TMAX(I)=0.
          TMIN(I)=0.
          GDDS(I)=0.
          SOLAR(I)=0.
        END DO

        I=JDYSTR
100     IF (LIBMODE) THEN                       !LIB
          IF ((I-JDYSTR+1.GT.WX_NDAYS).OR.(I.GT.366)) GOTO 200   !LIB
          TMAX(I)   = WX_TMAX(I-JDYSTR+1)     !LIB
          TMIN(I)   = WX_TMIN(I-JDYSTR+1)     !LIB
          PRECIP(I) = WX_PRECIP(I-JDYSTR+1)   !LIB
          EPAN(I)   = WX_EPAN(I-JDYSTR+1)     !LIB
          ETR(I)    = WX_ETR(I-JDYSTR+1)      !LIB
        ELSE                                    !LIB
          READ(1,*,END=200) IDATE,TMAX(I),TMIN(I),PRECIP(I),EPAN(I),ETR(I)
        END IF                                  !LIB

          NDAYS=NDAYS+1
          IF((TMAX(I).LT.-50.).OR.(TMAX(I).GT.125.))  TMAX(I)=TMAXA
          IF((TMIN(I).LT.-50.).OR.(TMIN(I).GT.100.))  TMIN(I)=TMINA
          IF((PRECIP(I).LT.0.).OR.(PRECIP(I).GT.10.)) PRECIP(I)=PRECIPA
          IF((ETR(I).LT.0.).OR.(ETR(I).GT.0.6))       ETR(I) =ETRA

          IF ((I-JDYSTR).GE.3) THEN
            TMAXA=(TMAX(I)+TMAX(I-1)+TMAX(I-2))/3.0
            TMINA=(TMIN(I)+TMIN(I-1)+TMIN(I-2))/3.0
            PRECIPA=(PRECIP(I)+PRECIP(I-1)+PRECIP(I-2))/3.0
            ETRA= (ETR(I)+ETR(I-1)+ETR(I-2))/3.0
          ENDIF


!  Reduce Reference Crop ET for Field Values and High Values from HPCC

		  ETR(I) = ETRFACT * ETR(I)

	      I=I+1

          GOTO 100

200     JDYSTP=JDYSTR+NDAYS-1


!---    Calculate The Growing Degree Days

        JDYFRZ=0

        DO I = 1, 366
		  GDDS(I) = 0.0
		END DO

        DO I=JDYPLT,JDYEND
          T1=TMAX(I)
          IF(T1.GE.TCEIL(CROP))T1=TCEIL(CROP)
          IF(T1.LT.TBASE(CROP))T1=TBASE(CROP)
          T2=TMIN(I)
          IF(T2.LE.TBASE(CROP))T2=TBASE(CROP)
          IF(T2.GT.TCEIL(CROP))T2=TCEIL(CROP)
          GDD=(T1+T2)/2.-TBASE(CROP)
          IF(GDD.LT.0.)GDD=0.
          GDDS(I)=GDDS(I-1) + GDD

!---   Determine First Killing Freeze Date
          IF(TMIN(I) .GE. 26.) GOTO 225
          IF(I .LT. 200) GOTO 225
          IF (JDYFRZ .LT. 1) JDYFRZ=I
225     END DO

        IF(JDYFRZ .LT. 1)  JDYFRZ=JDYEND
        IF(JDYSTR.GT.JDYBG)JDYBG=JDYSTR

!---  Calculate Development, Maturity And Cover Dates Based On Gdd
!---  Skip Calculation Of Development Dates For Non Row Crops


        IF (CROP.GE.10) THEN
            JDYMAT=JDYFRZ
!************************************************************
!Added to address JDYEFC calc for crops >=10.  Computing
!Effectice Cover day from GDDs since input planting date

			DO I=JDYPLT,JDYEND
				IF(GDDS(I).GE.GDDEFC) GOTO 305
			ENDDO
305			JDYEFC=I
!************************************************************
            GOTO 400

          ELSE
              DO I=JDYPLT,JDYEND
                IF(GDDS(I).GE.GDDEFC) GOTO 310
              END DO
310         JDYEFC=I

            DO I=JDYPLT,JDYEND
              IF(GDDS(I).GE.GDDMAT)GOTO 320
            END DO
320         JDYMAT=I
            IF(JDYMAT.GT.JDYFRZ) JDYMAT=JDYFRZ

            DO I=JDYPLT,JDYEND
              IF(GDDS(I).GE.GDDFLO) GOTO 330
            END DO
330         JDYFLO=I

            DO I=JDYPLT,JDYEND
              IF(GDDS(I).GE.GDDRIPE) GOTO 340
            END DO
340         JDYRIPE=I

            DO I=JDYPLT,JDYEND
              IF(GDDS(I).GE.GDDVEG)GOTO 350
            END DO
350         JDYVEG=I
        ENDIF


!======================================================
!  Compute daily value of crop coefficients
!

400		DO JDAY = JDYSTR, JDYSTP
          CALL CROPCO
		  GDD=GDDS(JDAY)
		  CROPKC(JDAY) = KC
		END DO 		

!======================================================

        TANUAL = 0.0
        TAMP = 0.0
        AIRMAX = 0.0
        AIRMIN = 0.0

        DO I = 1, JDYSTP
          DAY = I
          TAVG = 0.5 * ( TMAX(I) + TMIN(I) )
          RSOA   = 753.6 - 6.53 * LAT + 0.0057*ELEV
          RSOB   = -7.1 + 6.4 * LAT + 0.0030 * ELEV
          RSO    = RSOA + RSOB * COS (2*3.14159*(DAY-170)/365)
          DELTAT = TMAX(I) - TMIN(I)

          IF ( PRECIP(I).GT.0.2) THEN

              SOLAR(I) = RSO*EXP(0.0146*TAVG)                          &
                        /(1.+EXP(- DELTAT/36.301))**3.6795
            ELSE
              SOLAR(I) = RSO*EXP(7.82E-4*TAVG)                         &
                           /(1.+EXP(- DELTAT/9.4619))**3.6142
          ENDIF

          TANUAL = TANUAL + TAVG
  		  IF(TMAX(I).GT.AIRMAX) AIRMAX = TMAX(I)
          IF(TMIN(I).LT.AIRMIN) AIRMIN = TMIN(I)

        END DO

        TAMP = AIRMAX - AIRMIN
        TANUAL = TANUAL / NDAYS

       RETURN
       END SUBROUTINE READWEAT
!***********************************************************************
!***********************************************************************
      SUBROUTINE SOILTEMP

!!    ~ ~ ~ PURPOSE ~ ~ ~
!!    This subroutine estimates daily average temperature at the bottom
!!    of each soil layer

!!    ~ ~ ~ INCOMING VARIABLES ~ ~ ~
!!    name        |units         |definition
!!    ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
!!    ALB         |none          |albedo of ground for day
!!    LAYERS      |none          |number of soil layers in profile
!!    SNOH2O      |inches H2O    |amount of water as snow
!!    BULKD       |Mg/m^3        |average bulk density of soil profile
!!    RESIDUE     |lb/acre       |amount of residue on soil surface
!!    TOTWAT      |inches H2O    |amount of water stored in soil profile
!!    SOILT       |deg F         |average temperature of soil layer
!!    TOTDEP      |inches        |depth to bottom of soil layer
!!    TMIN        |deg F         |minimum temperature for the day
!!    TANUAL      |deg F         |average annual air temperature
!!    TAVG        |deg F         |average temperature for the day
!!    TMAX        |deg F         |maximum temperature for the day
!!    ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~

!!    ~ ~ ~ OUTGOING VARIABLES ~ ~ ~
!!    name        |units         |definition
!!    ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
!!    SOILT       |deg F         |daily average temperature of soil layer
!!    ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~

!!    ~ ~ ~ LOCAL DEFINITIONS ~ ~ ~
!!    name        |units         |definition
!!    ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
!!    B           |none          |variable to hold intermediate calculation
!!    BCV         |none          |lagging factor for cover
!!    DD          |mm            |damping depth for day
!!    DF          |none          |depth factor
!!    DP          |inches        |maximum damping depth
!!    F           |none          |variable to hold intermediate calculation
!!                               |result
!!    K           |none          |counter
!!    STO         |MJ/m^2        |radiation hitting soil surface on day
!!    TBARE       |deg C         |temperature of bare soil surface
!!    TCOV        |deg C         |temperature of soil surface corrected for cover
!!    TLAG        |none          |lag coefficient for soil temperature
!!    SURFTEMP    |deg F         |temperature of soil surface
!!    WC          |none          |scaling factor for soil water impact on daily damping depth
!!    WW          |none          |variable to hold intermediate calculation
!!    XX          |none          |variable to hold intermediate calculation
!!    ZD          |none          |ratio of depth at center of layer to damping depth
!!    ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~


      USE PARM

      REAL :: F, DP, WW, B, WC, DD, XX, STO
      REAL :: TLAG, DF, ZD, BCV, TCOV

      TLAG = 0.8

!! calculate damping depth
      !! calculate maximum damping depth
      !! SWAT manual equation 2.3.6

      F = 0.
      DP = 0.

      F = BULKD / (BULKD + 686. * EXP(-5.63 * BULKD) )
      DP = 39.4 + 98.4 * F

      !! calculate scaling factor for soil water
      !! SWAT manual equation 2.3.7
      WW = 0.
      WC = 0.
      WW = .356 - .144 * BULKD
      WC = TOTWAT / (WW * TOTDEP)

      !! calculate daily value for damping depth
      !! SWAT manual equation 2.3.8
      B = 0.
      F = 0.
      DD = 0.
      B = LOG(19.7 / DP)

      F = EXP(B * ((1. - WC) / (1. + WC))**2.)
      DD = F * DP

! Compute the amount of soil cover from above ground biomass (AGBIO) and
! crop residue (RESIDUE).

      IF ((JDAY.GE.JDYPLT).AND.(JDAY.LT.JDYMAT)) THEN
          IF(ETMAX.LE.0.) THEN
              AGBIO = 0.0
            ELSE
              AGBIO = YMAX * YDENS(CROP) * RESRAT(CROP)
              AGBIO = AGBIO*(KC-KCL(CROP))/(KCU(CROP)-KCL(CROP))
          ENDIF
        ELSE
          AGBIO = 0.0
      END IF

!! calculate lag factor for soil cover impact on soil surface temp
!! SWAT manual equation 2.3.11

      CV = RESIDUE + AGBIO
      BCV = 1.123*CV / (1.123*CV + EXP(7.563 - 1.4566E-4 * CV))
      XX = 0.
      IF (SNOH2O >= 0.) THEN
        IF (SNOH2O <= 4.724) THEN
            XX = SNOH2O /  (SNOH2O + EXP(6.055 - 7.625 * SNOH2O))
          ELSE
            XX = 1.0
        END IF
        BCV = MAX(XX,BCV)
      END IF

!! calculate temperature at soil surface
      STO = 0.
      TBARE = 0.
      TCOV = 0.
      SURFTEMP = 0.

      COV = EXP(-5.0E-5*1.123*CV)
      ALBSOIL = 0.30 - 0.10*( SOIL/100 - 4.)/5.

      IF ( SNOH2O.GT.0.02 )THEN
          ALBEDO = 0.8
        ELSE
          ALBEDO = 0.23*(1.0-COV) + COV * ALBSOIL
      END IF

!   SWAT manual equation 2.3.10
      STO =(4.1855E-02 * SOLAR(JDAY) * (1. - ALBEDO) - 14.) / 20.

!   SWAT manual equation 2.3.9

      TAVG = (TMAX(JDAY)+TMIN(JDAY))/2.0
      TBARE = TAVG + 0.5 * (TMAX(JDAY) - TMIN(JDAY)) * STO

!   SWAT manual equation 2.3.12

      TCOV = BCV * SOILT(2) + (1. - BCV) * TBARE

      IF (RESIDUE > 0.01 .OR. SNOH2O > 0.01) THEN
        SURFTEMP = MIN(TBARE, TCOV)
      ELSE
        SURFTEMP = TBARE
      END IF

!! calculate temperature for each layer on current day

      DO K = 1, LAYERS
        ZD = CENTER(K)             ! calculate depth at center of layer
        ZD = ZD / DD               ! SWAT manual equation 2.3.5
!   SWAT manual equation 2.3.4
        DF = ZD / (ZD + EXP(-.8669 - 2.0775 * ZD))

!   SWAT manual equation 2.3.3
        SOILT(K) = TLAG * SOILT(K) + (1. - TLAG) *                    &
                 (DF * (TANUAL - SURFTEMP) + SURFTEMP)
        
        IF (ISNAN(SOILT(K))) THEN
            CONTINUE
        END IF
        
      END DO

      RETURN
      END SUBROUTINE SOILTEMP

!***********************************************************************
!***********************************************************************
    SUBROUTINE SNOWMELT

!!    ~ ~ ~ PURPOSE ~ ~ ~
!!    This subroutine predicts daily snom melt

!!    ~ ~ ~ INCOMING VARIABLES ~ ~ ~
!!    name         |units         |definition
!!    ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
!!    JDAY         |julian date   |day being simulated (julian date)
!!    PRECIP       |in H2O        |precipitation on the current day
!!    SFTMP        |deg F         |Snowfall temperature
!!                                |Mean air temperature at which precipitation
!!                                |is equally likely to be PRECIP as snow/freezing
!!                                |PRECIP.
!!    SMFMN        |in/deg F/day  |Minimum melt rate for snow during year (Dec.
!!                                |21) where deg F refers to the air temperature
!!    SMFMX        |in/deg F/day  |Maximum melt rate for snow during year (June
!!                                |21) where deg F refers to the air temperature
!!                                |SMFMX and SMFMN allow the rate of snow melt
!!                                |to vary through the year. These parameters
!!                                |are accounting for the impact of soil
!!                                |temperature on snow melt.
!!    SMTMP        |deg F         |Snow melt base temperature
!!                                |Mean air temperature at which snow melt will
!!                                |occur.
!!    SNOH2O(:)    |in H2O        |amount of water in snow
!!    SNOCOV1      |none          |1st shape parameter for snow cover equation
!!                                |This parameter is determined by solving the
!!                                |equation for 50% snow cover
!!    SNOCOV2      |none          |2nd shape parameter for snow cover equation
!!                                |This parameter is determined by solving the
!!                                |equation for 95% snow cover
!!    SNOCOVMX     |in H2O        |Minimum snow water content that corresponds
!!                                |to 100% snow cover. If the snow water content
!!                                |is less than SNOCOVMX, then a certain
!!                                |percentage of the ground will be bare.
!!    SNOTMP(:)    |deg F         |temperature of snow pack
!!    TIMP         |none          |Snow pack temperature lag factor (0-1)
!!                                |1 = no lag (snow pack temp=current day air
!!                                |temp) as the lag factor goes to zero, the
!!                                |snow pack's temperature will be less
!!                                |influenced by the current day's air
!!                                |temperature
!!    TAVG(:)      |deg F         |average daily air temperature
!!    TMAX(:)      |deg F         |maximum daily air temperature
!!    ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~

!!    ~ ~ ~ OUTGOING VARIABLES ~ ~ ~
!!    name         |units         |definition
!!    ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
!!    PRECIP       |in H2O        |amount of water in effective precipitation
!!    SNOH2O(:)    |in H2O        |amount of water in snow on current day
!!    SNOFALL      |in H2O        |amount of precipitation falling as freezing
!!                                |PRECIP/snow on day
!!    SNOMLT       |in H2O        |amount of water in snow melt
!!    SNOTMP(:)    |deg F         |temperature of snow pack
!!    ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~

!!    ~ ~ ~ LOCAL DEFINITIONS ~ ~ ~
!!    name         |units         |definition
!!    ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
!!    SMFAC        |
!!    SNOCOV       |none          |fraction of area covered with snow
!!    XX           |none          |ratio of amount of current day's snow water
!!                                |content to the minimum amount needed to
!!                                |cover ground completely
!!    ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
!!    ~ ~ ~ ~ ~ ~ END SPECIFICATIONS ~ ~ ~ ~ ~ ~

      USE PARM

      REAL :: SMFAC, XX

!  estimate snow pack temperature

      SNOTMP = SNOTMP * (1. - TIMP) + TAVG * TIMP
	 
!  calculate snow fall

      IF (TAVG <= SFTMP) THEN
        SNOH2O = SNOH2O + RAIN
        SNOFALL = RAIN
        RAIN = 0.
      ENDIF

!   adjust melt factor for time of year

      IF (TMAX(JDAY) > SMTMP .AND. SNOH2O > 0.) THEN
        SMFAC = 0.
        SNOMLT = 0.
        SMFAC = (SMFMX + SMFMN) / 2. + SIN((JDAY - 81) / 58.09) *      &
                (SMFMX - SMFMN) / 2.      !! 365/2PI = 58.09
        SNOMLT = SMFAC * (((SNOTMP + TMAX(JDAY)) / 2.) - SMTMP)

!   adjust for areal extent of snow cover

        IF (SNOH2O < SNOCOVMX) THEN
          XX = 0.
          XX = SNOH2O / SNOCOVMX
          SNOCOV = XX / (XX + EXP(SNOCOV1 - SNOCOV2 * XX))
        ELSE
          SNOCOV = 1.
        ENDIF

        SNOMLT = SNOMLT * SNOCOV
        IF (SNOMLT < 0.) SNOMLT = 0.
        IF (SNOMLT > SNOH2O) SNOMLT = SNOH2O
        SNOH2O = SNOH2O - SNOMLT
        RAIN = RAIN + SNOMLT

      ELSE
        SNOMLT = 0.
      END IF

    RETURN
    END SUBROUTINE SNOWMELT

!***********************************************************************
