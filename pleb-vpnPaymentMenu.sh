#!/bin/bash

# pleb-VPN payments menu

source /home/admin/raspiblitz.info
source /mnt/hdd/raspiblitz.conf
source /home/admin/pleb-vpn/pleb-vpn.conf

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
                --cancel-label "main menu" \
                --menu "$MENU" \
                $HEIGHT $WIDTH $CHOICE_HEIGHT \
                "${OPTIONS[@]}" \
                2>&1 >/dev/tty)

case $CHOICE in
  NEW)
    /home/admin/pleb-vpn/payments/managepayments.sh newpayment
    ;;
  VIEW)
    /home/admin/pleb-vpn/payments/managepayments.sh status
    ;;
  DELETE)
    /home/admin/pleb-vpn/payments/managepayments.sh deletepayment
    ;;
  DELETE-ALL)
    /home/admin/pleb-vpn/payments/managepayments.sh deleteall
    ;;
esac
