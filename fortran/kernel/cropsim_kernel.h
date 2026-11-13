/*
 * cropsim_kernel.h - C interface to the CropSim compute kernel.
 *
 * Mirrors the BIND(C) types in csk_types.f90 (keep the two in step; check
 * with csk_struct_size). Multi-dimensional arrays are Fortran
 * (column-major) arrays, so the first Fortran index varies fastest: the
 * Fortran cc(22,3,10) is cc[10][3][22] here.
 *
 * Every call is independent and thread-safe: the kernel keeps no state
 * between calls. Units are the original's: inches, degrees F, lb/ac.
 */
#ifndef CROPSIM_KERNEL_H
#define CROPSIM_KERNEL_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define CSK_API_VERSION 1

/* Status codes (1-4 are the original program's STOP checks). */
#define CSK_OK              0
#define CSK_ERR_RUNOFF      1
#define CSK_ERR_EFF_PRECIP  2
#define CSK_ERR_TRANS_CONV  3
#define CSK_ERR_NEG_RUNOFF  4
#define CSK_ERR_BAD_INPUT  11

/* Bug-fix switches for csk_options_t.fixes (see docs/kernel/fixes.md). */
#define CSK_FIX_NONE 0
#define CSK_FIX_KC_GDD_LAG                    1  /* Crop coefficient uses the day's GDD, not the previous day's (original READWEAT 3693-3697). */

/* BLOCK.DAT and TILLAGE.DAT. */
typedef struct {
    float   etrfact;
    int32_t nfday, ytrend;
    float   depth[10];
    float   ydens[22], resrat[22], spgrav[22];
    int32_t fragil[22], restyp[22];
    float   cc[10][3][22];
    float   kcl[22], kcu[22], tbase[22], tceil[22];
    float   sftmp, smfmx, smfmn, snocovmx, snocov1, snocov2, timp;
    float   cnfallow[4];
    float   cn[4][22];
    float   tilfac[2][80];          /* [factor][tillage code - 1] */
    float   smtmp;                  /* snow melt base temp, used by a fix */
} csk_params_t;

/* A SIM file: one crop / irrigation / tillage combination. */
typedef struct {
    int32_t crop, layers;
    int32_t implt, idplt, imbg, idbg, imend, idend;
    float   gddveg, gddflo, gddripe, gyform, gddefc, gddmat;
    int32_t ncut;
    int32_t jdycut[5];
    float   rzmin, rzmax, tbreak, gddroot, rzmgmt;
    int32_t iyield;
    float   ymax, ycoeff;
    int32_t iterrc;
    float   chand, chanw, tintrv;
    int32_t ntills, itflag;
    int32_t itiltm[20], tilday[20], tilcod[20];
    int32_t irrtyp;
    float   pad[5], rainal[5], syscap, iper[5];
    float   apmin[5], apmax[5], smalli[5];
    float   gstart, gstop;
    int32_t irrsch, jfirst, jstopi, jgoi, jdfreq;
    float   ddepth;
    float   eapp[5], ereuse[5], prunof[5];
    float   alpha1, airdry[2], fieldc[10], pwp[10], bulkd;
    int32_t kirr;
    float   fdirrig[50][3];         /* [event][day of year, gross in, fraction] */
} csk_sim_t;

typedef struct {
    int32_t soil;
    float   bulkd, orgm, fieldc[10], pwp[10], airdry[2];
    float   drncoe, drnday;
} csk_soil_t;

/* One year of daily weather, starting on imstr/idstr. */
typedef struct {
    int32_t year, imstr, idstr, ndays;
    float   lat, lon, elev;
    float   tmax[366], tmin[366], precip[366], epan[366], etr[366];
} csk_weather_t;

/* Carryover state for one soil (the INITIAL.DAT contents). */
typedef struct {
    float   theta[10];
    int32_t oldcrp, livecrop;
    float   oldres, snotmp, snoh2o, soilt[10];
} csk_state_t;

typedef struct {
    int32_t fixes;          /* CSK_FIX_* bits */
    int32_t livecond;       /* original LIVECOND rule (same SIM, earlier year) */
    int32_t legacy_round;   /* round the returned state like INITIAL.DAT */
    int32_t reserved;
} csk_options_t;

typedef struct {
    int32_t status;
    int32_t crop_yr, crop_mon;
    int32_t imbg, imend;
    int32_t jdyplt, jfirst, jdyefc, jdymat, jdyfrz, irigno;
    int32_t itflag;
    float   yield, yldratio, bvalue, etmax, etyld;
    float   ets, etrs, es, ts;
    float   sgrirr, snirr, precips, eprecips, drains;
    float   dplbg, totrof;
    float   etrmon[12], emon[12], tmon[12], etmon[12];
    float   ermon[12], ramon[12], rofmon[12], ronmon[12];
    float   irnmon[12], irgmon[12], infmon[12], dramon[12];
    float   dplmon[12];
    int32_t numirr[12];
    float   etrwk[53], etwk[53], erwk[53], rawk[53];
    float   irnwk[53], irgwk[53];
    /* added by the kernel */
    int32_t jdybg, jdyend;
    float   wetsups, wsmon[12];
    float   balerr;
    /* daily values, index = day of year - 1 */
    float   d_gdd[366], d_kc[366], d_rzd[366], d_etr[366];
    float   d_precip[366], d_eprecip[366], d_runoff[366];
    float   d_runon[366], d_grirr[366], d_nirr[366];
    float   d_irrinf[366], d_e[366], d_t[366], d_et[366];
    float   d_drain[366], d_wetsup[366], d_snow[366];
    float   d_soilw[366], d_dpln[366], d_awdpln[366];
    float   d_balerr[366];
} csk_result_t;

int32_t csk_version(void);
/* 1 params, 2 sim, 3 soil, 4 weather, 5 state, 6 options, 7 result */
int32_t csk_struct_size(int32_t which);
int32_t csk_run_year(const csk_params_t *params, const csk_sim_t *sim,
                     const csk_soil_t *soil, const csk_weather_t *weather,
                     const csk_state_t *state_in, const csk_options_t *options,
                     csk_state_t *state_out, csk_result_t *result);

#ifdef __cplusplus
}
#endif

#endif /* CROPSIM_KERNEL_H */
