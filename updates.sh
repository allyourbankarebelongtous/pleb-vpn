#!/bin/bash

# script for applying updates to current users
# only used for updates to installed files that are not part of the core pleb-vpn scripts
# make sure updates can be re-run multiple times
# keep updates present until most users have had the chance to update

ver="v1.1.0betaRC1"

# get node info# find home directory based on node implementation
if [ -d "/mnt/hdd/mynode/pleb-vpn/" ]; then
  homedir="/mnt/hdd/mynode/pleb-vpn"
  execdir="/opt/mynode/pleb-vpn"
  nodetype="mynode"
elif [ -f "/mnt/hdd/raspiblitz.conf" ]; then
  homedir="/mnt/hdd/app-data/pleb-vpn"
  execdir="/home/admin/pleb-vpn"
  nodetype="raspiblitz"
fi
plebVPNConf="${homedir}/pleb-vpn.conf"
plebVPNTempConf="${homedir}/pleb-vpn.conf.tmp"
sed '1d' $plebVPNConf > $plebVPNTempConf
source ${plebVPNTempConf}
sudo rm ${plebVPNTempConf}

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

# only run this part for raspiblitz updates.
if [ "${nodetype}" = "raspiblitz" ]; then

  # fix nginx assets to reflect status of letsencrypt
  if [ "${letsencryptBTCPay}" = "on" ]; then
    sudo sed -i 's/ssl-certificate-app-data.conf/ssl-certificate-app-data-letsencrypt.conf/' /home/admin/assets/nginx/sites-available/btcpay_ssl.conf
  fi
  if [ "${letsencryptLNBits}" = "on" ]; then
    sudo sed -i 's/ssl-certificate-app-data.conf/ssl-certificate-app-data-letsencrypt.conf/' /home/admin/assets/nginx/sites-available/lnbits_ssl.conf
  fi

  # add updates to pleb-vpn on new installs
  custominstallUpdate=$(cat /mnt/hdd/app-data/custom-installs.sh | grep -c "/mnt/hdd/app-data/pleb-vpn/pleb-vpn.install.sh update")
  if [ ${custominstallUpdate} -eq 0 ]; then
    echo "# get latest pleb-vpn update
  /mnt/hdd/app-data/pleb-vpn/pleb-vpn.install.sh update
  " | sudo tee -a /mnt/hdd/app-data/custom-installs.sh
  fi

  # change pleb-vpn.conf values to lowercase for webui
  # create new pleb-vpn.conf file
  if [ ! $(cat ${homedr}/pleb-vpn.conf | grep -c plebVPN) -eq 0 ]; then
    echo "[PLEBVPN]
version=
latestversion=
nodetype=
lan=
plebvpn=off
vpnip=
vpnport=
lndhybrid=off
lnport=
clnhybrid=off
clnport=
wireguard=off
wgip=
wglan=
wgport=
letsencrypt_ssl=off
letsencryptlnbits=off
letsencryptbtcpay=off
letsencryptdomain1=
letsencryptdomain2=
torsplittunnel=off
clnconffile=
lndconffile=







