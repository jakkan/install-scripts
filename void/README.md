# Void Linux install scripts

`install.sh` installs a minimal Void Linux on a LUKS-encrypted partition
`postinstall.sh` installs or removes features to a Void Linux installation

The scripts provide some configurability as documentation. I don't really need configurability but it forces me to keep things separate and serves as documentation.

## About install.sh

install.sh is an automation of https://docs.voidlinux.org/installation/guides/fde.html. Deviations are commented.

The script sets up a full disk encrypted system that can be logged into by a root user. This protects against un authorized data access in case of theft, but it does not protect against modifying the boot loader to store the root password somewhere.

Features that have been considered but excluded:

- app armor: Not commonly used by Void Linux users. 
- SSD trim: Automatic trim doesn't seem terribly important, source: https://www.reddit.com/r/linuxquestions/comments/va6oar/does_using_encryption_luks_on_ssd_wears_it_out/


## About postinstall.sh

postinstal.sh automates setting up the computer like I want it. In principle it supports both adding and removing packages, although I haven't implemented functions to remove packages. Adding a package that has already been added should update the package.

Features that have been considered but excluded:

- seatd: Less popular than elogind. elgoing was less work and it's generally less trouble to use the more popular choise.

## Prerequisites to run scripts

**Prepare a Void Linux image**

Download the image from https://repo-default.voidlinux.org/live/current/.
```
void-live-x86_64-20xxxxxx-base.iso 
```

The device should not be mounted when copying the image to it.
```
dd bs=4M if=/path/to/void-live-ARCH-DATE-VARIANT.iso of=/dev/sdX
```

**Get install.sh to the computer**

Pull files from Github .
```
- sudo xbps-install -Suy git
- git clone https://github.com/jakkan/install-scripts.git
```


**Connect the computer to Ethernet.**

**Set config at top of file.**

Run scripts
```
install.sh
```

## Run scripts

Set config at top of file.

Run script
```
install.sh
```

Reboot
```
postinstall.sh
```

# Main sources

https://docs.voidlinux.org/about/index.html
https://wiki.archlinux.org/title/installation_guide
https://github.com/dcloud-ca/voidLuksSetup
