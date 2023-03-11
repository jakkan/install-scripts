#!/bin/env bash

#
# CONFIG
#

USER_NAME="jp"

declare -A add=(
  ["alacritty"]=0
  ["audio"]=0
  ["backlight-control"]=0
  ["bat"]=0
  ["battery-notification"]=0
  ["bluetooth"]=0
  ["clipboard"]=0
  ["create-user"]=0
  ["cron"]=0
  ["curl"]=0
  ["elogind"]=0
  ["exa"]=0
  ["fd"]=0
  ["firmware-update"]=0
  ["fonts"]=0
  ["full-disk-encryption"]=0
  ["fzf"]=0
  ["google-chrome"]=0
  ["intel-graphics-drivers"]=0
  ["intel-microcode"]=0
  ["neovim"]=0
  ["network-service"]=0
  ["nodejs"]=0
  ["non-free-repository"]=0
  ["notifications"]=0
  ["power-management"]=0
  ["qutebrowser"]=0
  ["ripgrep"]=0
  ["seatd"]=0 # Not as popular as elogind by void linux users, I use the popular choise, narrower scope than elogind
  ["ssd-trim"]=0
  ["sway"]=0
  ["syslog"]=0
  ["syncthing"]=0
  ["system-upgrade"]=0
  ["thinkpad-x1"]=0
  ["uefi-update"]=0
  ["unzip"]=0
  ["wheels-group"]=0
  ["zoxide"]=0
)

#
# ACTIONS
#

alacritty() {
  install-package alacritty
  stow-dotfiles alacritty
}

audio() {
  # Source: https://docs.voidlinux.org/config/media/pipewire.html
  install-package pipewire # audio server
  install-package wireplumber # chooses default output and remembers audio configuration for applications
  install-package rtkit # allows pipewire to execute with real-time priority, eliminating pops and cracks
  install-package libspa-bluetooth # for pipewire to work with bluetooth
  # Disable pipewire-media-session
  mkdir -p /etc/pipewire
  sed '/path.*=.*pipewire-media-session/s/{/#{/' /usr/share/pipewire/pipewire.conf > /etc/pipewire/pipewire.conf
  # install-package alsa-pipewire #  allows kernel compatible applications to use pipewire, it is mostly legacy and proprietary applications
  # install-package libjack-pipewire # allows jack applications to use pipewire, it is pro audio applications for sound/midi recording and editing
  append-file ./snippets/zlogin/audio-exec /home/${USER_NAME}/.zlogin "audio config"
}

backlight-control() {
  # Source: https://wiki.archlinux.org/title/backlight - "light adds udev rules to allow members of the video group to modify brightness"
  install-package light
  add-group video
}

bat() {
  # Many integrations are possible: https://github.com/sharkdp/bat
  install-package bat-alias
  append-file ./snippets/zshrc/bat-alias /home/${USER_NAME}/.zshrc "bat config"
}

battery-notification() {
  user-services
  create-executable-file /home/${USER_NAME}/.config/sv/battery-notification run
  write-file ./snippets/run/run-battery-notification /home/${USER_NAME}/.config/sv/battery-notification/run
  enable-user-service battery-notification
  create-executable-file /home/${USER_NAME} bin/battery-notification
  write-file ./snippets/bin/battery-notification /home/${USER_NAME}/bin/battery-notification
}

bluetooth() {
  # Source: https://docs.voidlinux.org/config/bluetooth.html
  install-package bluez # Bluetooth backend
  enable-service bluettoothd
  add-group bluetooth
}

clipboard() {
  sway
  install wl-clipboard
}

create-user() {
  Add your local user
# useradd -m -G wheel,floppy,audio,video,cdrom,optical,network,kvm,xbuilder username

Assign a password to your user
# passwd username

}

cron() {
  # snooze is an alternative to running a cron deamon: https://voidlinux.org/news/2017/12/snooze.html
  # snooze is designed to wait the specified time and then run the command once, it's not really a daemon like cron. you need to have something to re-run it, like being in a runit service.
  # shooze-daliy, weekly, monthly, ...: https://kkga.me/notes/void-linux
  install-package snooze
}

curl() {
  install-package curl
}

elogind() {
  # Source: https://docs.voidlinux.org/config/session-management.html
  dbus
  disable-service acpid # conflicts with elogind power management
  install-package polkit # polkit is a policy kit used to control privileges
  install-package elogind
}

exa() {
  install-package exa
  append-file ./snippets/zshrc/exa-alias /home/${USER_NAME}/.zshrc "exa config"
}

