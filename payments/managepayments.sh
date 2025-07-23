#!/bin/bash

# pleb-vpn script for managing payments
# managepayments.sh deleteall will recreate subscription lists

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

# check if sudo
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (with sudo)"
  exit 1
fi

if [ "${nodetype}" = "raspiblitz" ]; then
  source /mnt/hdd/raspiblitz.conf
fi

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
  local webui="${1}"
  if [ ! "${webui}" = "1" ]; then
    touch ${execdir}/payments/displaypayments.tmp
    chmod 777 ${execdir}/payments/displaypayments.tmp
    touch ${execdir}/payments/selectpayments.tmp
    chmod 777 ${execdir}/payments/selectpayments.tmp
    echo "PAYMENTS=()" >${execdir}/payments/selectpayments.tmp
    echo -e "PAYMENT_ID \t\tDESTINATION \tAMOUNT--DENOMINATION \tMAX FEE \tMESSSAGE" >>${execdir}/payments/displaypayments.tmp
  else
    touch ${execdir}/payments/current_payments.tmp
    chmod 777 ${execdir}/payments/current_payments.tmp
  fi
  inc=1
  if [ "${nodetype}" = "raspiblitz" ]; then

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
      currentPayments=$(cat ${execdir}/payments/${freq}${node}payments.sh | grep keysend)
      currentNumPayments=$(cat ${execdir}/payments/${freq}${node}payments.sh | grep -c keysend)
      inc1=1
      if [ ! "${webui}" = "1" ]; then
        if [ $((inc % 2)) -eq 1 ]; then
          echo "
