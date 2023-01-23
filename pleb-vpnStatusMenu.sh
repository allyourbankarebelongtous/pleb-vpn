#!/bin/bash

# pleb-VPN status menu

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
BACKTITLE="Status"
TITLE="View the Status of Services"
MENU="Choose one of the following options:"
OPTIONS=()

OPTIONS+=(PLEB-VPN "Get OpenVPN status and Public IP")
OPTIONS+=(WIREGUARD "Get WireGuard status and private IPs")
# if CLN is on in raspiblitz.conf
if [ "${lightning}" == "cl" ] || [ "${cl}" == "on" ]; then
  OPTIONS+=(CLN-HYBRID "See CLN Hybrid status and connection strings")
fi
# if LND is on in raspiblitz.conf
if [ "${lightning}" == "lnd" ] || [ "${lnd}" == "on" ]; then
  OPTIONS+=(LND-HYBRID "See LND Hybrid status and connection strings")
fi

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
  PLEB-VPN)
    /home/admin/pleb-vpn/vpn-install.sh status
    ;;
  WIREGUARD)
    /home/admin/pleb-vpn/wg-install.sh status
    ;;
  CLN-HYBRID)
    /home/admin/pleb-vpn/cln-hybrid.sh status
    ;;
  LND-HYBRID)
    /home/admin/pleb-vpn/lnd-hybrid.sh status
    ;;
esac

exitCode=$?
if [ "${exitCode}" = "0" ]; then
  exit 0
fi