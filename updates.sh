#!/bin/bash

# script for applying updates to current users
# only used for updates to installed files that are not part of the core pleb-vpn scripts
# make sure updates can be re-run multiple times
# keep updates present until most users have had the chance to update

# updates pleb-vpn.conf to change letsencrypt value to letsencrypt_ssl to avoid conflicts with raspiblitz.conf
plebVPNConf="/mnt/hdd/app-data/pleb-vpn/pleb-vpn.conf"

# change letsencrypt= to letsencrypt_ssl=
sudo sed -i 's/.*letsencrypt=/letsencrypt_ssl=/g' ${plebVPNConf}
# change # letsencrypt to # letsencrypt_ssl
sectionLine=$(cat ${plebVPNConf} | grep -n "# lndHybrid" | cut -d ":" -f1)
# make sure sectionLine returned a value before continuing
if [ ! "${sectionLine}" = "" ]; then
  insertLine=$(expr $sectionLine + 1)
  sudo sed -i "${insertLine}d" ${plebVPNConf}
  line="# letsencrypt_ssl"
  sudo sed -i "${insertLine}i${line}" ${plebVPNConf}
fi

# fix nginx assets to reflect status of letsencrypt
source /mnt/hdd/app-data/pleb-vpn/pleb-vpn.conf
if [ "${letsencryptBTCPay}" = "on" ]; then
  sudo sed -i 's/ssl-certificate-app-data.conf/ssl-certificate-app-data-letsencrypt.conf/' /home/admin/assets/nginx/sites-available/btcpay_ssl.conf
fi
if [ "${letsencryptLNBits}" = "on" ]; then
  sudo sed -i 's/ssl-certificate-app-data.conf/ssl-certificate-app-data-letsencrypt.conf/' /home/admin/assets/nginx/sites-available/lnbits_ssl.conf
fi
