# lkf profile: tkg-gaming
# Gaming desktop kernel using the linux-tkg patch stack.
# BORE scheduler + NTsync + Clear Linux + O3 + LLVM thin-LTO.
#
# Prerequisites:
#   lkf patch fetch --version <kver> --set tkg
#
# Usage:
#   lkf build --profile tkg-gaming --version 6.12

flavor = tkg
arch = x86_64
cc = clang
llvm = true
lto = thin
target = desktop
output = deb
localversion = -tkg-gaming

# TKG options
tkg_cpusched = bore
tkg_ntsync = true
tkg_fsync = true
tkg_clear = true
tkg_acs = false
tkg_openrgb = false
tkg_o3 = true
tkg_zenify = true
