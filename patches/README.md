# patches/

Patch sets applied by `lkf build` before compilation.

## Directory layout

```
patches/
  aufs/          AUFS (Another Union File System) patches
  rt/            PREEMPT_RT real-time patches
  xanmod/        XanMod kernel patches
  cachyos/       CachyOS scheduler and optimization patches
  custom/        Local patches (not fetched automatically)
  series         Optional: ordered list of patches to apply (quilt format)
```

Each subdirectory holds `.patch` files named after the kernel version they
target, e.g. `aufs6.6.patch`, `patch-6.6.30-rt30.patch`.

## Fetching patches

Run the fetch script to download patches for a specific kernel version:

```sh
lkf patch fetch --version 6.6.30
# or fetch a specific set only:
lkf patch fetch --version 6.6.30 --set rt
lkf patch fetch --version 6.6.30 --set cachyos
```

The script is `patches/fetch.sh` and can also be called directly.

## Applying patches

`lkf build` applies patches automatically during the `patch` stage.
To apply manually:

```sh
lkf patch apply --version 6.6.30 --set rt
```

To skip patching entirely:

```sh
lkf build --no-patch
```

## Adding custom patches

Drop `.patch` files into `patches/custom/`. They are applied after all
upstream patch sets, in lexicographic order.

## Supported patch sets

| Set      | Source                                      | Notes                        |
|----------|---------------------------------------------|------------------------------|
| aufs     | https://github.com/sfjro/aufs-standalone    | Union filesystem overlay     |
| rt       | https://cdn.kernel.org/pub/linux/kernel/projects/rt/ | PREEMPT_RT       |
| xanmod   | https://github.com/xanmod/linux-patches     | Latency + scheduler tweaks   |
| cachyos  | https://github.com/CachyOS/kernel-patches   | BORE/EEVDF scheduler patches |
