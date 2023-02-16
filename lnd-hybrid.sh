#!/bin/bash

# turn LND node hybrid mode on or off
# example: "lnd-hybrid.sh on"

# command info
if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "-help" ]; then
  echo "config script to turn LND hybrid mode on or off"
  echo "lnd-hybrid.sh [status|on|off]"
  exit 1
fi

plebVPNConf="/home/admin/pleb-vpn/pleb-vpn.conf"

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
  sudo sed -i --follow-symlinks "s/^${NAME}=.*/${NAME}=${VALUE}/g" ${FILE}
}

status() {
  source ${plebVPNConf}
  nodeName=$(lncli getinfo | jq .alias | sed 's/\"//g')
  nodeID=$(lncli getinfo | jq .identity_pubkey | sed 's/\"//g')
  address0=$(lncli getinfo | jq .uris[0] | sed 's/\"//g' | cut -d "@" -f2)
  istor=$(echo "${address0}" | grep -c onion)
  isv6=$(echo "${address0}" | grep -c :)
  if [ $istor -eq 0 ]; then
    if [ $isv6 -gt 1 ]; then
      address0Type="ipv6"
    else
      address0Type="ipv4"
    fi
  else
    address0Type="torv3"
  fi
  if [ "${lndHybrid}" = "on" ]; then
    address1=$(lncli getinfo | jq .uris[1] | sed 's/\"//g' | cut -d "@" -f2)
    istor=$(echo "${address1}" | grep -c onion)
    isv6=$(echo "${address1}" | grep -c :)
    if [ $istor -eq 0 ]; then
      if [ $isv6 -gt 1 ]; then
        address1Type="ipv6"
      else
        address1Type="ipv4"
      fi
    else
      address1Type="torv3"
    fi
    whiptail --title "LND Node hybrid status" --msgbox "
Alias = ${nodeName}
Hybrid Mode = ${lndHybrid}
Node ID = ${nodeID}
${address0Type} address: ${address0}
${address1Type} address: ${address1}
" 13 100
    exit 0
  else
    whiptail --title "Core Lightning status" --msgbox "
Alias = ${nodeName}
Hybrid Mode = ${lndHybrid}
Node ID = ${nodeID}
${address0Type} address: ${address0}
" 12 100
    exit 0
  fi
}

on() {
  # enable hybrid mode 
  source ${plebVPNConf}
  source /mnt/hdd/raspiblitz.conf
  local isRestore = "${1}"

  # check if plebvpn is on
  if ! [ "${plebVPN}" = "on" ]; then
    echo "error: turn on plebvpn before enabling hybrid mode"
    exit 1
  fi
  # check if LND node is availabe
  if ! [ "${lnd}" = "on" ]; then
    echo "error: no LND node found"
    exit 1
  fi 
  # get LND port
  if [ ! "${lnPort}" = "" ]; then
    # skip if restoring
    if [ ! "${isRestore}" = "1" ]; then
      whiptail --title "Use Existing Port?" \
      --yes-button "Use Existing" \
      --no-button "Enter New Port" \
      --yesno "There is an existing port from a previous install. Do you want to re-use ${lnPort} or enter a new one?" 10 80
      if [ $? -eq 1 ]; then
        keepport="0"
      else
        keepport="1"
      fi
    else
      keepport="1"
    fi
  else
    keepport="0"
  fi
  if [ "${keepport}" = "0" ]; then
    sudo touch /var/cache/raspiblitz/.tmp
    sudo chmod 777 /var/cache/raspiblitz/.tmp
    whiptail --title "LND Clearnet Port" --inputbox "Enter the port that is forwarded to your node from the VPS for hybrid mode. If you don't have one, forward one from your VPS or contact your VPS provider to obtain one. (example: 9740)" 12 80 2>/var/cache/raspiblitz/.tmp
    lnPort=$(cat /var/cache/raspiblitz/.tmp)
    # add LND port to pleb-vpn.conf 
    setting ${plebVPNConf} "2" "lnPort" "'${lnPort}'"
  fi

  # configure firewall
  if ! [ "${lnPort}" = "9735" ]; then
    sudo ufw allow ${lnPort} comment "LND Port"
  fi
  # fix lnd.check.sh (also fixes database compact time)
  sectionStart=$(cat /home/admin/config.scripts/lnd.check.sh | grep -n "\# enforce PublicIP if (if not running Tor)" | cut -d ":" -f1)
  inc=1
  while [ $inc -le 6 ]
  do
    fileLine=$(expr $sectionStart + $inc)
	  sudo sed -i "${fileLine}s/^/#/" /home/admin/config.scripts/lnd.check.sh
	  ((inc++))
  done
  # edit lnd.conf
  source /mnt/hdd/raspiblitz.conf
  source <(/home/admin/config.scripts/network.aliases.sh getvars lnd)
  # Application Options 
  sectionName="Application Options"
  publicIP="${vpnIP}"
  echo "# [${sectionName}] config ..."
  sectionLine=$(cat ${lndConfFile} | grep -n "^\[${sectionName}\]" | cut -d ":" -f1)
  echo "# sectionLine(${sectionLine})"
  insertLine=$(expr $sectionLine + 1)
  echo "# insertLine(${insertLine})"
  fileLines=$(wc -l ${lndConfFile} | cut -d " " -f1)
  echo "# fileLines(${fileLines})"
  if [ ${fileLines} -lt ${insertLine} ]; then
    echo "# adding new line for inserts"
    echo "
  " | sudo tee -a ${lndConfFile}
  fi
  echo "# sectionLine(${sectionLine})"
  setting ${lndConfFile} ${insertLine} "externalip" "${publicIP}:${lnPort}"
  setting ${lndConfFile} ${insertLine} "listen" "0.0.0.0:${lnPort}"
  # set tlsextraip if wireguard="on"
  if [ "${wireguard}" = "on" ]; then 
    setting ${lndConfFile} ${insertLine} "tlsextraip" "${wgIP}"
  fi

  # tor
  sectionName="tor"
  echo "# [${sectionName}] config ..."
  sectionLine=$(cat ${lndConfFile} | grep -n "^\[${sectionName}\]" | cut -d ":" -f1)
  echo "# sectionLine(${sectionLine})"
  insertLine=$(expr $sectionLine + 1)
  echo "# insertLine(${insertLine})"
  fileLines=$(wc -l ${lndConfFile} | cut -d " " -f1)
  echo "# fileLines(${fileLines})"
  if [ ${fileLines} -lt ${insertLine} ]; then
    echo "# adding new line for inserts"
    echo "
  " | sudo tee -a ${lndConfFile}
  fi
  setting ${lndConfFile} ${insertLine} "tor.streamisolation" "false"
  setting ${lndConfFile} ${insertLine} "tor.skip-proxy-for-clearnet-targets" "true"
  # edit raspiblitz.conf
  raspiConfFile="/mnt/hdd/raspiblitz.conf"
  lndAddress="${vpnIP}"
  publicIP="${vpnIP}" 
  echo "# RASPIBLITZ CONFIG FILE config ..."
  sectionLine="1"
  echo "# sectionLine(${sectionLine})"
  insertLine=$(expr $sectionLine + 1)
  echo "# insertLine(${insertLine})"
  fileLines=$(wc -l ${raspiConfFile} | cut -d " " -f1)
  echo "# fileLines(${fileLines})"
  if [ ${fileLines} -lt ${insertLine} ]; then
    echo "# adding new line for inserts"
    echo "
  " | sudo tee -a ${raspiConfFile}
  fi
  setting ${raspiConfFile} ${insertLine} "lndPort" "'${lnPort}'"
  setting ${raspiConfFile} ${insertLine} "lndAddress" "'${lndAddress}'"
  setting ${raspiConfFile} ${insertLine} "publicIP" "'${publicIP}'"
  # restart lnd (skip this step on restore)
  local norestart="${1}"
  if ! [ "${norestart}" = "1" ]; then
    sudo systemctl restart lnd 
    # restart nginx
    sudo systemctl restart nginx
  fi
  # set lnd-hybrid on in pleb-vpn.conf
  setting ${plebVPNConf} "2" "lndHybrid" "on"
  exit 0
}

