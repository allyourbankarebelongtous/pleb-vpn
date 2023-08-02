#!/bin/bash

# turn Core Lightning node hybrid mode on or off
# example: "cln-hybrid.sh on"

# find home directory based on node implementation
if [ -d "/mnt/hdd/mynode/pleb-vpn/" ]; then
  homedir="/mnt/hdd/mynode/pleb-vpn"
  execdir="/opt/mynode/pleb-vpn"
elif [ -f "/mnt/hdd/raspiblitz.conf" ]; then
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
    sed -i --follow-symlinks "${LINENUMBER}i${NAME}=" ${FILE}
  fi
  echo "# updating setting (${NAME}) with value(${VALUE})"
  sed -i --follow-symlinks "s/^${NAME}=.*/${NAME}=${VALUE}/g" ${FILE}
}

status() {
  # show current Core Lightning status
  local webui="${1}"
  nodeName=$(sudo -u bitcoin lightning-cli getinfo | jq .alias | sed 's/\"//g')
  nodeID=$(sudo -u bitcoin lightning-cli getinfo | jq .id | sed 's/\"//g')
  address0Type=$(sudo -u bitcoin lightning-cli getinfo | jq .address[0].type | sed 's/\"//g')
  address0Port=$(sudo -u bitcoin lightning-cli getinfo | jq .address[0].port | sed 's/\"//g')
  address0=$(sudo -u bitcoin lightning-cli getinfo | jq .address[0].address | sed 's/\"//g')
  if [ "${clnhybrid}" = "on" ]; then
    address1Type=$(sudo -u bitcoin lightning-cli getinfo | jq .address[1].type | sed 's/\"//g')
    address1Port=$(sudo -u bitcoin lightning-cli getinfo | jq .address[1].port | sed 's/\"//g')
    address1=$(sudo -u bitcoin lightning-cli getinfo | jq .address[1].address | sed 's/\"//g')
    if [ "${webui}" = "1" ]; then
      echo "Alias='${nodeName}'
Node_ID='${nodeID}'
address0='${address0}:${address0Port}'
address1='${address1}:${address1Port}'
address0Type='${address0Type}'
address1Type='${address1Type}'" | tee ${execdir}/cln_hybrid_status.tmp
    else
      whiptail --title "Core Lightning hybrid status" --msgbox "
Alias = ${nodeName}
Hybrid Mode = ${clnhybrid}
Node ID = ${nodeID}
${address0Type} address: ${address0}:${address0Port}
${address1Type} address: ${address1}:${address1Port}
" 13 100
    fi
    exit 0
  else
    if [ "${webui}" = "1" ]; then
      echo "Alias='${nodeName}'
Node_ID='${nodeID}'
address0='${address0}:${address0Port}'
address0Type='${address0Type}'" | tee ${execdir}/cln_hybrid_status.tmp
    else
      whiptail --title "Core Lightning status" --msgbox "
Alias = ${nodeName}
Hybrid Mode = ${clnhybrid}
Node ID = ${nodeID}
${address0Type} address: ${address0}:${address0Port}
" 12 100
    fi
    exit 0
  fi
}

