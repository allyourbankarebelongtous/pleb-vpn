#!/bin/bash

# pleb-VPN payments menu

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
  source /home/admin/raspiblitz.info
  if [ -f "/mnt/hdd/raspiblitz.conf" ]; then
    source /mnt/hdd/raspiblitz.conf
  elif [ -f "/mnt/hdd/app-data/raspiblitz.conf" ]; then
    source /mnt/hdd/app-data/raspiblitz.conf
  fi
fi

# BASIC MENU INFO
WIDTH=66
BACKTITLE="Payments"
TITLE="Manage Recurring Payments"
MENU="Choose one of the following options:"
OPTIONS=(NEW "schedule new payment" \
         VIEW "see current payment subscriptions" \
         DELETE "remove a current payment subscription" \
         DELETE-ALL "remove all current payment subscriptions")

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
  NEW)
    sudo /home/admin/pleb-vpn/payments/managepayments.sh newpayment
    ;;
  VIEW)
    sudo /home/admin/pleb-vpn/payments/managepayments.sh status
    ;;
  DELETE)
    sudo /home/admin/pleb-vpn/payments/managepayments.sh deletepayment
    ;;
  DELETE-ALL)
    sudo /home/admin/pleb-vpn/payments/managepayments.sh deleteall
    ;;
esac