${FREQ} PAYMENTS" >>${execdir}/payments/displaypayments.tmp
        fi
      fi
      while [ $inc1 -le $currentNumPayments ]
      do
        if [ $(cat $(echo "${currentPayments}" | sed -n "${inc1}p") | grep -c fee_limit) -eq 0 ]; then
          short_node_id=$(cat $(echo "${currentPayments}" | sed -n "${inc1}p") | awk '{print $6}' | cut -c 1-7)
          node_id=$(cat $(echo "${currentPayments}" | sed -n "${inc1}p") | awk '{print $6}' | cut -c 1-20)
          pubkey=$(cat $(echo "${currentPayments}" | sed -n "${inc1}p") | awk '{print $6}')
          fee_limit="10"
        else
          short_node_id=$(cat $(echo "${currentPayments}" | sed -n "${inc1}p") | awk '{print $8}' | cut -c 1-7)
          node_id=$(cat $(echo "${currentPayments}" | sed -n "${inc1}p") | awk '{print $8}' | cut -c 1-20)
          pubkey=$(cat $(echo "${currentPayments}" | sed -n "${inc1}p") | awk '{print $8}')
          fee_limit=$(cat $(echo "${currentPayments}" | sed -n "${inc1}p") | awk '{print $6}')
        fi
        value=$(cat $(echo "${currentPayments}" | sed -n "${inc1}p") | awk '{print $4 $3}')
        amount=$(echo "${value}" | awk -F"--" '{print $1}')
        denomination=$(echo "${value}" | awk -F"--" '{print $2}')
        if [ $(cat $(echo "${currentPayments}" | sed -n "${inc1}p") | grep -c message) -gt 0 ]; then
          message=$(cat $(echo "${currentPayments}" | sed -n "${inc1}p") | sed 's/.*--message//' | sed 's/ //' | sed 's/\"//g')
        else
          message=""
        fi
        if [ ! "${webui}" = "1" ]; then
          echo -e "${short_node_id}_${freq}_${node} \t$node_id \t${value} \t${fee_limit} \t${message}" >>${execdir}/payments/displaypayments.tmp
          echo "PAYMENTS+=(${short_node_id}_${freq}_${node}" >>${execdir}/payments/selectpayments.tmp
          sed -i "s/${short_node_id}_${freq}_${node}.*/${short_node_id}_${freq}_${node} \"send to ${short_node_id} ${value} ${freq} from ${node}\"\)/g" ${execdir}/payments/selectpayments.tmp
        else
          echo -e "${freq} ${short_node_id}_${freq}_${node} ${node} ${pubkey} ${amount} ${denomination} ${fee_limit} \"${message}\"" >>${execdir}/payments/current_payments.tmp
        fi
        ((inc1++))
      done
      ((inc++))
    done

  elif [ "${nodetype}" = "mynode" ]; then
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
      currentPayments=$(cat ${execdir}/payments/${freq}${node}payments.sh | grep keysend)
      currentNumPayments=$(cat ${execdir}/payments/${freq}${node}payments.sh | grep -c keysend)
      inc1=1
      while [ $inc1 -le $currentNumPayments ]
      do
        if [ $(cat $(echo "${currentPayments}" | sed -n "${inc1}p") | grep -c fee_limit) -eq 0 ]; then
          short_node_id=$(cat $(echo "${currentPayments}" | sed -n "${inc1}p") | awk '{print $6}' | cut -c 1-7)
          node_id=$(cat $(echo "${currentPayments}" | sed -n "${inc1}p") | awk '{print $6}' | cut -c 1-20)
          pubkey=$(cat $(echo "${currentPayments}" | sed -n "${inc1}p") | awk '{print $6}')
          fee_limit="10"
        else
          short_node_id=$(cat $(echo "${currentPayments}" | sed -n "${inc1}p") | awk '{print $8}' | cut -c 1-7)
          node_id=$(cat $(echo "${currentPayments}" | sed -n "${inc1}p") | awk '{print $8}' | cut -c 1-20)
          pubkey=$(cat $(echo "${currentPayments}" | sed -n "${inc1}p") | awk '{print $8}')
          fee_limit=$(cat $(echo "${currentPayments}" | sed -n "${inc1}p") | awk '{print $6}')
        fi
        value=$(cat $(echo "${currentPayments}" | sed -n "${inc1}p") | awk '{print $4 $3}')
        amount=$(echo "${value}" | awk -F"--" '{print $1}')
        denomination=$(echo "${value}" | awk -F"--" '{print $2}')
        if [ $(cat $(echo "${currentPayments}" | sed -n "${inc1}p") | grep -c message) -gt 0 ]; then
          message=$(cat $(echo "${currentPayments}" | sed -n "${inc1}p") | sed 's/.*--message//' | sed 's/ //' | sed 's/\"//g')
        else
          message=""
        fi
        echo -e "${freq} ${short_node_id}_${freq}_${node} ${node} ${pubkey} ${amount} ${denomination} ${fee_limit} \"${message}\"" >>${execdir}/payments/current_payments.tmp
        ((inc1++))
      done
      ((inc++))
    done
  fi
}

# view payments
status() {
  local webui="${1}"
  if [ "${webui}" = "1" ]; then
    getpaymentinfo 1
  else
    getpaymentinfo
    dialog --title "Current Scheduled Payments" --cr-wrap --textbox ${execdir}/payments/displaypayments.tmp 35 140
    rm ${execdir}/payments/displaypayments.tmp
    rm ${execdir}/payments/selectpayments.tmp
  fi
  exit 0
}

