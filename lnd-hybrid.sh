#!/bin/bash

# turn LND node hybrid mode on or off
# example: "lnd-hybrid.sh on"

# command info
if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "-help" ]; then
  echo "config script to turn LND hybrid mode on or off"
  echo "lnd-hybrid.sh [status|on|off]"
  exit 1
fi

plebVPNConf="/mnt/hdd/mynode/pleb-vpn/pleb-vpn.conf"
lndConfFile="/mnt/hdd/mynode/lnd/lnd.conf"
lndCustomConf="/mnt/hdd/mynode/settings/lnd_custom.conf"
lndCustomConfOld="/mnt/hdd/mynode/settings/lnd_custom_old.conf"

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
    if [ "${FILE}" = "${lndConfFile}" ]; then
      sudo -u bitcoin sed -i --follow-symlinks "${LINENUMBER}i${NAME}=" ${FILE}
    else
      sudo sed -i --follow-symlinks "${LINENUMBER}i${NAME}=" ${FILE}
    fi
  fi
  echo "# updating setting (${NAME}) with value(${VALUE})"
  if [ "${FILE}" = "${lndConfFile}" ]; then
    sudo -u bitcoin sed -i --follow-symlinks "s/^${NAME}=.*/${NAME}=${VALUE}/g" ${FILE}
  else
    sudo sed -i --follow-symlinks "s/^${NAME}=.*/${NAME}=${VALUE}/g" ${FILE}
  fi
}

status() {
  source ${plebVPNConf}
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
  if [ "${lndHybrid}" = "on" ]; then
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
    echo "Alias='${nodeName}'
Node_ID='${nodeID}'
address0='${address0}'
address1='${address1}'
address0Type='${address0Type}'
address1Type='${address1Type}'" | tee /mnt/hdd/mynode/pleb-vpn/lnd_hybrid_status.tmp
    exit 0 
  else
    echo "Alias='${nodeName}'
Node_ID='${nodeID}'
address0='${address0}'
address0Type='${address0Type}'" | tee /mnt/hdd/mynode/pleb-vpn/lnd_hybrid_status.tmp
    exit 0
  fi
}

on() {
  # enable hybrid mode 
  source ${plebVPNConf}

  local isRestore="${1}"
  local newlnPort="${2}"
  echo "New Ln Port: ${newlnPort}"

  # check if plebvpn is on
  if ! [ "${plebVPN}" = "on" ]; then
    echo "error: turn on plebvpn before enabling hybrid mode"
    exit 1
  fi
  # check if LND node is availabe
  lnd_isOn=$(systemctl status lnd | grep Active | cut -d ":" -f2 | cut -d " " -f2)
  if ! [ "${lnd_isOn}" = "active" ]; then
    echo "error: no LND node found"
    exit 1
  fi 
  # get LND port
  # check to see if new lnd port passed as argument
  if [ ! -z "${newlnPort}" ]; then
    lnPort="${newlnPort}"
    setting ${plebVPNConf} "2" "lnPort" "'${newlnPort}'"
  fi
  if [ ! -z "${lnPort}" ]; then
    # skip if restoring
    if [ ! "${isRestore}" = "1" ]; then
      echo "error: need a port to enable hybrid mode"
      exit 1
    else
      keepport="1"
    fi
  else
    keepport="0"
  fi
  if [ "${keepport}" = "0" ]; then
    echo "error: need a port to enable hybrid mode"
    exit 1
  fi

  # configure firewall
  if ! [ "${lnPort}" = "9735" ]; then
    sudo ufw allow ${lnPort} comment "LND Port"
  fi

  # edit lnd.conf
  # check for old lndCustomConf and copy to lndCustomConfOld if exists
  if [ -f ${lndCustomConf} ]; then
    sudo cp -p ${lndCustomConf} ${lndCustomConfOld}
  fi
  # copy lnd.conf to lndCustomConf
  sudo cp -p ${lndConfFile} ${lndCustomConf}
  # Application Options 
  sectionName="Application Options"
  publicIP="${vpnIP}"
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
  " | sudo tee -a ${lndCustomConf}
  fi
  echo "# sectionLine(${sectionLine})"
  setting ${lndCustomConf} ${insertLine} "externalip" "${publicIP}:${lnPort}"
  setting ${lndCustomConf} ${insertLine} "listen" "0.0.0.0:${lnPort}"

  # tor
  sectionName="tor"
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
  " | sudo tee -a ${lndCustomConf}
  fi
  setting ${lndCustomConf} ${insertLine} "tor.streamisolation" "false"
  setting ${lndCustomConf} ${insertLine} "tor.skip-proxy-for-clearnet-targets" "true"

  # restart lnd
  sudo systemctl restart lnd 

  # set lnd-hybrid on in pleb-vpn.conf
  setting ${plebVPNConf} "2" "lndHybrid" "on"
  exit 0
}

off() {
  # disable hybrid mode 
  source ${plebVPNConf}

  # configure firewall
  if ! [ "${lnPort}" = "9735" ]; then
    sudo ufw delete allow ${lnPort}
  fi

  # remove lndCustomConf
  sudo rm ${lndCustomConf}
  # check if lndCustomConfOld exists and if so, copy back to lndCustomConf
  if [ -f ${lndCustomConfOld} ]; then
    sudo cp -p ${lndCustomConfOld} ${lndCustomConf}
    sudo rm ${lndCustomConfOld}
  fi
  # # Application Options 
  # sudo sed -i '/^externalip=*/d' ${lndConfFile}
  # sudo sed -i '/^tor.skip-proxy-for-clearnet-targets=*/d' ${lndConfFile}
  # sectionName="Application Options"
  # echo "# [${sectionName}] config ..."
  # sectionLine=$(cat ${lndConfFile} | grep -n "^\[${sectionName}\]" | cut -d ":" -f1 | head -n 1)
  # echo "# sectionLine(${sectionLine})"
  # insertLine=$(expr $sectionLine + 1)
  # echo "# insertLine(${insertLine})"
  # fileLines=$(wc -l ${lndConfFile} | cut -d " " -f1)
  # echo "# fileLines(${fileLines})"
  # if [ ${fileLines} -lt ${insertLine} ]; then
    # echo "# adding new line for inserts"
    # echo "
  # " | sudo tee -a ${lndConfFile}
  # fi
  # echo "# sectionLine(${sectionLine})"
  # setting ${lndConfFile} ${insertLine} "listen" "localhost"
  # # tor
  # sectionName="tor"
  # echo "# [${sectionName}] config ..."
  # sectionLine=$(cat ${lndConfFile} | grep -n "^\[${sectionName}\]" | cut -d ":" -f1 | head -n 1)
  # echo "# sectionLine(${sectionLine})"
  # insertLine=$(expr $sectionLine + 1)
  # echo "# insertLine(${insertLine})"
  # fileLines=$(wc -l ${lndConfFile} | cut -d " " -f1)
  # echo "# fileLines(${fileLines})"
  # if [ ${fileLines} -lt ${insertLine} ]; then
    # echo "# adding new line for inserts"
    # echo "
  # " | sudo tee -a ${lndConfFile}
  # fi
  # setting ${lndConfFile} ${insertLine} "tor.streamisolation" "true"

  # restart lnd
  sudo systemctl restart lnd 
  # set lnd-hybrid off in pleb-vpn.conf
  setting ${plebVPNConf} "2" "lndHybrid" "off"
  exit 0
}

case "${1}" in
  status) status ;;
  on) on "${2}" "${3}" ;;
  off) off ;;
  *) echo "err=Unknown action: ${1}" ; exit 1 ;;
esac
