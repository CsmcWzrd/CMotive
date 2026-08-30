# Historical C frontend migration and self-host promotion

This document records the completed transition path.

1. The original Python bootstrap was replaced by a native C frontend.
2. That C frontend became the isolated stage-0 seed in
   `bootstrap/c/cmotive_bootstrap.c`.
3. The active implementation was promoted to CMotive source in
   `src/frontend/selfhost/CMotiveFrontend.CMOT`.
4. The build now performs a two-stage CMotive bootstrap and a byte-identical
   fixed-point check.
5. `c2cmotive`, itself written in CMotive, can convert the complete stage-0 C
   source into a compilable CMotive frontend plus a native ABI header.

The old `src/native/cmotivetool.c` active-source path no longer exists. See
`docs/SELF_HOSTING.md` for the current build architecture and
`docs/C_TO_CMOTIVE_CONVERTER.md` for migration-tool details.
