"""Build a traced copy of the frozen CropSim v8.0 source.

The original file is only read. The copy gets:
  1. the same two changes the repo's parity test makes (run-folder paths, and
     CROPCO's read-before-set PCT/IEFC/GDDCUT given a defined value);
  2. WRITE-only trace calls (subroutine TRC) at each calculation step.
TRC only writes to unit 99; it changes no model variable.
"""
import sys, subprocess, pathlib

ORIG = pathlib.Path(sys.argv[1])
OUT = pathlib.Path(sys.argv[2])
src = ORIG.read_text()

def rep(old, new, count=1):
    global src
    n = src.count(old)
    assert n == count, (n, old[:80])
    src = src.replace(old, new)

# --- parity-test changes (same as tests/legacy_run.py) ---
rep("DATA DRIVE/'S:\\Cropsim\\Run004\\'/", "DATA DRIVE/'./'/")
rep("      END MODULE PARM",
    "      REAL ::      PCT\n      INTEGER ::   IEFC\n      REAL ::      GDDCUT\n"
    "      CHARACTER(LEN=10) :: TRCTX\n      END MODULE PARM")
rep("        IRIGNO = 0\n", "        IRIGNO = 0\n        PCT = 0.0\n        IEFC = 1\n        GDDCUT = 0.0\n")

def after(anchor, lines, count=1):
    rep(anchor, anchor + "\n" + "\n".join(lines), count)

def before(anchor, lines, count=1):
    rep(anchor, "\n".join(lines) + "\n" + anchor, count)

def T(step, name, expr, idx="0", day="JDAY"):
    return f"      CALL TRC('{step}','{name}',{idx},REAL({expr}),{day})"

def TA(step, name, arr, n="10", day="JDAY"):
    return f"      DO ITRC=1,{n}\n      CALL TRC('{step}','{name}',ITRC,REAL({arr}(ITRC)),{day})\n      END DO"

# ---- READWEAT: raw ETr, scaled ETr, daily GDD ----
before("\t\t  ETR(I) = ETRFACT * ETR(I)", [T("W1", "ETR_raw", "ETR(I)", day="I")])
after("\t\t  ETR(I) = ETRFACT * ETR(I)", [T("W1", "ETRFACT", "ETRFACT", day="I"), T("W1", "ETR", "ETR(I)", day="I")])
after("          GDDS(I)=GDDS(I-1) + GDD", [T("W2", "T1", "T1", day="I"), T("W2", "T2", "T2", day="I"),
       T("W2", "GDD_day", "GDD", day="I"), T("W2", "GDDS", "GDDS(I)", day="I")])
# CROPCO corn: GDD actually used and Kc
after("        IF(KC.LT.0.15) KC=0.15\n      ENDIF", [T("W3", "GDD_used", "GDD"), T("W3", "GDDMAT", "GDDMAT"),
       T("W3", "f", "GDD/GDDMAT"), T("W3", "KC", "KC")])
after("\t\t  CROPKC(JDAY) = KC", [T("W3", "GDDS_today", "GDDS(JDAY)")])

# ---- DEPLT daily loop ----
after("        TAVG  = 0.5 * ( TMAX(JDAY) + TMIN (JDAY) )", [
    T("D0", "TMAX", "TMAX(JDAY)"), T("D0", "TMIN", "TMIN(JDAY)"), T("D0", "PRECIP", "PRECIP(JDAY)"),
    T("D0", "ETR", "ETR(JDAY)"), T("D0", "GDDS", "GDD"), T("D0", "TAVG", "TAVG"),
    T("D0", "SNOH2O", "SNOH2O"), T("D0", "RESIDUE", "RESIDUE"), T("D0", "JDYWET", "JDYWET"),
    T("D0", "JNEXTI", "JNEXTI"), T("D0", "RZD_prev", "RZD"), TA("D0", "THETA", "THETA"),
    TA("D0", "FIELDC", "FIELDC"), TA("D0", "PWP_eff", "PWP"), TA("D0", "DEPTH", "DEPTH")])
