#!/bin/bash

# initial install script for pleb-vpn
# used for installing or uninstalling pleb-vpn on raspiblitz
# establishes system configuration backups using pleb-vpn.backup.sh and restores on uninstall
# sets initial values in pleb-vpn.conf, including LAN, lndConfFile, CLNConfFile

# command info
if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "-help" ]; then
  echo "install script for installing, updating, restoring after blitz update, or uninstalling pleb-vpn"
  echo "pleb-vpn.install.sh [on|update|uninstall]"
  exit 1
fi

function setting() # FILE LINENUMBER NAME VALUE
{
  FILE=$1
  LINENUMBER=$2
  NAME=$3
  VALUE=$4
  settingExists=$(cat ${FILE} | grep -c "^${NAME}=")
  echo "# setting ${FILE} ${LINENUMBER} ${NAME} ${VALUE}"
  echo "# ${NAME} exists->(${settingExists})"
  if [ "${settingExists}" == "0" ]; then
    echo "# adding setting (${NAME})"
    sudo sed -i --follow-symlinks "${LINENUMBER}i${NAME}=" ${FILE}
  fi
  echo "# updating setting (${NAME}) with value(${VALUE})"
  sudo sed -i --follow-symlinks "s:^${NAME}=.*:${NAME}=${VALUE}:g" ${FILE}
}

