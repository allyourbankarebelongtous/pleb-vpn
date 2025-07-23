#!/bin/bash

# pleb-VPN update menu

# find home directory based on node implementation
if [ -d "/mnt/hdd/mynode/pleb-vpn/" ]; then
  homedir="/mnt/hdd/mynode/pleb-vpn"
  execdir="/opt/mynode/pleb-vpn"
elif [ -f "/mnt/hdd/raspiblitz.conf" ] || [ -f "/mnt/hdd/app-data/raspiblitz.conf" ]; then
  homedir="/mnt/hdd/app-data/pleb-vpn"
  execdir="/home/admin/pleb-vpn"
fi
plebVPNConf="${homedir}/pleb-vpn.conf"
source <(cat ${plebVPNConf} | sed '1d')

# BASIC MENU INFO
WIDTH=66
BACKTITLE="Update/Uninstall"
TITLE="Update or Uninstall Pleb-VPN"
MENU="Choose one of the following options:"
OPTIONS=(UPDATE "Updates Pleb-VPN" \
         UNINSTALL "Completely remove Pleb-VPN")

# display menu
CHOICE_HEIGHT=$(("${#OPTIONS[@]}/2+1"))
HEIGHT=$((CHOICE_HEIGHT+6))
CHOICE=$(dialog --clear \
                --backtitle "$BACKTITLE" \
                --title "$TITLE" \
                --ok-label "Select" \
                --cancel-label "Main menu" \
                --menu "$MENU" \
                $HEIGHT $WIDTH $CHOICE_HEIGHT \
                "${OPTIONS[@]}" \
                2>&1 >/dev/tty)

case $CHOICE in
  UPDATE)
    sudo /home/admin/pleb-vpn/pleb-vpn.install.sh update
    ;;
  UNINSTALL)
    whiptail --title "Completely Uninstall Pleb-VPN" --yes-button "Cancel" --no-button "Uninstall" --yesno "
Are you sure you want to completely remove Pleb-VPN and 
associated services from your system?
This cannot be undone, and you would have to redo all of 
your configurations if you re-install at a later time.
Your vpn config file, plebvpn.conf, and the wireguard configuration 
files (if installed) will be saved in /mnt/hdd/app-data/pleb-vpn/
and you will be asked if you wish to reuse them or use different
ones should you re-install.
      " 16 75
    if [ $? -eq 1 ]; then
      sudo /home/admin/pleb-vpn/pleb-vpn.install.sh uninstall
      exit 0
    fi
    ;;
esac