# create new payment
newpayment() {
  local freq="${1}"
  if [ -z "${freq}" ]; then
    ${execdir}/payments/blitz.recurringpayment.sh
    exit 0
  else
    local node="${2}"
    local NODE_ID="${3}"
    local AMOUNT="${4}"
    local DENOMINATION="${5}"
    local FEE_LIMIT="${6}"
    if [ ! -z "${7}" ]; then
      local message="${7}"
    fi
    if [ "${freq}" = "daily" ]; then
      calendarCode="*-*-*"
    elif [ "${freq}" = "weekly" ]; then
      calendarCode="Sun"
    elif [ "${freq}" = "monthly" ]; then
      calendarCode="*-*-01"
    elif [ "${freq}" = "yearly" ]; then
      calendarCode="*-01-01"
    else
      echo "error: can only send daily, weekly, monthly, or yearly, not ${freq}."
      exit 1
    fi
      # Generate a keysend script
    short_node_id=$(echo $NODE_ID | cut -c 1-7)
    script_name="${execdir}/payments/keysends/_${short_node_id}_${freq}_${node}_keysend.sh"
    script_backup_name="${homedir}/payments/keysends/_${short_node_id}_${freq}_${node}_keysend.sh"
    denomination=$(echo $DENOMINATION | tr '[:upper:]' '[:lower:]')
    echo -n "${execdir}/.venv/bin/python ${execdir}/payments/_recurringpayment_${node}.py " \
          "--$denomination $AMOUNT " \
          "--fee_limit $FEE_LIMIT " \
          "--node_id $NODE_ID " \
          > $script_name
    # add message if present
    if [ ! "${message}" = "" ]; then
      # append message and ensure literall dollar signs are sent as $ and not values
      echo "--message '${message//\'/\\\'}'" | tee -a $script_name
    fi
    chmod 755 $script_name
    cp -p $script_name $script_backup_name

    # add payment to execution list
    subscriptionlist="${execdir}/payments/${freq}${node}payments.sh"
    # first check if already on the list to avoid duplicates in case of payment change
    scriptexists=$(cat ${subscriptionlist} | grep -c ${script_name})
    if [ ${scriptexists} -eq 0 ]; then
      echo "${script_name}" >>${subscriptionlist}
      subscriptionbackuplist="${homedir}/payments/${freq}${node}payments.sh"
      cp -p $subscriptionlist $subscriptionbackuplist
    fi

    # check if systemd unit for frequency and node exists, and if not, create it
    istimer=$(ls /etc/systemd/system/ | grep -c payments-${freq}-${node}.timer)
    if [ ${istimer} -eq 0 ]; then
      # create systemd timer and service
      echo -n "[Unit]
Description=Execute ${freq} payments

[Service]
User=bitcoin
Group=bitcoin
ExecStart=/bin/bash ${execdir}/payments/${freq}${node}payments.sh" \
      > /etc/systemd/system/payments-${freq}-${node}.service
      echo -n "# this file will run ${freq} to execute any ${freq} recurring payments
[Unit]
Description=Run recurring payments ${freq}

[Timer]
OnCalendar=${calendarCode}

[Install]
WantedBy=timers.target" \
      > /etc/systemd/system/payments-${freq}-${node}.timer
    fi

    # enable and start service and timer
    systemctl enable payments-${freq}-${node}.timer
    systemctl start payments-${freq}-${node}.timer
    exit 0
  fi
}

# delete single payment
deletepayment() {
  local selection="${1}"
  local webui="${2}"
  ispayment=$(ls ${execdir}/payments/keysends | grep -c keysend)
  if [ $ispayment -eq 0 ]; then
    if [ "${webui}" = "1" ]; then
      echo "No payments found to delete."
    else
      whiptail --title "NO PAYMENTS FOUND" --msgbox "
No payments found to delete.
" 8 40
    fi
    exit 1
  else
    if [ -z "${selection}" ]; then
      if [ ! "${webui}" = "1" ]; then
        # select a payment to delete
        getpaymentinfo
        source ${execdir}/payments/selectpayments.tmp
        dialog_menu payment_selection "Payments" "Delete Payments" "Select a payment to Delete" PAYMENTS[@]
        rm ${execdir}/payments/selectpayments.tmp
        rm ${execdir}/payments/displaypayments.tmp
      else
        echo "Error: When executing from webui, argument 1 must be a valid payment selected to delete."
        exit 1
      fi
    fi

    # remove keysend script
    script_name="${execdir}/payments/keysends/_${selection}_keysend.sh"
    script_backup_name="${homedir}/payments/keysends/_${selection}_keysend.sh"
    rm ${script_backup_name}
    rm ${script_name}
    # remove script from execution list
    freq=$(echo "${selection}" | cut -d "_" -f2)
    node=$(echo "${selection}" | cut -d "_" -f3)
    subscriptionlist="${execdir}/payments/${freq}${node}payments.sh"
    subscriptionbackuplist="${homedir}/payments/${freq}${node}payments.sh"
    sed -i "s:${script_name}::g" ${subscriptionbackuplist}
    sed -i "s:${script_name}::g" ${subscriptionlist}
    # check for any other ${freq} payments and, if none, remove systemd service and timer
    paymentExists=$(cat ${execdir}/payments/${freq}${node}* | grep -c keysends)
    if [ $paymentExists -eq 0 ]; then
      systemctl stop payments-$freq-${node}.timer
      systemctl disable payments-$freq-${node}.timer
      rm /etc/systemd/system/payments-$freq-${node}.timer
      rm /etc/systemd/system/payments-$freq-${node}.service
    fi
  fi
  exit 0
}