on() {
  # only for new install

  # move the files to /mnt/hdd/app-data/pleb-vpn
  sudo mkdir /home/admin/pleb-vpn/payments/keysends
  sudo cp -p -r /home/admin/pleb-vpn /mnt/hdd/app-data/
  # fix permissions
  sudo chown -R admin:admin /mnt/hdd/app-data/pleb-vpn
  sudo chown -R admin:admin /home/admin/pleb-vpn
  sudo chmod -R 755 /mnt/hdd/app-data/pleb-vpn
  sudo chmod -R 755 /home/admin/pleb-vpn
  # create and symlink pleb-vpn.conf
  echo "# PlebVPN CONFIG FILE


####################
# Available values #
####################
# vpnIP
# vpnPort
# wgLAN
# wgIP
# wgPort
# CLNPort
# lnPort
# wireguard
# clnHybrid
# lndHybrid
# CLNConfFile
# lndConfFile
# LAN
# plebVPN" | tee /mnt/hdd/app-data/pleb-vpn/pleb-vpn.conf
  sudo ln -sf /mnt/hdd/app-data/pleb-vpn/pleb-vpn.conf /home/admin/pleb-vpn/pleb-vpn.conf
  # backup critical files and configs
  /home/admin/pleb-vpn/pleb-vpn.backup.sh backup
  # initialize payment files
  inc=1
  while [ $inc -le 8 ]
  do
    if [ $inc -le 4 ]; then
      node="lnd"
    else
      node="cln"
    fi
    if [ $((inc % 4)) -eq 1 ]; then
      freq="daily"
      description="at 00:00:00 UTC"
    fi
    if [ $((inc % 4)) -eq 2 ]; then
      freq="weekly"
      description="Sunday at 00:00:00 UTC"
    fi
    if [ $((inc % 4)) -eq 3 ]; then
      freq="monthly"
      description="1st of each month at 00:00:00 UTC"
    fi
    if [ $((inc % 4)) -eq 0 ]; then
      freq="yearly"
      description="1st of each year at 00:00:00 UTC"
    fi
    echo -n "#!/bin/bash

# ${freq} payments ($description)
" > /home/admin/pleb-vpn/payments/${freq}${node}lndpayments.sh
    ((inc++))
  done
  sudo cp -p /home/admin/pleb-vpn/payments/*lndpayments.sh /mnt/hdd/app-data/pleb-vpn/payments/
  sudo cp -p /home/admin/pleb-vpn/payments/*clnpayments.sh /mnt/hdd/app-data/pleb-vpn/payments/
  # fix permissions
  sudo chown -R admin:admin /mnt/hdd/app-data/pleb-vpn
  sudo chown -R admin:admin /home/admin/pleb-vpn
  sudo chmod -R 755 /mnt/hdd/app-data/pleb-vpn
  sudo chmod -R 755 /home/admin/pleb-vpn
  # initialize pleb-vpn.conf
  plebVPNConf="/home/admin/pleb-vpn/pleb-vpn.conf"
  # get initial values
  source <(/home/admin/_cache.sh get internet_localip)
  source <(/home/admin/config.scripts/network.aliases.sh getvars cl)
  source <(/home/admin/config.scripts/network.aliases.sh getvars lnd)
  LAN=$(echo "${internet_localip}" | sed 's/^\(.*\)\.\(.*\)\.\(.*\)\.\(.*\)$/\1\.\2\.\3/g')
  setting ${plebVPNConf} "2" "LndConfFile" "'${lndConfFile}'"
  setting ${plebVPNConf} "2" "CLNConfFile" "'${CLCONF}'"
  setting ${plebVPNConf} "2" "LAN" "'${LAN}'"
  setting ${plebVPNConf} "2" "torSplitTunnel" "off"
  setting ${plebVPNConf} "2" "lndHybrid" "off"
  setting ${plebVPNConf} "2" "clnHybrid" "off"
  setting ${plebVPNConf} "2" "wireguard" "off"
  setting ${plebVPNConf} "2" "plebVPN" "off"
  # make persistant with custom-installs.sh
  isPersistant=$(cat /mnt/hdd/app-data/custom-installs.sh | grep -c /mnt/hdd/app-data/pleb-vpn/pleb-vpn.install.sh)
  if [ ${isPersistant} -eq 0 ]; then
    echo "/mnt/hdd/app-data/pleb-vpn/pleb-vpn.install.sh restore
" | sudo tee -a /mnt/hdd/app-data/custom-installs.sh
  fi
  # add pleb-vpn to 00mainMenu.sh
  mainMenu="/home/admin/00mainMenu.sh"
  sectionName="# Activated Apps/Services"
  echo "#${sectionName} config ..."
  sectionLine=$(cat ${mainMenu} | grep -n "^${sectionName}" | cut -d ":" -f1)
  echo "# sectionLine(${sectionLine})"
  insertLine=$(expr $sectionLine + 1)
  echo "# insertLine(${insertLine})"
  Line='OPTIONS+=(PLEB-VPN "Install and manage PLEB-VPN services")'
  sudo sed -i "${insertLine}i${Line}" ${mainMenu}
  sectionName="/home/admin/99connectMenu.sh"
  sectionLine=$(cat ${mainMenu} | grep -n "${sectionName}" | cut -d ":" -f1)
  echo "# sectionLine(${sectionLine})"
  insertLine=$(expr $sectionLine + 2)
  echo "# insertLine(${insertLine})"
  Line='PLEB-VPN)'
  sudo sed -i "${insertLine}i        ${Line}" ${mainMenu}
  insertLine=$(expr $sectionLine + 3)
  Line='/home/admin/pleb-vpn/pleb-vpnMenu.sh'
  sudo sed -i "${insertLine}i            ${Line}" ${mainMenu}
  insertLine=$(expr $sectionLine + 4)
  Line=';;'
  sudo sed -i "${insertLine}i            ${Line}" ${mainMenu}
  exit 0
}

update() {
  sudo rm -rf /home/admin/pleb-vpn
  cd /home/admin
  git clone https://github.com/allyourbankarebelongtous/pleb-vpn.git
#  these commands are for checking out a specific branch for testing
#  cd /home/admin/pleb-vpn
#  git checkout -b v0.9.1-tor-split-tunnel
#  git pull origin v0.9.1-tor-split-tunnel 
  sudo cp -p -r /home/admin/pleb-vpn /mnt/hdd/app-data/
  # fix permissions
  sudo chown -R admin:admin /mnt/hdd/app-data/pleb-vpn
  sudo chown -R admin:admin /home/admin/pleb-vpn
  sudo chmod -R 755 /mnt/hdd/app-data/pleb-vpn
  sudo chmod -R 755 /home/admin/pleb-vpn
  if [ -d /mnt/hdd/app-data/pleb-vpn/split-tunnel/ ]; then
    sudo cp -p -r /mnt/hdd/app-data/pleb-vpn/split-tunnel /home/admin/pleb-vpn/
  fi
  sudo cp -p -r /mnt/hdd/app-data/pleb-vpn/payments /home/admin/pleb-vpn/
  sudo ln -s /mnt/hdd/app-data/pleb-vpn/pleb-vpn.conf /home/admin/pleb-vpn/pleb-vpn.conf
  exit 0
}

restore() {
  plebVPNConf="/home/admin/pleb-vpn/pleb-vpn.conf"
  # fix permissions
  sudo chown -R admin:admin /mnt/hdd/app-data/pleb-vpn
  sudo chmod -R 755 /mnt/hdd/app-data/pleb-vpn
  sudo rm -rf /mnt/hdd/app-data/pleb-vpn/.backups
  # copy files to /home/admin/pleb-vpn
  sudo cp -p -r /mnt/hdd/app-data/pleb-vpn/ /home/admin/
  # remove and symlink pleb-vpn.conf
  sudo rm /home/admin/pleb-vpn/pleb-vpn.conf
  sudo ln -s /mnt/hdd/app-data/pleb-vpn/pleb-vpn.conf /home/admin/pleb-vpn/pleb-vpn.conf
  # fix permissions
  sudo chown -R admin:admin /home/admin/pleb-vpn
  sudo chmod -R 755 /home/admin/pleb-vpn
  # backup critical files and configs
  /home/admin/pleb-vpn/pleb-vpn.backup.sh backup
  # add pleb-vpn to 00mainMenu.sh
  mainMenu="/home/admin/00mainMenu.sh"
  sectionName="# Activated Apps/Services"
  echo "#${sectionName} config ..."
  sectionLine=$(cat ${mainMenu} | grep -n "^${sectionName}" | cut -d ":" -f1)
  echo "# sectionLine(${sectionLine})"
  insertLine=$(expr $sectionLine + 1)
  echo "# insertLine(${insertLine})"
  Line='OPTIONS+=(PLEB-VPN "Install and manage PLEB-VPN services")'
  sudo sed -i "${insertLine}i${Line}" ${mainMenu}
  sectionName="/home/admin/99connectMenu.sh"
  sectionLine=$(cat ${mainMenu} | grep -n "${sectionName}" | cut -d ":" -f1)
  echo "# sectionLine(${sectionLine})"
  insertLine=$(expr $sectionLine + 2)
  echo "# insertLine(${insertLine})"
  Line='PLEB-VPN)'
  sudo sed -i "${insertLine}i        ${Line}" ${mainMenu}
  insertLine=$(expr $sectionLine + 3)
  Line='/home/admin/pleb-vpn/pleb-vpnMenu.sh'
  sudo sed -i "${insertLine}i            ${Line}" ${mainMenu}
  insertLine=$(expr $sectionLine + 4)
  Line=';;'
  sudo sed -i "${insertLine}i            ${Line}" ${mainMenu}
  # step through pleb-vpn.conf and restore services
  source ${plebVPNConf}
  if [ "${plebVPN}" = "on" ]; then
    /home/admin/pleb-vpn/vpn-install.sh on 1
  fi
  if [ "${lndHybrid}" = "on" ]; then
    /home/admin/pleb-vpn/lnd-hybrid.sh on 1
  fi
  if [ "${clnHybrid}" = "on" ]; then
    /home/admin/pleb-vpn/cln-hybrid.sh on 1
  fi
  if [ "${wireguard}" = "on" ]; then
    /home/admin/pleb-vpn/wg-install.sh on 1
  fi
  if [ "${torSplitTunnel}" = "on" ]; then
    sudo /home/admin/pleb-vpn/tor.split-tunnel.sh on
  fi
  # restore payment services
  inc=1
  while [ $inc -le 8 ]
  do
    if [ $inc -le 4 ]; then
      node="lnd"
    else
      node="cln"
    fi
    if [ $((inc % 4)) -eq 1 ]; then
      freq="daily"
      calendarCode="*-*-*"
    fi
    if [ $((inc % 4)) -eq 2 ]; then
      freq="weekly"
      calendarCode="Sun"
    fi
    if [ $((inc % 4)) -eq 3 ]; then
      freq="monthly"
      calendarCode="*-*-01"
    fi
    if [ $((inc % 4)) -eq 0 ]; then
      freq="yearly"
      calendarCode="*-01-01"
    fi
    paymentExists=$(cat /home/admin/pleb-vpn/payments/${freq}${node}payments.sh | grep -c keysend)
    if ! [ ${paymentFile} -eq 0 ]; then
      # create systemd timer and service
      echo -n "[Unit]
Description=Execute ${freq} payments

[Service]
User=bitcoin
Group=bitcoin
ExecStart=/bin/bash /home/admin/pleb-vpn/payments/${freq}${node}payments.sh" \
      > /etc/systemd/system/payments-${freq}-${node}.service
      echo -n "# this file will run ${freq} to execute any ${freq} recurring payments
[Unit]
Description=Run recurring payments ${freq}

[Timer]
OnCalendar=${calendarCode}

[Install]
WantedBy=timers.target" \
      > /etc/systemd/system/payments-${freq}-${node}.timer
      sudo systemctl enable payments-${freq}-${node}.timer
      sudo systemctl start payments-${freq}-${node}.timer
    fi
    ((inc++))
  done
  exit 0
}

uninstall() {
  plebVPNConf="/home/admin/pleb-vpn/pleb-vpn.conf"
  source ${plebVPNConf}
  # first uninstall services
  if [ "${torSplitTunnel}" = "on" ]; then
    sudo /home/admin/pleb-vpn/tor.split-tunnel.sh off
  fi
  if [ "${lndHybrid}" = "on" ]; then
    /home/admin/pleb-vpn/lnd-hybrid.sh off
  fi
  if [ "${clnHybrid}" = "on" ]; then
    /home/admin/pleb-vpn/cln-hybrid.sh off
  fi
  if [ "${wireguard}" = "on" ]; then
    /home/admin/pleb-vpn/wg-install.sh off
  fi
  if [ "${plebVPN}" = "on" ]; then
    /home/admin/pleb-vpn/vpn-install.sh off
  fi
  # delete all payments
  /home/admin/pleb-vpn/payments/managepayments.sh deleteall 1
  # restore backups
  /home/admin/pleb-vpn/pleb-vpn.backup.sh restore
  # remove extra line from custom-installs if required
  extraLine="/mnt/hdd/app-data/pleb-vpn/pleb-vpn.install.sh"
  lineExists=$(sudo cat /mnt/hdd/app-data/custom-installs.sh | grep -c "${extraLine}")
  if ! [ ${lineExists} -eq 0 ]; then
    sudo sed -i "s:^${extraLine}.*::g" /mnt/hdd/app-data/custom-installs.sh
  fi
  # remove extra lines from 00mainMenu.sh if required
  extraLine='OPTIONS+=(PLEB-VPN "Install and manage PLEB-VPN services")'
  lineExists=$(sudo cat /home/admin/00mainMenu.sh | grep -c "${extraLine}")
  if ! [ ${lineExists} -eq 0 ]; then
    sudo sed -i "s:.*${extraLine}.*::g" /mnt/hdd/app-data/custom-installs.sh
  fi
  extraLine='PLEB-VPN)'
  lineExists=$(sudo cat /home/admin/00mainMenu.sh | grep -c "${extraLine}")
  if ! [ ${lineExists} -eq 0 ]; then
    sudo sed -i "s:.*${extraLine}.*::g" /mnt/hdd/app-data/custom-installs.sh
  fi
  extraLine='/home/admin/pleb-vpn/pleb-vpnMenu.sh'
  lineExists=$(sudo cat /home/admin/00mainMenu.sh | grep -c "${extraLine}")
  if ! [ ${lineExists} -eq 0 ]; then
    sectionLine=$(cat ${mainMenu} | grep -n "${extraLine}" | cut -d ":" -f1)
    nextLine=$(expr $sectionLine + 1)
    sudo sed -i "${nextLine}d" /mnt/hdd/app-data/custom-installs.sh
    sudo sed -i "s:.*${extraLine}.*::g" /mnt/hdd/app-data/custom-installs.sh
  fi
  # delete files
  sudo rm -rf /home/admin/pleb-vpn
  sudo rm -rf /mnt/hdd/app-data/pleb-vpn.conf
  exit 0
}

case "${1}" in
  on) on ;;
  update) update ;;
  restore) restore ;;
  uninstall) uninstall ;;
  *) echo "err=Unknown action: ${1}" ; exit 1 ;;
esac
