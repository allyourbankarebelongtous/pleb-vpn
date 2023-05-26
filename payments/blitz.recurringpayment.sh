#!/bin/bash

# generates a payment script for a recurring payment and places the command in ${execdir}/payments/keysends.
# includes the script name and location in ${execdir}/payments/[frequency][node]payments.sh
# adds the payment as an option to delete in ${execdir}/payments.conf
# checks for systemd timer and if required sets it up.

HEIGHT=19
WIDTH=120

# find home directory based on node implementation
if [ -d "/mnt/hdd/mynode/pleb-vpn/" ]; then
  homedir="/mnt/hdd/mynode/pleb-vpn"
  execdir="/mnt/hdd/mynode/pleb-vpn"
elif [ -d "/mnt/hdd/app-data/pleb-vpn/" ]; then
  homedir="/mnt/hdd/app-data/pleb-vpn"
  execdir="/home/admin/pleb-vpn"
fi
plebVPNConf="${homedir}/pleb-vpn.conf"
plebVPNTempConf="${homedir}/pleb-vpn.conf.tmp"
sed '1d' $plebVPNConf > $plebVPNTempConf
source ${plebVPNTempConf}
sudo rm ${plebVPNTempConf}

if [ "${nodetype}" = "raspiblitz" ]; then
  source /mnt/hdd/raspiblitz.conf
fi

# Node menu options (if necessary)
NODE_OPTIONS=(LND "Send sats using the LND node" \
              CL "Send sats using the Core Lightning node")

# Denomination menu options
OPTIONS=(SATS "Send sats" \
         USD "Send sats denominated in dollars")

# Send frequency menu options
FREQUENCY_OPTIONS=(DAILY "Send sats every day" \
                   WEEKLY "Send sats once a week, every Sunday"
                   MONTHLY "Send sats once a month, on the 1st"
                   YEARLY "Send sats once a year, on January 1st")


# Detect if the user has cancelled running the script at any point in time.
function cancel_check(){
  if [[ -z "$1" ]]; then
    echo "Cancelled"
    exit 0
  fi
}

# User select sats or dollars to denominate in.
DENOMINATION=$(dialog --clear \
        --backtitle "Recurring Payments" \
        --title "Recurring Keysend" \
        --ok-label "Select" \
        --cancel-label "Exit" \
        --menu "Automatically send some sats to another node on a daily/weekly/monthly basis." \
        $HEIGHT $WIDTH $HEIGHT \
        "${OPTIONS[@]}" \
        2>&1 >/dev/tty)

cancel_check $DENOMINATION

# After choosing denomination, ask user how many dollars or sats to send
case $DENOMINATION in
      SATS)
        AMOUNT=$(dialog --backtitle "Recurring Payments" \
            --title "Choose the amount" \
            --inputbox "Enter the amount to send in $DENOMINATION" \
            10 60 100 2>&1 >/dev/tty)
        ;;
      USD)
        AMOUNT=$(dialog --backtitle "Recurring Payments" \
            --title "Choose the amount" \
            --inputbox "Enter the amount to send in $DENOMINATION" \
            10 60 0.50 2>&1 >/dev/tty)
        ;;
esac

cancel_check $AMOUNT

# check which node implementation to use, and if necessary, ask the user
if [ "${nodetype}" = "raspiblitz" ]; then
  if [ "${lnd}" = "on" ]; then
    if [ "${cl}" = "on" ]; then
      node="ask"
    else
      node="lnd"
    fi
   else
    if [ "${cl}" = "on" ]; then
      node="none"
    else
      node="cln"
    fi
  fi
  if [ "${node}" = "ask" ]; then
    # Ask user which node implementation to use
    NODE_TYPE=$(dialog --clear \
          --backtitle "Recurring Payments" \
          --title "Recurring Keysend" \
          --ok-label "Select" \
          --cancel-label "Exit" \
          --menu "Automatically send some sats to another node on a daily/weekly/monthly basis." \
          $HEIGHT $WIDTH $HEIGHT \
          "${NODE_OPTIONS[@]}" \
          2>&1 >/dev/tty)

    cancel_check $NODE_TYPE

    case $NODE_TYPE in
          LND)
            node="lnd"
            ;;
          CL)
            node="cln"
            ;;
    esac
  fi
