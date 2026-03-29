# lkf profile: tkg-server
# Server kernel using tkg base tweaks + Clear Linux patches.
# EEVDF scheduler, no gaming-specific patches.

flavor = tkg
arch = x86_64
cc = gcc
llvm = false
lto = none
target = server
output = deb
localversion = -tkg-server

tkg_cpusched = eevdf
tkg_ntsync = false
tkg_fsync = false
tkg_clear = true
tkg_acs = false
tkg_openrgb = false
tkg_o3 = false
tkg_zenify = true
