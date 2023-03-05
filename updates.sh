#!/bin/bash

# script for applying updates to current users
# only used for updates to installed files that are not part of the core pleb-vpn scripts
# make sure updates can be re-run multiple times
# keep updates present until most users have had the chance to update

# updates pleb-vpn.conf to change letsencrypt value to letsencrypt_ssl to avoid conflicts with raspiblitz.conf
plebVPNConf="/mnt/hdd/app-data/pleb-vpn/pleb-vpn.conf"
ver="1.0beta"

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

# change letsencrypt= to letsencrypt_ssl=
sudo sed -i 's/.*letsencrypt=/letsencrypt_ssl=/g' ${plebVPNConf}

# fix Available values
sectionLine=$(cat ${plebVPNConf} | grep -n "# Available values #" | cut -d ":" -f1)
insertLine=$(expr $sectionLine + 2)
fileLines=$(wc -l ${plebVPNConf} | cut -d " " -f1)
sudo sed -i "${insertLine},${fileLines}d" ${plebVPNConf}
echo "# vpnIP
# vpnPort
# wgLAN
# wgIP
# wgPort
# CLNPort
# lnPort
# wireguard
# clnHybrid
# lndHybrid
# letsencrypt_ssl
# letsencryptBTCPay
# letsencryptLNBits
# letsencryptDomain1
# letsencryptDomain2
# version
# CLNConfFile
# lndConfFile
# LAN
# plebVPN" | sudo tee -a ${plebVPNConf}

# fix nginx assets to reflect status of letsencrypt
source ${plebVPNConf}
if [ "${letsencryptBTCPay}" = "on" ]; then
  sudo sed -i 's/ssl-certificate-app-data.conf/ssl-certificate-app-data-letsencrypt.conf/' /home/admin/assets/nginx/sites-available/btcpay_ssl.conf
fi
if [ "${letsencryptLNBits}" = "on" ]; then
  sudo sed -i 's/ssl-certificate-app-data.conf/ssl-certificate-app-data-letsencrypt.conf/' /home/admin/assets/nginx/sites-available/lnbits_ssl.conf
fi

# add version number to pleb-vpn.conf and pause when updating while displaying current version
setting ${plebVPNConf} "2" "version" "'${ver}'"

# add pleb-vpn to 00infoBlitz.sh for status check
infoBlitz="/home/admin/00infoBlitz.sh"
infoBlitzUpdated=$(cat ${infoBlitz} | grep -c '  # Pleb-VPN info')
if [ ${infoBlitzUpdated} -eq 0 ]; then
  sectionName='    echo "${appInfoLine}"'
  sectionLine=$(cat ${infoBlitz} | grep -n "^${sectionName}" | cut -d ":" -f1)
  insertLine=$(expr $sectionLine + 2)
  echo '  # Pleb-VPN info
  source /home/admin/pleb-vpn/pleb-vpn.conf
  if [ "${plebVPN}" = "on" ]; then' | sudo tee /home/admin/pleb-vpn/update.tmp
  echo -e "    currentIP=\$(host myip.opendns.com resolver1.opendns.com 2>/dev/null | awk '/has / {print \$4}') >/dev/null 2>&1" | sudo tee -a /home/admin/pleb-vpn/update.tmp
  echo '    if [ "${currentIP}" = "${vpnIP}" ]; then
      plebVPNstatus="${color_green}OK${color_gray}"
    else
      plebVPNstatus="${color_red}Down${color_gray}"
    fi
      plebVPNline="Pleb-VPN IP ${vpnIP} Status ${plebVPNstatus}"
    echo -e "${plebVPNline}"
  fi
' | sudo tee -a /home/admin/pleb-vpn/update.tmp
  edIsInstalled=$(ed --version 2>/dev/null | grep -c "GNU ed")
  if [ ${edIsInstalled} -eq 0 ]; then
    sudo apt install -y ed
  fi
  ed -s ${infoBlitz} <<< "${insertLine}r /home/admin/pleb-vpn/update.tmp"$'\nw'
  sudo rm /home/admin/pleb-vpn/update.tmp
fi

# add updates to pleb-vpn on new installs
custominstallUpdate=$(cat /mnt/hdd/app-data/custom-installs.sh | grep -c "/mnt/hdd/app-data/pleb-vpn/pleb-vpn.install.sh update")
if [ ${custominstallUpdate} -eq 0 ]; then
  echo "# get latest pleb-vpn update
/mnt/hdd/app-data/pleb-vpn/pleb-vpn.install.sh update
" | sudo tee -a /mnt/hdd/app-data/custom-installs.sh
fi