else
  node="lnd"
fi
if [ "${node}" = "none" ]; then
  echo "error: no node implementation found."
  exit 1
fi

# Ask user for node ID to send to.
NODE_ID=$(whiptail --backtitle "Recurring Payments" \
            --title "Node Address" \
            --inputbox "Enter the 66-character public key of the node you'd like to send to.
            \n(e.g: 02c3afc714b2ea1d4ec35e5d4c6a... )" \
            10 60 2>&1 >/dev/tty)

cancel_check $NODE_ID

# Ask user how frequently they'd like to send sats
FREQUENCY=$(dialog --clear \
        --backtitle "Recurring Payments" \
        --title "Select Frequency" \
        --ok-label "Select" \
        --cancel-label "Exit" \
        --menu "How often do you want to send sats to this node?" \
        $HEIGHT $WIDTH $HEIGHT \
        "${FREQUENCY_OPTIONS[@]}" \
        2>&1 >/dev/tty)

case $FREQUENCY in
      DAILY)
        freq="daily"
        calendarCode="*-*-*"
        ;;
      WEEKLY)
        freq="weekly"
        calendarCode="Sun"
        ;;
      MONTHLY)
        freq="monthly"
        calendarCode="*-*-01"
        ;;
      YEARLY)
        freq="yearly"
        calendarCode="*-01-01"
        ;;
esac

cancel_check $freq

# Ask if user wants to include a message, and if so, what message.
message=""
whiptail --title "Include Message?" \
--yes-button "Yes" \
--no-button "No" \
--yesno "
You may include a message with your keysend. This helps the recipient know
who sent the payment. If you use this with @allyourbankarebelongtous VPS
service, please include your TG handle or protonmail email for accounting.
" 12 85
if [ $? -eq 0 ]; then
  sudo touch ${execdir}/payments/.tmp
  sudo chmod 777 ${execdir}/payments/.tmp
  whiptail --title "Enter Message" --inputbox "Enter the message you wish to send with each payment" 12 100 2>${execdir}/payments/.tmp
  message=$(cat ${execdir}/payments/.tmp)
  sudo rm ${execdir}/payments/.tmp
fi
 
# Generate a keysend script
short_node_id=$(echo $NODE_ID | cut -c 1-7)
script_name="${execdir}/payments/keysends/_${short_node_id}_${freq}_${node}_keysend.sh"
script_backup_name="${homedir}/payments/keysends/_${short_node_id}_${freq}_${node}_keysend.sh"
denomination=$(echo $DENOMINATION | tr '[:upper:]' '[:lower:]')
echo -n "${execdir}/.venv/bin/python ${execdir}/payments/_recurringpayment_${node}.py " \
      "--$denomination $AMOUNT " \
      "--node_id $NODE_ID " \
      > $script_name
# add message if present
if [ ! "${message}" = "" ]; then
  echo "--message \"${message}\"
" | tee -a $script_name
fi
chmod 755 $script_name

# add payment to execution list
subscriptionlist="${execdir}/payments/${freq}${node}payments.sh"
# first check if already on the list to avoid duplicates in case of payment change
scriptexists=$(cat ${subscriptionlist} | grep -c ${script_name})
if [ ${scriptexists} -eq 0 ]; then
  echo "${script_name}" >>${subscriptionlist}
  subscriptionbackuplist="${homedir}/payments/${freq}${node}payments.sh"
  sudo cp -p $subscriptionlist $subscriptionbackuplist
fi

# check if systemd unit for frequency and node exists, and if not, create it
istimer=$(sudo ls /etc/systemd/system/ | grep -c payments-${freq}-${node}.timer)
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
sudo systemctl enable payments-${freq}-${node}.timer
sudo systemctl start payments-${freq}-${node}.timer


