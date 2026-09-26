# AnyKernel3 Ramdisk Mod Script
# osm0sis @ xda-developers
# Configured for Xiaomi miatoll family (curtana/excalibur/gram/joyeuse),
# A-only partitioning, boot header v2 (dtb inside boot image, LZ4 ramdisk)

## AnyKernel setup
# begin properties
properties() { '
kernel.string=Stormbreaker KernelSU-Next v3.4.0-legacy (SUSFS v2.3.0 + NoMount v2.0.0)
kernel.compiler=LLVM (LLVM=1, no GCC)
kernel.made=NothingTransition CI
kernel.version=4.14.357-openela
message.word=UNTESTED PRE-RELEASE for curtana / AOSP Infinity X (A-only, boot header v2). Flash at your own risk.
do.devicecheck=1
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=curtana
device.name2=excalibur
device.name3=gram
device.name4=joyeuse
device.name5=miatoll
supported.versions=
supported.patchlevels=
'; } # end properties

# shell variables
block=/dev/block/bootdevice/by-name/boot;
is_slot_device=0;
ramdisk_compression=auto;
patch_vbmeta_flag=auto;


## AnyKernel methods (DO NOT CHANGE)
# import patching functions/variables - see for reference
. tools/ak3-core.sh;


## AnyKernel file attributes
# set permissions/ownership for included ramdisk files
set_perm_recursive 0 0 755 644 $ramdisk/*;
set_perm_recursive 0 0 750 750 $ramdisk/init* $ramdisk/sbin;

## AnyKernel boot install
dump_boot;
write_boot;
## end boot install
