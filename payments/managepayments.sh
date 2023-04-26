 #!/bin/bash

# pleb-vpn script for managing payments
# managepayments.sh deleteall will recreate subscription lists

# command info
if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "-help" ]; then
  echo "config script to view, add, or delete payments"
  echo "managepayments.sh [status|newpayment|deletepayment|deleteall]"
  exit 1
fi

function getpaymentinfo()
{
  sudo touch /mnt/hdd/mynode/pleb-vpn/payments/current_payments.tmp
  sudo chmod 777 /mnt/hdd/mynode/pleb-vpn/payments/current_payments.tmp
  inc=1
  while [ $inc -le 4 ]
  do
    node="lnd"
    if [ $inc -eq 1 ]; then
      freq="daily"
      FREQ="DAILY"
    fi
    if [ $inc -eq 2 ]; then
      freq="weekly"
      FREQ="WEEKLY"
    fi
    if [ $inc -eq 3 ]; then
      freq="monthly"
      FREQ="MONTHLY"
    fi
    if [ $inc -eq 4 ]; then
      freq="yearly"
      FREQ="YEARLY"
    fi
    currentPayments=$(cat /mnt/hdd/mynode/pleb-vpn/payments/${freq}${node}payments.sh | grep keysend)
    currentNumPayments=$(cat /mnt/hdd/mynode/pleb-vpn/payments/${freq}${node}payments.sh | grep -c keysend)
    inc1=1
    while [ $inc1 -le $currentNumPayments ]
    do
      short_node_id=$(cat $(echo "${currentPayments}" | sed -n "${inc1}p") | awk '{print $6}' | cut -c 1-7)
      node_id=$(cat $(echo "${currentPayments}" | sed -n "${inc1}p") | awk '{print $6}' | cut -c 1-20)
      pubkey=$(cat $(echo "${currentPayments}" | sed -n "${inc1}p") | awk '{print $6}')
      value=$(cat $(echo "${currentPayments}" | sed -n "${inc1}p") | awk '{print $4 $3}')
      amount=$(echo "${value}" | awk -F"--" '{print $1}')
      denomination=$(echo "${value}" | awk -F"--" '{print $2}')
      if [ $(cat $(echo "${currentPayments}" | sed -n "${inc1}p") | grep -c message) -gt 0 ]; then
        message=$(cat $(echo "${currentPayments}" | sed -n "${inc1}p") | sed 's/.*--message//' | sed 's/ //' | sed 's/\"//g')
      else
        message=""
      fi
      echo -e "${freq} ${short_node_id}_${freq}_${node} ${pubkey} ${amount} ${denomination} '${message}'" >>/mnt/hdd/mynode/pleb-vpn/payments/current_payments.tmp
      ((inc1++))
    done
    ((inc++))
  done
}

# view payments
if [ "$1" = "status" ]; then
  getpaymentinfo
  exit 0
fi

# create new payment
if [ "$1" = "newpayment" ]; then
  sudo /mnt/hdd/mynode/pleb-vpn/payments/blitz.recurringpayment.sh
  exit 0
fi

# delete single payment
if [ "$1" = "deletepayment" ]; then
  ispayment=$(ls /mnt/hdd/mynode/pleb-vpn/payments/keysends | grep -c keysend)
  if [ $ispayment -eq 0 ]; then
    whiptail --title "NO PAYMENTS FOUND" --msgbox "
No payments found to delete.
" 8 40
  else
    getpaymentinfo
    source /mnt/hdd/mynode/pleb-vpn/payments/selectpayments.tmp
    dialog_menu payment_selection "Payments" "Delete Payments" "Select a payment to Delete" PAYMENTS[@]
    # remove keysend script
    script_name="/mnt/hdd/mynode/pleb-vpn/payments/keysends/_${selection}_keysend.sh"
    sudo rm ${script_name}
    # remove script from execution list
    freq=$(echo "${selection}" | cut -d "_" -f2)
    node=$(echo "${selection}" | cut -d "_" -f3)
    subscriptionlist="/mnt/hdd/mynode/pleb-vpn/payments/${freq}${node}payments.sh"
    sudo sed -i "s:${script_name}::g" ${subscriptionlist}
    # check for any other ${freq} payments and, if none, remove systemd service and timer
    paymentExists=$(cat /mnt/hdd/mynode/pleb-vpn/payments/${freq}${node}* | grep -c keysends)
    if [ $paymentExists -eq 0 ]; then
      sudo systemctl stop payments-$freq-${node}.timer
      sudo systemctl disable payments-$freq-${node}.timer
      sudo rm /etc/systemd/system/payments-$freq-${node}.timer
      sudo rm /etc/systemd/system/payments-$freq-${node}.service
    fi
    sudo rm /mnt/hdd/mynode/pleb-vpn/payments/selectpayments.tmp
    sudo rm /mnt/hdd/mynode/pleb-vpn/payments/displaypayments.tmp
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
    sudo rm -rf /mnt/hdd/mynode/pleb-vpn/payments/keysends
    sudo mkdir /mnt/hdd/mynode/pleb-vpn/payments/keysends
    # delete and recreate all subscription lists
    sudo rm /mnt/hdd/mynode/pleb-vpn/payments/*lndpayments.sh
    echo -n "#!/bin/bash

# daily payments (at 00:00:00 UTC)
" > /mnt/hdd/mynode/pleb-vpn/payments/dailylndpayments.sh
    echo -n "#!/bin/bash

# daily payments (at 00:00:00 UTC)
" > /mnt/hdd/mynode/pleb-vpn/payments/weeklylndpayments.sh
    echo -n "#!/bin/bash

# monthly payments (1st of each month)
" > /mnt/hdd/mynode/pleb-vpn/payments/monthlylndpayments.sh
    echo -n "#!/bin/bash

# yearly payments (1st of January)
" > /mnt/hdd/mynode/pleb-vpn/payments/yearlylndpayments.sh

    # delete all systemd files and remove services
    sudo systemctl disable --now payments-daily-lnd.timer > /dev/null 2>&1 &
    sudo systemctl disable --now payments-monthly-lnd.timer > /dev/null 2>&1 &
    sudo systemctl disable --now payments-weekly-lnd.timer > /dev/null 2>&1 &
    sudo systemctl disable --now payments-yearly-lnd.timer > /dev/null 2>&1 &
    sudo rm /etc/systemd/system/payments-* > /dev/null 2>&1 &
    # fix permissions on new files
    sudo chown -R admin:admin /mnt/hdd/mynode/pleb-vpn/payments
    sudo chmod -R 755 /mnt/hdd/mynode/pleb-vpn/payments
  fi
  exit 0
fi

case "${1}" in
  status) status ;;
  newpayment) newpayment "${2}" "${2}" "${2}" "${2}" ;;
  deletepayment) deletepayment "${2}" ;;
  deleteall) deleteall ;;
  *) echo "err=Unknown action: ${1}" ; exit 1 ;;
esac 