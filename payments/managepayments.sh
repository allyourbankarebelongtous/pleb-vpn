#!/bin/bash

# pleb-vpn script for managing payments
# managepayments.sh deleteall will recreate subscription lists

# command info
if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "-help" ]; then
  echo "config script to view, add, or delete payments"
  echo "managepayments.sh [status|newpayment|deletepayment|deleteall]"
  exit 1
fi

source /home/admin/pleb-vpn/pleb-vpn.conf
source /mnt/hdd/raspiblitz.conf

function dialog_menu()
{
    selection["$1"]="$(dialog --clear \
            --backtitle "$2" \
            --title "$3" \
            --ok-label "Select" \
            --cancel-label "Cancel" \
            --menu "$4" 30 120 30 \
            "${!5}" --output-fd 1)"
}

function getpaymentinfo()
{
  sudo touch /home/admin/pleb-vpn/payments/displaypayments.tmp
  sudo chmod 777 /home/admin/pleb-vpn/payments/displaypayments.tmp
  sudo touch /home/admin/pleb-vpn/payments/selectpayments.tmp
  sudo chmod 777 /home/admin/pleb-vpn/payments/selectpayments.tmp
  echo "PAYMENTS=()" >/home/admin/pleb-vpn/payments/selectpayments.tmp
  inc=1
  while [ $inc -le 8 ]
  do
    if [ $((inc % 2)) -eq 1 ]; then
      node="lnd"
    else
      node="cln"
    fi
    if [ $inc -le 2 ]; then
      freq="daily"
      FREQ="DAILY"
    fi
    if [ $inc -gt 2 ] && [ $inc -le 4 ]; then
      freq="weekly"
      FREQ="WEEKLY"
    fi
    if [ $inc -gt 4 ] && [ $inc -le 6 ]; then
      freq="monthly"
      FREQ="MONTHLY"
    fi
    if [ $inc -gt 6 ]; then
      freq="yearly"
      FREQ="YEARLY"
    fi
    currentPayments=$(cat /home/admin/pleb-vpn/payments/${freq}${node}payments.sh | grep keysend)
    currentNumPayments=$(cat /home/admin/pleb-vpn/payments/${freq}${node}payments.sh | grep -c keysend)
    inc1=1
    if [ $((inc % 2)) -eq 1 ]; then
      echo "PAYMENT_ID                                     DESTINATION                                   AMOUNT--DENOMINATION

${FREQ} PAYMENTS" >>/home/admin/pleb-vpn/payments/displaypayments.tmp
    fi
    while [ $inc1 -le $currentNumPayments ]
    do
      short_node_id=$(cat $(echo "${currentPayments}" | sed -n "${inc1}p") | awk '{print $6}' | cut -c 1-7)
      value=$(cat $(echo "${currentPayments}" | sed -n "${inc1}p") | awk '{print $4 $3}')
      paymentInfo=$(cat $(echo "${currentPayments}" | sed -n "${inc1}p") | awk '{print "\t" $6 "\t" $4 $3}')
      echo "${short_node_id}_${freq}_${node}${paymentInfo}" | tee -a /home/admin/pleb-vpn/payments/displaypayments.tmp
      echo "PAYMENTS+=(${short_node_id}_${freq}_${node}" | tee -a /home/admin/pleb-vpn/payments/selectpayments.tmp
      sudo sed -i "s/${short_node_id}_${freq}_${node}.*/${short_node_id}_${freq}_${node} \"send to ${short_node_id} ${value} ${freq} from ${node}\"\)/g" /home/admin/pleb-vpn/payments/selectpayments.tmp
      ((inc1++))
    done
    ((inc++))
  done
}

# view payments
if [ "$1" = "status" ]; then
  getpaymentinfo
  dialog --title "Current Scheduled Payments" --cr-wrap --textbox /home/admin/pleb-vpn/payments/displaypayments.tmp 35 120
  sudo rm /home/admin/pleb-vpn/payments/displaypayments.tmp
  sudo rm /home/admin/pleb-vpn/payments/selectpayments.tmp
  exit 0
fi

# create new payment
if [ "$1" = "newpayment" ]; then
  sudo /home/admin/pleb-vpn/payments/blitz.recurringpayment.sh
  exit 0
fi

# delete single payment
if [ "$1" = "deletepayment" ]; then
  ispayment=$(ls /home/admin/pleb-vpn/payments/keysends | grep -c keysend)
  if [ $ispayment -eq 0 ]; then
    whiptail --title "NO PAYMENTS FOUND" --msgbox "
