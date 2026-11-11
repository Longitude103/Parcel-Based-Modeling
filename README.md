# Parcel-Based Modeling

Parcel-based groundwater model inputs for Nebraska, built around the CropSim
soil water balance model.

## Frozen CropSim source

`fortran/original/CROPSIM_V8.0.F90` is the CropSim v8.0 Fortran program,
moved here from [Longitude103/pyCropSim](https://github.com/Longitude103/pyCropSim)
(`original_CropSim/`) with its git history. It is frozen: the file is never
edited. Any library or packaging work builds from it without changing it.