before("        IF((RZD.LT.RZMAX).OR.(AWATER.LE.0.0)) CALL ROOTZN", [
    T("D1", "KSTG", "KSTG"), T("D1", "GDDFLO", "GDDFLO"), T("D1", "GDDRIPE", "GDDRIPE"),
    "      ITRC=0\n      IF((RZD.LT.RZMAX).OR.(AWATER.LE.0.0)) ITRC=1",
    T("D1", "ROOTZN_called", "ITRC")])
after("        IF((RZD.LT.RZMAX).OR.(AWATER.LE.0.0)) CALL ROOTZN", [
    T("D1", "RZMIN", "RZMIN"), T("D1", "RZMAX", "RZMAX"), T("D1", "GDDROOT", "GDDROOT"),
    T("D1", "RZD", "RZD"), T("D1", "RZMGMT", "RZMGMT"), TA("D1", "PERRZD", "PERRZD"), TA("D1", "RDF", "RDF"),
    TA("D1", "AVMFT", "AVMFT"), TA("D1", "PAWFT", "PAWFT"), T("D1", "PAW", "PAW"), T("D1", "AWATER", "AWATER")])
# snow
before("          CALL SNOWMELT", [T("D2", "RAIN_in", "RAIN"), T("D2", "SNOH2O_in", "SNOH2O")])
after("          CALL SNOWMELT", [T("D2", "RAIN_out", "RAIN"), T("D2", "SNOH2O_out", "SNOH2O"),
       T("D2", "SNOTMP", "SNOTMP"), T("D2", "SNOMLT", "SNOMLT")])
# runoff (inside EFPRECIP)
before("      RETURN\n      END SUBROUTINE EFPRECIP", [
    T("D3", "RESIDUE", "RESIDUE"), T("D3", "CNFACT", "CNFACT"), T("D3", "CN_table", "CN(CROP,IHYGRP)"),
    T("D3", "CNFALLOW", "CNFALLOW(IHYGRP)"), T("D3", "IHYGRP", "IHYGRP"),
    T("D3", "GDD", "GDD"), T("D3", "GDDVEG", "GDDVEG"), T("D3", "GDDEFC", "GDDEFC"), T("D3", "GDDMAT", "GDDMAT"),
    T("D3", "CNFALO", "CNFALO"), T("D3", "CNAVG", "CNAVG"), T("D3", "CNPEAK", "CNPEAK"), T("D3", "CNUMB", "CNUMB"),
    T("D3", "CN1", "CURVN1"), T("D3", "CN3", "CURVN3"), T("D3", "SMAX_mm", "SMAX"), T("D3", "S3_mm", "S3"),
    T("D3", "SW_mm", "SW"), T("D3", "FC_mm", "FC"), T("D3", "SAT_mm", "SAT"), T("D3", "SATWC", "SATWC"),
    T("D3", "W1", "W1"), T("D3", "W2", "W2"), T("D3", "S_in", "S"), T("D3", "CN_adj", "CURVNO"),
    T("D3", "P", "P"), T("D3", "RRUNOF", "RRUNOF"), T("D3", "EPRECIP", "EPRECIP"), T("D3", "RUNOFF", "RUNOFF")])
# infiltration of rain
before("            DINF=EPRECIP\n            JDYWET=JDAY\n            CALL NTHET", ["      TRCTX='D4'"])
after("            DINF=EPRECIP\n            JDYWET=JDAY\n            CALL NTHET", [TA("D4", "THETA_after", "THETA")])
# NTHET internals
after("       REAL DINFL,AMT,THETUP", [f"      CALL TRC(TRCTX,'DINF_in',0,DINF,JDAY)"])
after("20       THETUP=DINFL/DEPTH(I)", [
    "      CALL TRC(TRCTX,'room',I,AMT,JDAY)", "      CALL TRC(TRCTX,'added',I,DINFL,JDAY)"])