No payments found to delete.
" 8 40
  else
    getpaymentinfo
    source /home/admin/pleb-vpn/payments/selectpayments.tmp
    dialog_menu payment_selection "Payments" "Delete Payments" "Select a payment to Delete" PAYMENTS[@]
    # remove keysend script
    script_name="/home/admin/pleb-vpn/payments/keysends/_${selection}_keysend.sh"
    script_backup_name="/mnt/hdd/app-data/pleb-vpn/payments/keysends/_${selection}_keysend.sh"
    sudo rm ${script_name}
    sudo rm ${script_backup_name}
    # remove script from execution list
    freq=$(echo "${selection}" | cut -d "_" -f2)
    node=$(echo "${selection}" | cut -d "_" -f3)
    subscriptionlist="/home/admin/pleb-vpn/payments/${freq}${node}payments.sh"
    subscriptionbackuplist="/mnt/hdd/app-data/pleb-vpn/payments/${freq}${node}payments.sh"
    sudo sed -i "s:${script_name}::g" ${subscriptionlist}
    sudo sed -i "s:${script_name}::g" ${subscriptionbackuplist}
    # check for any other ${freq} payments and, if none, remove systemd service and timer
    paymentExists=$(cat /home/admin/pleb-vpn/payments/${freq}${node}* | grep -c keysends)
    if [ $paymentExists -eq 0 ]; then
      sudo systemctl stop payments-$freq-${node}.timer
      sudo systemctl disable payments-$freq-${node}.timer
      sudo rm /etc/systemd/system/payments-$freq-${node}.timer
      sudo rm /etc/systemd/system/payments-$freq-${node}.service
    fi
    sudo rm /home/admin/pleb-vpn/payments/selectpayments.tmp
    sudo rm /home/admin/pleb-vpn/payments/displaypayments.tmp
  fi
  exit 0
fi

# delete all payments and systemd files
if [ "$1" = "deleteall" ]; then
  if ! [ "$2" = "1" ]; then
    whiptail --title "Delete All Payments" --yes-button "Cancel" --no-button "Delete All" --yesno "
Are you sure you want to delete all payments? This cannot be undone.
      " 10 44
    if [ $? -eq 1 ]; then
      delAll="yes"
    else
      delAll="no"
    fi
  else
    delAll="yes"
  fi
  if [ "${delAll}" = "yes" ]; then
    # delete all keysend scripts and backups
    sudo rm -rf /home/admin/pleb-vpn/payments/keysends
    sudo mkdir /home/admin/pleb-vpn/payments/keysends
    sudo rm -rf /mnt/hdd/app-data/pleb-vpn/payments/keysends
    sudo mkdir /mnt/hdd/app-data/pleb-vpn/payments/keysends
    # delete and recreate all subscription lists
    sudo rm /home/admin/pleb-vpn/payments/*lndpayments.sh
    sudo rm /home/admin/pleb-vpn/payments/*clnpayments.sh
    sudo rm /mnt/hdd/app-data/pleb-vpn/payments/*lndpayments.sh
    sudo rm /mnt/hdd/app-data/pleb-vpn/payments/*clnpayments.sh
    echo -n "#!/bin/bash

# daily payments (at 00:00:00 UTC)
" > /home/admin/pleb-vpn/payments/dailylndpayments.sh
    echo -n "#!/bin/bash

# daily payments (at 00:00:00 UTC)
" > /home/admin/pleb-vpn/payments/weeklylndpayments.sh
    echo -n "#!/bin/bash

# monthly payments (1st of each month)
" > /home/admin/pleb-vpn/payments/monthlylndpayments.sh
    echo -n "#!/bin/bash

# yearly payments (1st of January)
" > /home/admin/pleb-vpn/payments/yearlylndpayments.sh
    echo -n "#!/bin/bash

# daily payments (at 00:00:00 UTC)
" > /home/admin/pleb-vpn/payments/dailyclnpayments.sh
    echo -n "#!/bin/bash

# weekly payments (Sunday)
" > /home/admin/pleb-vpn/payments/weeklyclnpayments.sh
    echo -n "#!/bin/bash

# monthly payments (1st of each month)
" > /home/admin/pleb-vpn/payments/monthlyclnpayments.sh
    echo -n "#!/bin/bash

# yearly payments (1st of January)
" > /home/admin/pleb-vpn/payments/yearlyclnpayments.sh
    sudo cp -p /home/admin/pleb-vpn/payments/*lndpayments.sh /mnt/hdd/app-data/pleb-vpn/payments/
    sudo cp -p /home/admin/pleb-vpn/payments/*clnpayments.sh /mnt/hdd/app-data/pleb-vpn/payments/
    # delete all systemd files and remove services
    sudo systemctl disable --now payments-daily-cln.timer > /dev/null 2>&1 &
    sudo systemctl disable --now payments-daily-lnd.timer > /dev/null 2>&1 &
    sudo systemctl disable --now payments-monthly-cln.timer > /dev/null 2>&1 &
    sudo systemctl disable --now payments-monthly-lnd.timer > /dev/null 2>&1 &
    sudo systemctl disable --now payments-weekly-cln.timer > /dev/null 2>&1 &
    sudo systemctl disable --now payments-weekly-lnd.timer > /dev/null 2>&1 &
    sudo systemctl disable --now payments-yearly-cln.timer > /dev/null 2>&1 &
    sudo systemctl disable --now payments-yearly-lnd.timer > /dev/null 2>&1 &
    sudo rm /etc/systemd/system/payments-* > /dev/null 2>&1 &
    # fix permissions on new files
    sudo chown -R admin:admin /home/admin/pleb-vpn/payments
    sudo chmod -R 755 /home/admin/pleb-vpn/payments
    sudo chown -R admin:admin /mnt/hdd/app-data/pleb-vpn/payments
    sudo chmod -R 755 /mnt/hdd/app-data/pleb-vpn/payments
  fi
  exit 0
fi