"| tee ${homedir}/pleb-vpn.conf.new

    # update new conf file with values from old conf file
    newConf="${homedir}/pleb-vpn.conf.new"
    setting ${newConf} "2" "nodetype" "'${nodetype}'"
    setting ${newConf} "2" "latestversion" "'${ver}'"
    source ${homedir}/pleb-vpn.conf
    if [ -z "${LAN}" ]; then
      LAN=""
    fi
    setting ${newConf} "2" "lan" "'${LAN}'"
    if [ -z "${plebVPN}" ]; then
      plebVPN="off"
    fi
    setting ${newConf} "2" "plebvpn" "${plebVPN}"
    if [ -z "${vpnIP}" ]; then
      vpnIP=""
    fi
    setting ${newConf} "2" "vpnip" "'${vpnIP}'"
    if [ -z "${vpnPort}" ]; then
      vpnPort=""
    fi
    setting ${newConf} "2" "vpnport" "'${vpnPort}'"
    if [ -z "${lndHybrid}" ]; then
      lndHybrid="off"
    fi
    setting ${newConf} "2" "lndhybrid" "${lndHybrid}"
    if [ -z "${lnPort}" ]; then
      lnPort=""
    fi
    setting ${newConf} "2" "lnport" "'${lnPort}'"
    if [ -z "${clnHybrid}" ]; then
      clnHybrid="off"
    fi
    setting ${newConf} "2" "clnhybrid" "${clnHybrid}"
    if [ -z "${CLNPort}" ]; then
      CLNPort=""
    fi
    setting ${newConf} "2" "clnport" "'${CLNPort}'"
    if [ -z "${wireguard}" ]; then
      wireguard="off"
    fi
    setting ${newConf} "2" "wireguard" "${wireguard}"
    if [ -z "${wgIP}" ]; then
      wgIP=""
    fi
    setting ${newConf} "2" "wgip" "'${wgIP}'"
    if [ -z "${wgLAN}" ]; then
      wgLAN=""
    fi
    setting ${newConf} "2" "wglan" "'${wgLAN}'"
    if [ -z "${wgPort}" ]; then
      wgPort=""
    fi
    setting ${newConf} "2" "wgport" "'${wgPort}'"
    if [ -z "${letsencrypt_ssl}" ]; then
      letsencrypt_ssl="off"
    fi
    setting ${newConf} "2" "letsencrypt_ssl" "${letsencrypt_ssl}"
    if [ -z "${letsencryptLNBits}" ]; then
      letsencryptLNBits="off"
    fi
    setting ${newConf} "2" "letsencryptlnbits" "${letsencryptLNBits}"
    if [ -z "${letsencryptBTCPay}" ]; then
      letsencryptBTCPay="off"
    fi
    setting ${newConf} "2" "letsencryptbtcpay" "${letsencryptBTCPay}"
    if [ -z "${letsencryptDomain1}" ]; then
      letsencryptDomain1=""
    fi
    setting ${newConf} "2" "letsencryptdomain1" "'${letsencryptDomain1}'"
    if [ -z "${letsencryptDomain2}" ]; then
      letsencryptDomain2=""
    fi
    setting ${newConf} "2" "letsencryptdomain2" "'${letsencryptDomain2}'"
    if [ -z "${torSplitTunnel}" ]; then
      torSplitTunnel="off"
    fi
    setting ${newConf} "2" "torsplittunnel" "${torSplitTunnel}"
    if [ -z "${CLNConfFile}" ]; then
      CLNConfFile=""
    fi
    setting ${newConf} "2" "clnconffile" "'${CLNConfFile}'"
    if [ -z "${LndConfFile}" ]; then
      LndConfFile=""
    fi
    setting ${newConf} "2" "lndconffile" "'${LndConfFile}'"
    # remove old pleb-vpn.conf and replace with new file
    sudo rm ${homedir}/pleb-vpn.conf
    sudo mv ${homedir}/pleb-vpn.conf.new ${homedir}/pleb-vpn.conf

    # change pleb-vpn.conf values to lowercase on 00infoBlitz status check screen
    # remove extra lines from 00infoBlitz.sh if required
    extraLine='  # Pleb-VPN info'
    lineExists=$(sudo cat /home/admin/00infoBlitz.sh | grep -c "${extraLine}")
    if ! [ ${lineExists} -eq 0 ]; then
      sectionLine=$(sudo cat /home/admin/00infoBlitz.sh | grep -n "${extraLine}" | cut -d ":" -f1)
      inc=1
      while [ $inc -le 13 ]
      do
        sudo sed -i "${sectionLine}d" /home/admin/00infoBlitz.sh
        ((inc++))
      done
    fi
    # change 00infoBlitz.sh to match new pleb-vpn values
    infoBlitz="/home/admin/00infoBlitz.sh"
    infoBlitzUpdated=$(cat ${infoBlitz} | grep -c '  # Pleb-VPN info')
    if [ ${infoBlitzUpdated} -eq 0 ]; then
      sectionName='    echo "${appInfoLine}"'
      sectionLine=$(cat ${infoBlitz} | grep -n "^${sectionName}" | cut -d ":" -f1)
      insertLine=$(expr $sectionLine + 2)
      echo '  # Pleb-VPN info
      source /home/admin/pleb-vpn/pleb-vpn.conf
      if [ "${plebvpn}" = "on" ]; then' | sudo tee /home/admin/pleb-vpn/update.tmp
      echo -e "    currentIP=\$(host myip.opendns.com resolver1.opendns.com 2>/dev/null | awk '/has / {print \$4}') >/dev/null 2>&1" | sudo tee -a /home/admin/pleb-vpn/update.tmp
      echo '    if [ "${currentIP}" = "${vpnip}" ]; then
      plebVPNstatus="${color_green}OK${color_gray}"
    else
      plebVPNstatus="${color_red}Down${color_gray}"
    fi
      plebVPNline="Pleb-VPN IP ${vpnip} Status ${plebVPNstatus}"
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

    # Add webui to raspiblitz
    cd ${execdir}
    echo "installing virtualenv..."
    sudo apt install -y virtualenv
    sudo virtualenv -p python3 .venv
    # install requirements
    echo "installing requirements..."
    sudo ${execdir}/.venv/bin/pip install -r ${execdir}/requirements.txt
    cd /home/admin
    # allow through firewall
    sudo ufw allow 2420 comment 'allow Pleb-VPN HTTP'
    # create pleb-vpn.service
    if [ ! -f /etc/systemd/system/pleb-vpn.service ]; then
      echo "
[Unit]
Description=Pleb-VPN guincorn app
Wants=network.target
After=network.target mnt-hdd.mount

[Service]
WorkingDirectory=/home/admin/pleb-vpn
ExecStart=/home/admin/pleb-vpn/.venv/bin/gunicorn -k geventwebsocket.gunicorn.workers.GeventWebSocketWorker -w 1 -b 0.0.0.0:2420 main:app
User=admin
Group=admin
Type=simple
Restart=always
StandardOutput=journal
StandardError=journal
RestartSec=60

# Hardening
PrivateTmp=true

[Install]
WantedBy=multi-user.target" | sudo tee "/etc/systemd/system/pleb-vpn.service"
    fi
    # enable and start systemd service
    sudo systemctl enable pleb-vpn.service
    sudo systemctl start pleb-vpn.service
  fi
fi

# update version
setting ${plebVPNConf} "2" "version" "'${ver}'"