off() {
  # disable hybrid mode 
  source ${plebVPNConf}
  if [ -z "${wgLAN}" ]; then
    wireguard=0
  else
    wireguard=1
  fi
  # configure firewall
  if ! [ "${lnPort}" = "9735" ]; then
    sudo ufw delete allow ${lnPort}
  fi
  # fix lnd.check.sh (also fixes database compact time)
  sectionStart=$(cat /home/admin/config.scripts/lnd.check.sh | grep -n "\  # enforce PublicIP if (if not running Tor)" | cut -d ":" -f1)
  inc=1
  while [ $inc -le 6 ]
  do
    fileLine=$(expr $sectionStart + $inc)
	  sudo sed -i "${fileLine}s/#//" /home/admin/config.scripts/lnd.check.sh
	  ((inc++))
  done
  # edit lnd.conf
  source /mnt/hdd/raspiblitz.conf
  source <(/home/admin/config.scripts/network.aliases.sh getvars lnd)
  # Application Options 
  sudo sed -i '/^externalip=*/d' ${lndConfFile}
  if [ $wireguard -eq 1 ]; then 
    sudo sed -i '/^tlsextraip=*/d' ${lndConfFile}
  fi
  sudo sed -i '/^listen=*/d' ${lndConfFile}
  # tor
  sectionName="tor"
  echo "# [${sectionName}] config ..."
  sectionLine=$(cat ${lndConfFile} | grep -n "^\[${sectionName}\]" | cut -d ":" -f1)
  echo "# sectionLine(${sectionLine})"
  insertLine=$(expr $sectionLine + 1)
  echo "# insertLine(${insertLine})"
  fileLines=$(wc -l ${lndConfFile} | cut -d " " -f1)
  echo "# fileLines(${fileLines})"
  if [ ${fileLines} -lt ${insertLine} ]; then
    echo "# adding new line for inserts"
    echo "
  " | sudo tee -a ${lndConfFile}
  fi
  setting ${lndConfFile} ${insertLine} "tor.skip-proxy-for-clearnet-targets" "false"
  # edit raspiblitz.conf
  raspiConfFile="/mnt/hdd/raspiblitz.conf"
  sudo sed -i '/^lndPort=*/d' ${raspiConfFile}
  sudo sed -i '/^lndAddress=*/d' ${raspiConfFile}
  sudo sed -i '/^publicIP=*/d' ${raspiConfFile}
  # restart lnd
  sudo systemctl restart lnd 
  # set lnd-hybrid off in pleb-vpn.conf
  setting ${plebVPNConf} "2" "lndHybrid" "off"
  exit 0
}

case "${1}" in
  status) status ;;
  on) on "${2}" ;;
  off) off ;;
  *) echo "err=Unknown action: ${1}" ; exit 1 ;;
esac
