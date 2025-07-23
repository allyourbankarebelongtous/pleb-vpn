#!/bin/bash

# turn LND node hybrid mode on or off
# example: "lnd-hybrid.sh on"

# find home directory based on node implementation
if [ -d "/mnt/hdd/mynode/pleb-vpn/" ]; then
  homedir="/mnt/hdd/mynode/pleb-vpn"
  execdir="/opt/mynode/pleb-vpn"
  firewallConf="/usr/bin/mynode_firewall.sh"
  lndCustomConf="/mnt/hdd/mynode/settings/lnd_custom.conf"
  lndCustomConfOld="/mnt/hdd/mynode/settings/lnd_custom_old.conf"
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
    if [ "${FILE}" = "${lndconffile}" ] && [ "${nodetype}" = "mynode" ]; then
      sudo -u bitcoin sed -i --follow-symlinks "${LINENUMBER}i${NAME}=" ${FILE}
    else
      sed -i --follow-symlinks "${LINENUMBER}i${NAME}=" ${FILE}
    fi
  fi
  echo "# updating setting (${NAME}) with value(${VALUE})"
  if [ "${FILE}" = "${lndconffile}" ] && [ "${nodetype}" = "mynode" ]; then
    sudo -u bitcoin sed -i --follow-symlinks "s/^${NAME}=.*/${NAME}=${VALUE}/g" ${FILE}
  else
    sed -i --follow-symlinks "s/^${NAME}=.*/${NAME}=${VALUE}/g" ${FILE}
  fi
}

status() {
  local webui="${1}"
  nodeName=$(sudo -u bitcoin lncli getinfo | jq .alias | sed 's/\"//g')
  nodeID=$(sudo -u bitcoin lncli getinfo | jq .identity_pubkey | sed 's/\"//g')
  address0=$(sudo -u bitcoin lncli getinfo | jq .uris[0] | sed 's/\"//g' | cut -d "@" -f2)
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
  if [ "${lndhybrid}" = "on" ]; then
    address1=$(sudo -u bitcoin lncli getinfo | jq .uris[1] | sed 's/\"//g' | cut -d "@" -f2)
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
    if [ "${webui}" = "1" ]; then
      echo "Alias='${nodeName}'
Node_ID='${nodeID}'
address0='${address0}'
address1='${address1}'
address0Type='${address0Type}'
address1Type='${address1Type}'" | tee ${execdir}/lnd_hybrid_status.tmp
    else
      whiptail --title "LND Node hybrid status" --msgbox "
Alias = ${nodeName}
Hybrid Mode = ${lndhybrid}
Node ID = ${nodeID}
${address0Type} address: ${address0}
${address1Type} address: ${address1}
" 13 100
    fi
    exit 0 
  else
    if [ "${webui}" = "1" ]; then
      echo "Alias='${nodeName}'
Node_ID='${nodeID}'
address0='${address0}'
address0Type='${address0Type}'" | tee ${execdir}/lnd_hybrid_status.tmp
    else
      whiptail --title "LND Node status" --msgbox "
Alias = ${nodeName}
Hybrid Mode = ${lndhybrid}
Node ID = ${nodeID}
${address0Type} address: ${address0}
" 12 100
    fi
    exit 0
  fi
}