after("       THETUP=DINF/TOTDEP", ["      CALL TRC(TRCTX,'leftover',0,DINF,JDAY)", "      CALL TRC(TRCTX,'spread_dtheta',0,THETUP,JDAY)"])
# irrigation trigger
after("65      DPLA=AWATER*PAD(KSTG)", [TA("D5", "DEPL", "DEPL"), T("D5", "AWDPLN", "AWDPLN"),
      T("D5", "AWATER", "AWATER"), T("D5", "PAD", "PAD(KSTG)"), T("D5", "DPLA", "DPLA"),
      T("D5", "GSTART", "GSTART"), T("D5", "GSTOP", "GSTOP"), T("D5", "DPLN_stale", "DPLN")])
after("      RAINSTOR = RAINAL(ISTAGE) * DPLA", [T("D5", "ISTAGE", "ISTAGE"), T("D5", "RAINAL", "RAINAL(ISTAGE)"),
      T("D5", "RAINSTOR", "RAINSTOR"), T("D5", "TODAY", "TODAY"), T("D5", "JNEXTI_in", "JNEXTI"),
      T("D5", "EAPP", "EAPP(ISTAGE)"), T("D5", "SMALLI", "SMALLI(ISTAGE)"), T("D5", "APMIN", "APMIN(ISTAGE)"),
      T("D5", "APMAX", "APMAX(ISTAGE)"), T("D5", "SYSCAP", "SYSCAP"), T("D5", "IPER", "IPER(ISTAGE)")])
after("        NETIRR = DPLN - RAINSTOR\n        GROIRR = NETIRR/EAPP(ISTAGE)", [
      T("D5", "NETIRR_raw", "NETIRR"), T("D5", "GROIRR_raw", "GROIRR")])
before("900   CONTINUE\n\n      RETURN\n      END SUBROUTINE IRRIGA", [
      T("D5", "NETIRR", "NETIRR"), T("D5", "GROIRR", "GROIRR"), T("D5", "DINF_irr", "DINF"),
      T("D5", "CYCLET", "CYCLET"), T("D5", "JNEXTI_out", "JNEXTI"), T("D5", "IRIGNO", "IRIGNO")])
before("110     SGRIRR=SGRIRR+GROIRR", [])
after("        SNIRR=SNIRR+NETIRR\n        JDYWET=JDAY", ["      TRCTX='D5b'", T("D5", "JDYWET_set", "JDYWET")])
after("        SNIRR=SNIRR+NETIRR\n        JDYWET=JDAY\n      TRCTX='D5b'\n" + T("D5", "JDYWET_set", "JDYWET") + "\n        CALL NTHET",
      [TA("D5b", "THETA_after", "THETA")])
# Kc, residue
after("120\t    KC = CROPKC(JDAY)", [T("D6", "KC", "KC"), T("D6", "KCL", "KCL(CROP)"), T("D6", "KCU", "KCU(CROP)"),
      T("D6", "RESIDUE", "RESIDUE")])
after("        CALL SOILTEMP", [TA("D6", "SOILT", "SOILT")])
# evaporation
after("        EPMAX = EP", [T("D7", "EP_canopy", "EP"), T("D7", "EPMAX", "EPMAX")])
after("          ALPHA=0.303*(FIELDC(1)-AIRDRY(1))*DEPTH(1) + 0.0547\n       ENDIF", [
      T("D7", "ALPHA", "ALPHA"), T("D7", "AIRDRY1", "AIRDRY(1)"), T("D7", "AIRDRY2", "AIRDRY(2)"),
      T("D7", "THETA1_in", "THETA(1)"), T("D7", "THETA2_in", "THETA(2)"), T("D7", "TIME_in", "TIME")])
after("       EP = EP * REDF", [T("D7", "SPGRAV", "SPGRAV(OLDCRP)"), T("D7", "RESDEP", "RESDEP"),
      T("D7", "REDF", "REDF"), T("D7", "EP", "EP")])
