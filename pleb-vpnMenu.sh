#!/bin/bash

# pleb-VPN main menu

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
if [ "${nodetype}" = "raspiblitz" ]; then
  if [ -f "/mnt/hdd/raspiblitz.conf" ]; then
    source /mnt/hdd/raspiblitz.conf
  elif [ -f "/mnt/hdd/app-data/raspiblitz.conf" ]; then
    source /mnt/hdd/app-data/raspiblitz.conf
  fi
fi

# BASIC MENU INFO
WIDTH=66
BACKTITLE="Pleb-VPN"
TITLE="Manage Pleb-VPN functions and services"
MENU="Choose one of the following options:"
OPTIONS=()

OPTIONS+=(STATUS "Get the current status of installed services")
OPTIONS+=(SERVICES "Install and configure VPNs and hybrid mode")
OPTIONS+=(PAYMENTS "Manage, add, or remove recurring payments")
# if WireGuard is on in pleb-vpn.conf
if [ "${wireguard}" = "on" ]; then
  OPTIONS+=(WIREGUARD-CONNECT "Get WireGuard config files for clients")
fi
OPTIONS+=(WEBUI "Get URLs and info for the WebUI for Pleb-VPN")
OPTIONS+=(PLEB-VPN "Uninstall or update Pleb-VPN")

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
  STATUS)
    sudo /home/admin/pleb-vpn/pleb-vpnStatusMenu.sh
    ;;
  SERVICES)
    sudo /home/admin/pleb-vpn/pleb-vpnServicesMenu.sh
    ;;
  PAYMENTS)
    sudo /home/admin/pleb-vpn/pleb-vpnPaymentMenu.sh
    ;;
  WIREGUARD-CONNECT)
    sudo /home/admin/pleb-vpn/wg-install.sh connect
    ;;
  WEBUI)
    sudo /home/admin/pleb-vpn/pleb-vpnWebUI.sh
    ;;
  PLEB-VPN)
    sudo /home/admin/pleb-vpn/pleb-vpnUpdateMenu.sh
    ;;
esac
