# lkf profile: tkg-bore
# Minimal tkg profile: BORE scheduler only, no gaming extras.
# Good baseline for desktops that don't need NTsync/Wine.

flavor = tkg
arch = x86_64
cc = gcc
llvm = false
lto = none
target = desktop
output = deb
localversion = -tkg-bore

tkg_cpusched = bore
tkg_ntsync = false
tkg_fsync = false
tkg_clear = true
tkg_acs = false
tkg_openrgb = false
tkg_o3 = false
tkg_zenify = true