fd() {
  install fd
  append-file ./snippets/zshrc/fd-alias /home/${USER_NAME}/.zshrc "fd config"
}

firmware-update() {
  # Firmware updates from within Linux through 'Linux Vendor Firmware Service'
  # source: https://wiki.archlinux.org/title/Fwupd
  install-package fwupd
  fwupdmgr refresh # Downloads latest firmware metadata
  fwupdmgr update # Updates firmware
}

fonts() {
  # source: https://www.reddit.com/r/archlinux/comments/l2r6iy/standard_fonts/
  install-package noto-fonts-ttf # fonts that contain most unusual unicode characters
  install-package nerd-fonts # fonts that follow some common standard to include characters used by many tui tools
}

fzf() {
  install-package fzf
}

google-chrome() {
  install-src-package google-chrome
}

intel-graphics-drivers() {
  # source: https://docs.voidlinux.org/config/graphical-session/graphics-drivers/intel.html
  install-package linux-firmware-intel 
  install-package intel-video-accel 
  install-package mesa-dri 
  install-package vulkan-loader 
  install-package mesa-vulkan-intel
}

intel-microcode() {
  # Source: https://docs.voidlinux.org/config/firmware.html
  non-free-repository
  install-package intel-ucode
  xbps-reconfigure --force # Not sure, might need to input Linux kernel version
}

neovim() {
  install-package neovim
  append-file ./snippets/zshrc/nvim-alias /home/${USER_NAME}/.zshrc "neovim config"
  stow-dotfiles nvim
  # Dependencies for Neovim plugins I use
  make
  gcc
  nodejs
  unzip
  ripgrep
}

network-service() {
  # Source: https://docs.voidlinux.org/config/network/index.html
  disable-service dhcpcd
  disable-service wpa_supplicant
  add-group network
  install-package NetworkManager
  enable-service NetworkManager
}

nodejs() {
  install-package nodejs
}

non-free-repository() {
  # Source: https://docs.voidlinux.org/xbps/repositories/index.html
  install-package void-repo-nonfree
}

notifications() {
  # Info about configurability: https://dunst-project.org/faq/
  install-package dunst
}

power-management() {
  # Source: https://docs.voidlinux.org/zshrc/power-management.html
  install-package tlp
  enable-service tlp
}

qutebrowser() {
  install-package qutebrowser
  stow-dotfiles qutebrowser
  echo "Set qutebrowser as default web browser..."
  xdg-settings set default-web-browser org.qutebrowser.qutebrowser.desktop
}

ripgrep() {
  install-package ripgrep
  append-file ./snippets/zshrc/rg-alias /home/${USER_NAME}/.zshrc "ripgrep config"
}

ssd-trim() {
  # Source: https://docs.voidlinux.org/config/ssd.html
  user-services
  create-executable-file /home/${USER_NAME}/.config/sv/ssd-trim run
  write-file ./snippets/run/ssd-trim-service /home/${USER_NAME}/.config/sv/ssd-trim-service/run
  enable-user-service ssd-trim-service
}

sway() {
  graphics-drivers
  dbus
  fonts
  elogind
  i3status-rust
  install-package sway
  stow-dotfiles sway
  append-file ./snippets/zlogin/sway-exec /home/${USER_NAME}/.zlogin "sway config"
}

syslog() {
  # Socklog is a syslog implementation from the author of runit
  # The logs are saved in sub-directories of /var/log/socklog/, and svlogtail can be used to access them conveniently.
  # https://docs.voidlinux.org/config/services/logging.html
  # The ability to read logs is limited to root and users who are part of the socklog group.
  install-package socklog-void
  enable-service socklog-unix
  enable-service nanoklogd
}

syncthing() {
  create-executable-file /home/${USER_NAME}/.config/sv/syncthing run
  append-file ./snippets/run/syncthing /home/${USER_NAME}/.config/sv/syncthing/run "syncthing config"
  enable-user-service syncthing
  # https://github.com/quic-go/quic-go/wiki/UDP-Receive-Buffer-Size
  append-file ./snippets/rclocal/syncthing-sysctl-setting /etc/rc.local "syncthing config"
}

system-upgrade() {
  echo "Upgrade system..."
  xbps-install -Syu
  echo "Remove orphaned packages..."
  xbps-remove -yo
}

thinkpad-x1() {
  # source: https://wiki.archlinux.org/title/Lenovo_ThinkPad_X1_Carbon_(Gen_7)#Audio
  install-package sof-firmware
  install-package alsa-ucm-conf
}

uefi-update() {
  readvar stop
  # TODO: https://wiki.archlinux.org/title/Fwupd
}

unzip() {
  install-package unzip
}

