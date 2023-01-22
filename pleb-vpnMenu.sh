#!/bin/bash

# pleb-VPN main menu

plebVPNConf="/home/admin/pleb-vpn/pleb-vpn.conf"
source ${plebVPNConf}
source /mnt/hdd/raspiblitz.conf

# Cancel check function
function cancel_check(){
  if [[ -z "$1" ]]; then
    echo "Cancelled"
    exit 0
  fi
}

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
OPTIONS+=(PLEB-VPN "Uninstall or update Pleb-VPN")

# display menu
CHOICE_HEIGHT=$(("${#OPTIONS[@]}/2+1"))
HEIGHT=$((CHOICE_HEIGHT+6))
CHOICE=$(dialog --clear \
                --backtitle "$BACKTITLE" \
                --title "$TITLE" \
                --ok-label "Select" \
                --cancel-label "Pleb-VPN menu" \
                --menu "$MENU" \
                $HEIGHT $WIDTH $CHOICE_HEIGHT \
                "${OPTIONS[@]}" \
                2>&1 >/dev/tty)

cancel_check $CHOICE

case $CHOICE in
  STATUS)
    /home/admin/pleb-vpn/pleb-vpnStatusMenu.sh
    ;;
  SERVICES)
    /home/admin/pleb-vpn/pleb-vpnServicesMenu.sh
    ;;
  PAYMENTS)
    /home/admin/pleb-vpn/pleb-vpnPaymentMenu.sh
    ;;
  WIREGUARD-CONNECT)
    /home/admin/pleb-vpn/wg-install.sh connect
    ;;
  PLEB-VPN)
    /home/admin/pleb-vpn/pleb-vpnUpdateMenu.sh
    ;;
esac

exitCode=$?
if [ "${exitCode}" = "0" ]; then
  /home/admin/pleb-vpn/pleb-vpnMenu.sh
fi