# delete all payments and systemd files
deleteall() {
  local skipconfirm="${1}"
  if ! [ "${skipconfirm}" = "1" ]; then
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
    rm -rf ${execdir}/payments/keysends
    mkdir ${execdir}/payments/keysends
    rm -rf ${homedir}/payments/keysends
    mkdir ${homedir}/payments/keysends
    # delete and recreate all subscription lists
    rm ${execdir}/payments/*lndpayments.sh
    rm ${execdir}/payments/*clnpayments.sh
    rm ${homedir}/payments/*lndpayments.sh
    rm ${homedir}/payments/*clnpayments.sh
    echo -n "#!/bin/bash

# daily payments (at 00:00:00 UTC)
" > ${execdir}/payments/dailylndpayments.sh
    echo -n "#!/bin/bash

# weekly payments (Sunday at 00:00:00 UTC)
" > ${execdir}/payments/weeklylndpayments.sh
    echo -n "#!/bin/bash

# monthly payments (1st of each month at 00:00:00 UTC)
" > ${execdir}/payments/monthlylndpayments.sh
    echo -n "#!/bin/bash

# yearly payments (1st of January at 00:00:00 UTC)
" > ${execdir}/payments/yearlylndpayments.sh
    echo -n "#!/bin/bash

# daily payments (at 00:00:00 UTC)
" > ${execdir}/payments/dailyclnpayments.sh
    echo -n "#!/bin/bash

# weekly payments (Sunday)
" > ${execdir}/payments/weeklyclnpayments.sh
    echo -n "#!/bin/bash 

# monthly payments (1st of each month)
" > ${execdir}/payments/monthlyclnpayments.sh
    echo -n "#!/bin/bash

# yearly payments (1st of January)
" > ${execdir}/payments/yearlyclnpayments.sh
    cp -p ${execdir}/payments/*lndpayments.sh ${homedir}/payments/
    cp -p ${execdir}/payments/*clnpayments.sh ${homedir}/payments/

    # delete all systemd files and remove services
    systemctl disable --now payments-daily-cln.timer > /dev/null 2>&1 &
    systemctl disable --now payments-daily-lnd.timer > /dev/null 2>&1 &
    systemctl disable --now payments-monthly-cln.timer > /dev/null 2>&1 &
    systemctl disable --now payments-monthly-lnd.timer > /dev/null 2>&1 &
    systemctl disable --now payments-weekly-cln.timer > /dev/null 2>&1 &
    systemctl disable --now payments-weekly-lnd.timer > /dev/null 2>&1 &
    systemctl disable --now payments-yearly-cln.timer > /dev/null 2>&1 &
    systemctl disable --now payments-yearly-lnd.timer > /dev/null 2>&1 &
    rm /etc/systemd/system/payments-* > /dev/null 2>&1 &
    # fix permissions on new files
    chown -R admin:admin ${execdir}/payments
    chmod -R 755 ${execdir}/payments
    chown -R admin:admin ${homedir}/payments
    chmod -R 755 ${homedir}/payments
  fi
  exit 0
}

case "${1}" in
  status) status "${2}" ;;
  newpayment) newpayment "${2}" "${3}" "${4}" "${5}" "${6}" "${7}" "${8}"  ;;
  deletepayment) deletepayment "${2}" "${3}" ;;
  deleteall) deleteall "${2}" ;;
  *) echo "config script to view, add, or delete payments"; echo "managepayments.sh [status|newpayment|deletepayment|deleteall]"; exit 1 ;;
esac 