on() {
  # enable hybrid mode
  if [ "${nodetype}" = "raspiblitz" ]; then
    source /mnt/hdd/raspiblitz.conf
  fi
  local isRestore="${1}"
  local webui="${2}"

  # check if plebvpn is on
  if ! [ "${plebvpn}" = "on" ]; then
    echo "error: turn on plebvpn before enabling hybrid mode"
    exit 1
  fi
  # check if CLN node is availabe
  if [ "${nodetype}" = "mynode" ]; then
    echo "error: no core lightning node found"
    exit 1
  elif [ "${nodetype}" = "raspiblitz" ]; then
    if ! [ "${cl}" = "on" ]; then
      echo "error: no core lightning node found"
      exit 1
    fi
  fi

  # get CLN port
  if [ ! -z "${clnport}" ]; then
    # skip if restoring
    if [ ! "${isRestore}" = "1" ]; then
      whiptail --title "Use Existing Port?" \
      --yes-button "Use Existing" \
      --no-button "Enter New Port" \
      --yesno "There is an existing port from a previous install. Do you want to re-use ${clnport} or enter a new one?" 10 80
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
    if [ "${nodetype}" = "raspiblitz" ]; then
      touch /var/cache/raspiblitz/.tmp
      chmod 777 /var/cache/raspiblitz/.tmp
      whiptail --title "Core Lightning Clearnet Port" --inputbox "Enter the clearnet port assigned to your Core Lightning node. If you don't have one, forward one from your VPS or contact your VPS provider to obtain one. (example: 9740)" 12 80 2>/var/cache/raspiblitz/.tmp
      clnport=$(cat /var/cache/raspiblitz/.tmp)
      # check to make sure port isn't already used by LND or WireGuard
      if [ "${clnport}" = "${lnport}" ] || [ "${clnport}" = "${wgport}" ]; then
        whiptail --title "Core Lightning Clearnet Port" --inputbox "ERROR: You must not use the same port as a previous service. Enter a different port than ${clnport}." 12 80 2>/var/cache/raspiblitz/.tmp
        clnport=$(cat /var/cache/raspiblitz/.tmp)
        if [ "${clnport}" = "${lnport}" ] || [ "${clnport}" = "${wgport}" ]; then
          echo "error: port must be different than other services"
          exit 1
        fi
      fi
      # add CLN port to pleb-vpn.conf  
      setting ${plebVPNConf} "2" "clnport" "'${clnport}'"
    else
      echo "ERROR: no port for CLN to enable hybrid mode."
      exit 1
    fi
  fi
  # configure firewall
  ufw allow ${clnport} comment "CLN Port"
  # edit CLN config
  # Tor settings
  sectionName="Tor settings"
  echo "# ${sectionName} config ..."
  sectionLine=$(cat ${clnconffile} | grep -n "^\# ${sectionName}" | cut -d ":" -f1)
  echo "# sectionLine(${sectionLine})"
  insertLine=$(expr $sectionLine + 1)
  echo "# insertLine(${insertLine})"
  fileLines=$(wc -l ${clnconffile} | cut -d " " -f1)
  echo "# fileLines(${fileLines})"
  if [ ${fileLines} -lt ${insertLine} ]; then
    echo "# adding new line for inserts"
    echo "
  " | tee -a ${clnconffile}
  fi
  echo "# sectionLine(${sectionLine})"
  setting ${clnconffile} ${insertLine} "always-use-proxy" "false"
  # Clearnet settings
  sectionName="Clearnet settings"
  echo "# ${sectionName} config ..."
  sectionExists=$(cat ${clnconffile} | grep -c "^\# ${sectionName}")
  echo "# sectionExists(${sectionExists})"
  if [ "${sectionExists}" == "0" ]; then
    echo "# adding section # Clearnet settings"
    echo "
# Clearnet settings
" | tee -a ${clnconffile}
  fi
  sectionLine=$(cat ${clnconffile} | grep -n "^\# ${sectionName}" | cut -d ":" -f1)
  echo "# sectionLine(${sectionLine})"
  insertLine=$(expr $sectionLine + 1)
  echo "# insertLine(${insertLine})"
  fileLines=$(wc -l ${clnconffile} | cut -d " " -f1)
  echo "# fileLines(${fileLines})"
  if [ ${fileLines} -lt ${insertLine} ]; then
    echo "# adding new line for inserts"
    echo "
  " | tee -a ${clnconffile}
  fi
  echo "# sectionLine(${sectionLine})"
  isBindaddr=$(cat ${clnconffile} | grep -c "bind-addr=0.0.0.0:")
  if [ ${isBindaddr} -eq 0 ]; then
    sed -i "${insertLine}ibind-addr=0.0.0.0:${clnport}" ${clnconffile}
  else
    sed -i "s/bind-addr=0\.0\.0\.0:.*/bind-addr=0\.0\.0\.0:${clnport}/" ${clnconffile}
  fi
  setting ${clnconffile} ${insertLine} "announce-addr" "${vpnip}:${clnport}"

  # restart CLN (skip this step on restore but not if webui)
  if ! [ "${isRestore}" = "1" ]; then
    systemctl restart lightningd.service
  fi
  if [ "${webui}" = "1" ]; then
    systemctl restart lightningd.service
  fi
  # set cln-hybrid on in pleb-vpn.conf
  setting ${plebVPNConf} "2" "clnhybrid" "on"
  exit 0
}

off() {
  # disable hybrid mode
  # Tor settings
  sectionName="Tor settings"
  echo "# ${sectionName} config ..."
  sectionLine=$(cat ${clnconffile} | grep -n "^\# ${sectionName}" | cut -d ":" -f1)
  echo "# sectionLine(${sectionLine})"
  insertLine=$(expr $sectionLine + 1)
  echo "# insertLine(${insertLine})"
  fileLines=$(wc -l ${clnconffile} | cut -d " " -f1)
  echo "# fileLines(${fileLines})"
  if [ ${fileLines} -lt ${insertLine} ]; then
    echo "# adding new line for inserts"
    echo "
" | tee -a ${clnconffile}
  fi
  echo "# sectionLine(${sectionLine})"
  setting ${clnconffile} ${insertLine} "always-use-proxy" "true"
  # Clearnet settings
  sectionName="Clearnet settings"
  echo "# ${sectionName} config ..."
  echo "removing Clearnet settings ..."
  sed -i '/Clearnet settings/d' ${clnconffile}
  sed -i '/bind-addr=0.0.0.0/d' ${clnconffile}
  sed -i '/announce-addr/d' ${clnconffile}
  # configure firewall
  if [ ! "${clnport}" = "9736" ] && [ ! "${clnport}" = "9735" ]; then
    ufw delete allow ${clnport}
  fi
  # restart CLN
  systemctl restart lightningd.service
  # set cln-hybrid off in pleb-vpn.conf
  setting ${plebVPNConf} "2" "clnhybrid" "off"
  exit 0
}

case "${1}" in
  status) status "${2}" ;;
  on) on "${2}" "${3}" ;;
  off) off ;;
  *) echo "config script to turn Core Lighting hybrid mode on or off"; echo "cln-hybrid.sh [status|on|off]"; exit 1 ;;
esac