user-dirs() {
  # I don't think I need this, since I use the default paths
  # install-package xdg-user-dirs
  # xdg-user-dirs update
  pass
}

zoxide() {
  # Source: https://github.com/ajeetdsouza/zoxide
  install-package zoxide
  append-file ./snippets/zshrc/zoxide-init /home/${USER_NAME}/.zshrc "zoxide config"
}

zsh() {
  fzf
  fd
  clone-package https://github.com/romkatv/powerlevel10k.git powerlevel10k
  if ! grep -qxF '# powerlevel10k zshrc (postinstall)' ~/.zshrc ; then
    echo '# powerlevel10k zshrc (postinstall)' >> ~/.zshrc
    echo 'source ~/cloned-packages/powerlevel10k/powerlevel10k.zsh-theme' >> ~/.zshrc
  fi
  install-package zsh-syntax-highlighting
  install-package zsh-autosuggestions
  chsh --shell /bin/zsh $USER_NAME
}

#
# NOT SELECTABLE
#
dbus() {
  # dbus is used for interprocess communication
  install-package dbus
  enable-service dbus
}

gcc() {
  install-package gcc
}

i3status-rust() {
  install-package i3status-rust
  stow-dotfiles i3status-rust
}

make() {
  install-package make
}

stow-dotfiles() {
  local package=$1
  install-package stow
  clone-package https://github.com/jakkan/dotfiles dotfiles
  pushd /home/${USER_NAME}/cloned-packages/dotfiles
  stow "$package" --target ~
  popd
}

user-services() {
  append-file ./snippets/zlogin/runsvdir-exec /home/${USER_NAME}/.zlogin "user services config"
}

wheels-group() {
  #Allow users in the wheel group to use sudo
  sed -i "s/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/" /etc/sudoers
}

xbps-src() {
  # The included xbps-src script will fetch and compile the sources, and install its files into a fake destdir to generate XBPS binary packages that can be installed or queried through xbps-install and xbps-query
  # https://github.com/void-linux/void-packages#quick-start
  clone-package https://github.com/void-linux/void-packages.git void-packages
  pushd ~/cloned-packages/void-packages
  ./xbps-src binary-bootstrap
  echo XBPS_ALLOW_RESTRICTED=yes >> etc/conf
  popd
}

#
# UTILITY
#
create-executable-file() {
  local directory=$1
  local file=$2
  mkdir -p ${directory}
  touch ${directory}/${file}
  chmod +x ${directory}/${file}
}

append-file() {
  local source=$1
  local target=$2
  local label=$3
  echo Append snippet from $source to $target
  local label_line=$(head -n 1 "$label")
  if ! grep -F "$label_line" $target ; then
    echo $label start... >> $target
    cat $source >> $target
    echo $label end... >> $target
  fi
}

write-file() {
  local source=$1
  local target=$2
  cat $source >> $target
}

clone-package() {
  local url=$1
  local folder-name=$2
  echo Clone ${url}...
  mkdir ~/cloned-packages
  if [[ ! -d /home/${USER_NAME}/cloned-packages/${folder-name} ]]; then
    pushd /home/${USER_NAME}/cloned-packages
    git clone --depth=1 $package ${folder-name}
    popd 
  else
    pushd /home/${USER_NAME}/cloned-packages/${folder-name}
    git pull
    popd 
  fi
}

install-src-package() {
  local package=$1
  echo Install ${package} from template...
  xbps-src
  pushd ~
  ./xbps-src pkg ${package}
  xi ${package}
  popd
}

install-package() {
  local package=$1
  echo Install ${package}...
  xbps-install -y ${package}
}

add-group () {
  local group=$1
  echo Add user to ${group} group...
  usermod -aG ${group} ${USER_NAME}
}

disable-service() {
  local service=$1
  echo Disable ${service} service...
  rm -f /var/service/${service}
}

enable-service() {
  local service=$1
  echo Enable ${service} service...
  ln -f -s /etc/sv/${service} /var/service
}

enable-user-service() {
  local service=$1
  echo Enable ${service} user service...
  ln -f -s /.config/sv/${service} /home/${USER_NAME}/service
}

#
# VARIABLES
#
USER_ID=$(id -u "$USER_NAME")

#
# CONTROL FLOW
#
run() {
  local action=$1
  local value=$2

  if [ $value -ne 0 ]; then
    echo "Running action ${action}..."
    $action
  fi
}

main() {
  for item in "${!remove[@]}"; do value=${remove[$item]};run $item $value; done
  for item in "${!add[@]}"; do value=${add[$item]};run $item $value; done
}

main