on() {
  # enable hybrid mode
  if [ "${nodetype}" = "raspiblitz" ]; then
    if [ -f "/mnt/hdd/raspiblitz.conf" ]; then
    source /mnt/hdd/raspiblitz.conf
  elif [ -f "/mnt/hdd/app-data/raspiblitz.conf" ]; then
    source /mnt/hdd/app-data/raspiblitz.CONF
  fi
  fi
  local isRestore="${1}"
  local webui="${2}"

  # check if plebvpn is on
  if ! [ "${plebvpn}" = "on" ]; then
    echo "error: turn on plebvpn before enabling hybrid mode"
    exit 1
  fi
  # check if LND node is availabe
  if [ "${nodetype}" = "raspiblitz" ]; then
    if ! [ "${lnd}" = "on" ]; then
      echo "error: no LND node found"
      exit 1
    fi 
  fi
  # get LND port
  if [ ! -z "${lnport}" ]; then
    # skip if restoring
    if [ ! "${isRestore}" = "1" ]; then
      whiptail --title "Use Existing Port?" \
      --yes-button "Use Existing" \
      --no-button "Enter New Port" \
      --yesno "There is an existing port from a previous install. Do you want to re-use ${lnport} or enter a new one?" 10 80
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
      whiptail --title "LND Clearnet Port" --inputbox "Enter the port that is forwarded to your node from the VPS for hybrid mode. If you don't have one, forward one from your VPS or contact your VPS provider to obtain one. (example: 9740)" 12 80 2>/var/cache/raspiblitz/.tmp
      lnport=$(cat /var/cache/raspiblitz/.tmp)
      # check to make sure port isn't already used by CLN or WireGuard
      if [ "${lnport}" = "${clnport}" ] || [ "${lnport}" = "${wgport}" ]; then
        whiptail --title "LND Clearnet Port" --inputbox "ERROR: You must not use the same port as a previous service. Enter a different port than ${lnport}." 12 80 2>/var/cache/raspiblitz/.tmp
        lnport=$(cat /var/cache/raspiblitz/.tmp)
        if [ "${lnport}" = "${clnport}" ] || [ "${lnport}" = "${wgport}" ]; then
          echo "error: port must be different than other services"
          exit 1
        fi
      fi
      # add LND port to pleb-vpn.conf 
      setting ${plebVPNConf} "2" "lnport" "'${lnport}'"
    else
      echo "ERROR: no port for lnd hybrid mode."
      exit 1
    fi
  fi

  # configure firewall
  if ! [ "${lnport}" = "9735" ]; then
    ufw allow ${lnport} comment "LND Port"
    if [ "${nodetype}" = "mynode" ]; then
      # add new rules to firewallConf
      sectionLine=$(cat ${firewallConf} | grep -n "^\# Add firewall rules" | cut -d ":" -f1 | head -n 1)
      insertLine=$(expr $sectionLine + 1)
      sed -i "${insertLine}iufw allow ${lnport} comment 'LND Port'" ${firewallConf}
    fi
  fi
  if [ "${nodetype}" = "raspiblitz" ]; then
    # fix lnd.check.sh
    sectionStart=$(cat /home/admin/config.scripts/lnd.check.sh | grep -n "\# enforce PublicIP if (if not running Tor)" | cut -d ":" -f1)
    inc=1
    while [ $inc -le 6 ]
    do
      fileLine=$(expr $sectionStart + $inc)
      sed -i "${fileLine}s/^/#/" /home/admin/config.scripts/lnd.check.sh
      ((inc++))
    done
  fi
  # edit lnd.conf

  if [ "${nodetype}" = "mynode" ]; then
    # check for old lndCustomConf and copy to lndCustomConfOld if exists
    if [ -f ${lndCustomConf} ]; then
      cp -p ${lndCustomConf} ${lndCustomConfOld}
    else
      # copy lnd.conf to lndCustomConf
      cp -p ${lndconffile} ${lndCustomConf}
    fi
    # Application Options 
    sectionName="Application Options"
    publicIP="${vpnip}"
    echo "# [${sectionName}] config ..."
    sectionLine=$(cat ${lndCustomConf} | grep -n "^\[${sectionName}\]" | cut -d ":" -f1 | head -n 1)
    echo "# sectionLine(${sectionLine})"
    insertLine=$(expr $sectionLine + 1)
    echo "# insertLine(${insertLine})"
    fileLines=$(wc -l ${lndCustomConf} | cut -d " " -f1)
    echo "# fileLines(${fileLines})"
    if [ ${fileLines} -lt ${insertLine} ]; then
      echo "# adding new line for inserts"
      echo "
    " | tee -a ${lndCustomConf}
    fi
    echo "# sectionLine(${sectionLine})"
    setting ${lndCustomConf} ${insertLine} "externalip" "${publicIP}:${lnport}"
    setting ${lndCustomConf} ${insertLine} "listen" "0.0.0.0:${lnport}"
    if [ "${wireguard}" = "on" ]; then
      setting ${lndCustomConf} ${insertLine} "tlsextraip" "${wgip}"
      rm /mnt/hdd/mynode/lnd/tls*
    fi

    # tor
    sectionName="Tor"
    echo "# [${sectionName}] config ..."
    sectionLine=$(cat ${lndCustomConf} | grep -n "^\[${sectionName}\]" | cut -d ":" -f1 | head -n 1)
    echo "# sectionLine(${sectionLine})"
    insertLine=$(expr $sectionLine + 1)
    echo "# insertLine(${insertLine})"
    fileLines=$(wc -l ${lndCustomConf} | cut -d " " -f1)
    echo "# fileLines(${fileLines})"
    if [ ${fileLines} -lt ${insertLine} ]; then
      echo "# adding new line for inserts"
      echo "
    " | tee -a ${lndCustomConf}
    fi
    setting ${lndCustomConf} ${insertLine} "tor.streamisolation" "false"
    setting ${lndCustomConf} ${insertLine} "tor.skip-proxy-for-clearnet-targets" "true"
  elif [ "${nodetype}" = "raspiblitz" ]; then
    if [ -f "/mnt/hdd/raspiblitz.conf" ]; then
      source /mnt/hdd/raspiblitz.conf
    elif [ -f "/mnt/hdd/app-data/raspiblitz.conf" ]; then
      source /mnt/hdd/app-data/raspiblitz.CONF
    fi
    source <(/home/admin/config.scripts/network.aliases.sh getvars lnd)
    # Application Options 
    sectionName="Application Options"
    publicIP="${vpnip}"
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
    " | tee -a ${lndConfFile}
    fi
    echo "# sectionLine(${sectionLine})"
    setting ${lndConfFile} ${insertLine} "externalip" "${publicIP}:${lnport}"
    setting ${lndConfFile} ${insertLine} "listen" "0.0.0.0:${lnport}"

    # tor
    sectionName="tor"
    echo "# [${sectionName}] config ..."
    sectionLine=$(cat ${lndconffile} | grep -n "^\[${sectionName}\]" | cut -d ":" -f1)
    echo "# sectionLine(${sectionLine})"
    insertLine=$(expr $sectionLine + 1)
    echo "# insertLine(${insertLine})"
    fileLines=$(wc -l ${lndconffile} | cut -d " " -f1)
    echo "# fileLines(${fileLines})"
    if [ ${fileLines} -lt ${insertLine} ]; then
      echo "# adding new line for inserts"
      echo "
    " | tee -a ${lndConfFile}
    fi
    setting ${lndConfFile} ${insertLine} "tor.streamisolation" "false"
    setting ${lndConfFile} ${insertLine} "tor.skip-proxy-for-clearnet-targets" "true"
    # edit raspiblitz.conf
    raspiConfFile="/mnt/hdd/raspiblitz.conf"
    lndAddress="${vpnip}"
    publicIP="${vpnip}" 
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
    " | tee -a ${raspiConfFile}
    fi
    setting ${raspiConfFile} ${insertLine} "lndPort" "'${lnport}'"
    setting ${raspiConfFile} ${insertLine} "lndAddress" "'${lndAddress}'"
    setting ${raspiConfFile} ${insertLine} "publicIP" "'${publicIP}'"
  fi
  # restart lnd (skip this step on restore but not if webui)
  if ! [ "${isRestore}" = "1" ]; then
    systemctl restart lnd
    sleep 5
    # restart nginx
    systemctl restart nginx
    sleep 5
  fi
  if [ "${webui}" = "1" ]; then
    systemctl restart lnd
    sleep 5
    # restart nginx
    systemctl restart nginx
    sleep 5
  fi

  # set lnd-hybrid on in pleb-vpn.conf
  setting ${plebVPNConf} "2" "lndhybrid" "on"
  exit 0
}

