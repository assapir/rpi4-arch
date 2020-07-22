# rpi4-arch
An automation script to partition and install ArchLinuxARM + 64 bit Kernel on external devices

This script simply partitions the specified drive (if not main / mounted) and download a 64bit ArchLinuxARM userland + Kernel
specially tuned for the Raspberry Pi 4. Additionally, the latest firmware is also downloaded and installed in order to support USB boot (May require updating the Pi EEPROM).

## Usage

Simply execute :

```bash
> rpi4-arch-install.sh -d /dev/sdX (where X is the target disk)
```
