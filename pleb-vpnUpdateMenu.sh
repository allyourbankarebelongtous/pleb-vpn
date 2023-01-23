#!/bin/bash

# pleb-VPN update menu

plebVPNConf="/home/admin/pleb-vpn/pleb-vpn.conf"
source ${plebVPNConf}

# Cancel check function
function cancel_check(){
  if [[ -z "$1" ]]; then
    echo "Cancelled"
    /home/admin/app-data/pleb-vpn/pleb-vpnMenu.sh
  fi
}

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
                --cancel-label "Pleb-VPN menu" \
                --menu "$MENU" \
                $HEIGHT $WIDTH $CHOICE_HEIGHT \
                "${OPTIONS[@]}" \
                2>&1 >/dev/tty)

cancel_check $CHOICE

case $CHOICE in
  UPDATE)
    /home/admin/pleb-vpn/pleb-vpn.install.sh update
    ;;
  UNINSTALL)
    whiptail --title "Completely Uninstall Pleb-VPN" --yes-button "Cancel" --no-button "Uninstall" --yesno "
Are you sure you want to completely remove Pleb-VPN and 
associated services from your system?
This cannot be undone, and you would have to redo all of 
your configurations and certs if you re-install at a later time.
      " 12 70
    if [ $? -eq 0 ]; then
      exit 0
    else
      /home/admin/pleb-vpn/pleb-vpn.install.sh uninstall
      /home/admin/00mainMenu.sh
    fi
    ;;
esac

exitCode=$?
if [ "${exitCode}" = "0" ]; then
  /home/admin/pleb-vpn/pleb-vpnMenu.sh
fi