off() {
  # disable hybrid mode

  # configure firewall
  if ! [ "${lnport}" = "9735" ]; then
    ufw delete allow ${lnport}
    if [ "${nodetype}" = "mynode" ]; then
      # remove from firewallConf
      while [ $(cat ${firewallConf} | grep -c "ufw allow ${lnport}") -gt 0 ];
      do
        sed -i "/ufw allow ${lnport}.*/d" ${firewallConf}
      done
    fi
  fi

  if [ "${nodetype}" = "mynode" ]; then
    # remove lndCustomConf
    rm ${lndCustomConf}
    # check if lndCustomConfOld exists and if so, copy back to lndCustomConf
    if [ -f ${lndCustomConfOld} ]; then
      cp -p ${lndCustomConfOld} ${lndCustomConf}
      rm ${lndCustomConfOld}
    fi
    # remove tls.cert and tls.key if wireguard is installed to pick up new tls.cert that doesn't include wireguard ip
    if [ "${wireguard}" = "on" ]; then
      rm /mnt/hdd/mynode/lnd/tls*
    fi

  elif [ "${nodetype}" = "raspiblitz" ]; then
    # fix lnd.check.sh
    sectionStart=$(cat /home/admin/config.scripts/lnd.check.sh | grep -n "\  # enforce PublicIP if (if not running Tor)" | cut -d ":" -f1)
    inc=1
    while [ $inc -le 6 ]
    do
      fileLine=$(expr $sectionStart + $inc)
      sed -i "${fileLine}s/#//" /home/admin/config.scripts/lnd.check.sh
      ((inc++))
    done
    # edit lnd.conf
    if [ -f "/mnt/hdd/raspiblitz.conf" ]; then
      source /mnt/hdd/raspiblitz.conf
    elif [ -f "/mnt/hdd/app-data/raspiblitz.conf" ]; then
      source /mnt/hdd/app-data/raspiblitz.CONF
    fi
    source <(/home/admin/config.scripts/network.aliases.sh getvars lnd)
    # Application Options 
    sed -i '/^externalip=*/d' ${lndConfFile}
    sed -i '/^listen=*/d' ${lndConfFile}
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
    " | tee -a ${lndConfFile}
    fi
    setting ${lndConfFile} ${insertLine} "tor.skip-proxy-for-clearnet-targets" "false"
    # edit raspiblitz.conf
    raspiConfFile="/mnt/hdd/raspiblitz.conf"
    sed -i '/^lndPort=*/d' ${raspiConfFile}
    sed -i '/^lndAddress=*/d' ${raspiConfFile}
    sed -i '/^publicIP=*/d' ${raspiConfFile}
  fi
  
  # restart lnd
  systemctl restart lnd
  sleep 5
  # restart nginx
  systemctl restart nginx
  sleep 5
  # set lnd-hybrid off in pleb-vpn.conf
  setting ${plebVPNConf} "2" "lndhybrid" "off"
  exit 0
}

case "${1}" in
  status) status "${2}" ;;
  on) on "${2}" "${3}" ;;
  off) off ;;
  *) echo "config script to turn LND hybrid mode on or off"; echo "lnd-hybrid.sh [status|on|off]"; exit 1 ;;
esac