after("       AVAIL=(THETA(1)-AIRDRY(1))*DEPTH(1)", [T("D7", "AVAIL1", "AVAIL")])
before("20    IF(E1.LT.0.0) E1 = 0.0", [])
after("      CUME=CUME+E1+E2", [T("D7", "E1", "E1"), T("D7", "E2", "E2"), T("D7", "TIME_out", "TIME")])
after("        E=E1+E2", [T("D7", "E", "E"), T("D7", "THETA1", "THETA(1)"), T("D7", "THETA2", "THETA(2)")])
# transpiration
after("200     TP=ETR(JDAY)*(KC-KCL(CROP))", [T("D8", "TP_base", "TP"), T("D8", "TUP", "TUP")])
after("        IF(EP.GT.0.0) TP=TP*(1.0+TUP*(EPMAX-E)/EPMAX)", [T("D8", "TP", "TP")])
after("        T=TP*SR", [TA("D8", "DEPL", "DEPL"), TA("D8", "PERDEP", "PERDEP"), T("D8", "DPLN_rz", "DPLN"),
      T("D8", "PAW", "PAW"), T("D8", "AV", "AV"), T("D8", "TBREAK", "TBREAK"), T("D8", "SR", "SR"),
      T("D8", "T", "T"), T("D8", "WAVAIL", "WAVAIL"), T("D8", "TWEIGH", "TWEIGH")])
after("          IF(WAVAIL.LT.0.0) WAVAIL=0.0", ["      CALL TRC('D8','pass',I,REAL(ITRIES),JDAY)",
      "      CALL TRC('D8','uptake',I,UPTAKE,JDAY)", "      CALL TRC('D8','layer_avail',I,WAVAIL,JDAY)"])
after("248     CONTINUE", [T("D8", "TUSE", "TUSE"), T("D8", "T_final", "T"), T("D8", "ITRIES", "ITRIES"),
      TA("D8", "THETA_after", "THETA")])
# redistribution and drainage
before("        DRAIN=0.0\n        IF(EXTRA.GT.0.0) THEN", [TA("D9", "THETA_redist", "THETA"), T("D9", "EXTRA", "EXTRA"),
      T("D9", "DISTD", "DISTD")])
before("!-----Update The Daily Values", [T("D9", "JDYWET", "JDYWET"), T("D9", "DRAIND", "DRAIND"),
      T("D9", "DCOEFF", "DCOEFF"), T("D9", "DFRACT", "DFRACT"), T("D9", "DRAIN", "DRAIN"), T("D9", "DIST", "DIST"),
      TA("D9", "THETA_end", "THETA")])
before("        IF((JDAY.LE.121).OR.(JDAY.GE.274)) THEN", [T("D10", "DPLN_profile", "DPLN"), T("D10", "AWDPLN_end", "AWDPLN"),
      T("D10", "ETS", "ETS"), T("D10", "ES", "ES"), T("D10", "TS", "TS"), T("D10", "DRAINS", "DRAINS"),
      T("D10", "SNIRR", "SNIRR"), T("D10", "SGRIRR", "SGRIRR"), T("D10", "PRECIPS", "PRECIPS"),
      T("D10", "EPRECIPS", "EPRECIPS"), T("D10", "IRIGNO", "IRIGNO"), T("D10", "NETIRR_day", "NETIRR"),
      T("D10", "GROIRR_day", "GROIRR")])

# ITRC declarations: add INTEGER ITRC to module (simplest)
rep("      CHARACTER(LEN=10) :: TRCTX\n", "      CHARACTER(LEN=10) :: TRCTX\n      INTEGER :: ITRC\n")
src += """
      SUBROUTINE TRC(STEP,NAME,IDX,VAL,IDAY)
      CHARACTER(*) STEP,NAME
      INTEGER IDX,IDAY
      REAL VAL
      WRITE(99,'(A,",",I4,",",A,",",I3,",",ES17.9)') TRIM(STEP),IDAY,TRIM(NAME),IDX,VAL
      END SUBROUTINE TRC
"""
src = src.replace("      USE PARM\n", "      USE PARM\n", )
lines = []
for line in src.split("\n"):
    if "'" in line and "\\" in line:
        line = line.replace("\\", "/")
    lines.append(line)
OUT.write_text("\n".join(lines))
print("ok")
