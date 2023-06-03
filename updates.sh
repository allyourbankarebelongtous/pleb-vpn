#!/bin/bash

# script for applying updates to current users
# only used for updates to installed files that are not part of the core pleb-vpn scripts
# make sure updates can be re-run multiple times
# keep updates present until most users have had the chance to update

ver="v1.1.0-alpha.4"

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
  sed -i --follow-symlinks "s:^${NAME}=.*:${NAME}=${VALUE}:g" ${FILE}
}

# only run this part for raspiblitz updates.
if [ "${nodetype}" = "raspiblitz" ]; then
  # get values for raspiblitz
  source /mnt/admin/raspiblitz.info
  source /mnt/hdd/raspiblitz.conf


  # fix nginx assets to reflect status of letsencrypt
  if [ "${letsencryptBTCPay}" = "on" ]; then
    sed -i 's/ssl-certificate-app-data.conf/ssl-certificate-app-data-letsencrypt.conf/' /home/admin/assets/nginx/sites-available/btcpay_ssl.conf
  fi
  if [ "${letsencryptLNBits}" = "on" ]; then
    sed -i 's/ssl-certificate-app-data.conf/ssl-certificate-app-data-letsencrypt.conf/' /home/admin/assets/nginx/sites-available/lnbits_ssl.conf
  fi

  # add updates to pleb-vpn on new installs
  custominstallUpdate=$(cat /mnt/hdd/app-data/custom-installs.sh | grep -c "/mnt/hdd/app-data/pleb-vpn/pleb-vpn.install.sh update")
  if [ ${custominstallUpdate} -eq 0 ]; then
    echo "# get latest pleb-vpn update
  /mnt/hdd/app-data/pleb-vpn/pleb-vpn.install.sh update
  " | tee -a /mnt/hdd/app-data/custom-installs.sh
  fi

  # change names of wireguard clients for webui
  if [ -f /mnt/hdd/app-data/pleb-vpn/wireguard/clients/desktop.conf ]; then
    mv /mnt/hdd/app-data/pleb-vpn/wireguard/clients/mobile.conf /mnt/hdd/app-data/pleb-vpn/wireguard/clients/client1.conf
    mv /mnt/hdd/app-data/pleb-vpn/wireguard/clients/laptop.conf /mnt/hdd/app-data/pleb-vpn/wireguard/clients/client2.conf
    mv /mnt/hdd/app-data/pleb-vpn/wireguard/clients/desktop.conf /mnt/hdd/app-data/pleb-vpn/wireguard/clients/client3.conf
  fi

  # change pleb-vpn.conf values to lowercase for webui
  # create new pleb-vpn.conf file
  if [ ! $(cat ${homedir}/pleb-vpn.conf | grep -c plebVPN) -eq 0 ]; then
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
    rm ${homedir}/pleb-vpn.conf
    mv ${homedir}/pleb-vpn.conf.new ${homedir}/pleb-vpn.conf
    chown admin:admin ${homedir}/pleb-vpn.conf
    chmod 755 ${homedir}/pleb-vpn.conf
  fi

  if [ $(cat /home/admin/00infoBlitz.sh | grep -c "{plebvpn}") -eq 0 ]; then
    # change pleb-vpn.conf values to lowercase on 00infoBlitz status check screen
    # remove extra lines from 00infoBlitz.sh if required
    extraLine='  # Pleb-VPN info'
    lineExists=$(cat /home/admin/00infoBlitz.sh | grep -c "${extraLine}")
    if ! [ ${lineExists} -eq 0 ]; then
      sectionLine=$(cat /home/admin/00infoBlitz.sh | grep -n "${extraLine}" | cut -d ":" -f1)
      inc=1
      while [ $inc -le 13 ]
      do
        sed -i "${sectionLine}d" /home/admin/00infoBlitz.sh
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
      source <(cat /mnt/hdd/app-data/pleb-vpn/pleb-vpn.conf | sed "1d")
      if [ "${plebvpn}" = "on" ]; then' | tee /home/admin/pleb-vpn/update.tmp
      echo -e "    currentIP=\$(host myip.opendns.com resolver1.opendns.com 2>/dev/null | awk '/has / {print \$4}') >/dev/null 2>&1" | tee -a /home/admin/pleb-vpn/update.tmp
      echo '    if [ "${currentIP}" = "${vpnip}" ]; then
      plebVPNstatus="${color_green}OK${color_gray}"
    else
      plebVPNstatus="${color_red}Down${color_gray}"
    fi
      plebVPNline="Pleb-VPN IP ${vpnip} Status ${plebVPNstatus}"
    echo -e "${plebVPNline}"
  fi
' | tee -a /home/admin/pleb-vpn/update.tmp
      edIsInstalled=$(ed --version 2>/dev/null | grep -c "GNU ed")
      if [ ${edIsInstalled} -eq 0 ]; then
        apt install -y ed
      fi
      ed -s ${infoBlitz} <<< "${insertLine}r /home/admin/pleb-vpn/update.tmp"$'\nw'
      rm /home/admin/pleb-vpn/update.tmp
    fi
  fi

  # add webui to raspiblitz
  if [ $(ls /etc/systemd/system | grep -c pleb-vpn.service) -eq 0 ]; then
    # Add webui to raspiblitz
    cd ${execdir}
    echo "installing virtualenv..."
    apt install -y virtualenv
    virtualenv -p python3 .venv
    # install requirements
    echo "installing requirements..."
    ${execdir}/.venv/bin/pip install -r ${execdir}/requirements.txt
    cd /home/admin
    # allow through firewall
    ufw allow 2420 comment 'allow Pleb-VPN HTTP'
    ufw allow 2421 commment 'allow Pleb-VPN HTTPS'
    # create pleb-vpn.service
    if [ ! -f /etc/systemd/system/pleb-vpn.service ]; then
      echo "
[Unit]
Description=Pleb-VPN guincorn app
Wants=network.target
After=network.target mnt-hdd.mount

[Service]
WorkingDirectory=/home/admin/pleb-vpn
ExecStart=/home/admin/pleb-vpn/.venv/bin/gunicorn --capture-output -k geventwebsocket.gunicorn.workers.GeventWebSocketWorker -w 1 -b 0.0.0.0:2420 main:app
User=root
Group=root
Type=simple
Restart=always
StandardOutput=append:/var/log/pleb-vpn.log
StandardError=append:/var/log/pleb-vpn.log
RestartSec=60

# Hardening
PrivateTmp=true

[Install]
WantedBy=multi-user.target" | tee "/etc/systemd/system/pleb-vpn.service"
    fi
    # enable and start systemd service
    systemctl enable pleb-vpn.service
    systemctl start pleb-vpn.service
  fi

  # add nginx service for tor and https access to pleb-vpn
  if [ ! -f /etc/nginx/sites-available/pleb-vpn_ssl.conf ]; then
    echo "## pleb-vpn_ssl.conf

server {
    listen 2421 ssl http2;
    listen [::]:2421 ssl http2;
    server_name _;

    include /etc/nginx/snippets/ssl-params.conf;
    include /etc/nginx/snippets/ssl-certificate-app-data.conf;

    include /etc/nginx/snippets/gzip-params.conf;

    access_log /var/log/nginx/access_pleb-vpn.log;
    error_log /var/log/nginx/error_pleb-vpn.log;

    location / {
        proxy_pass http://127.0.0.1:2420;

        include /etc/nginx/snippets/ssl-proxy-params.conf;

    }

    location /static/ {
        alias /home/admin/pleb-vpn/webui/static/;
        # for debug purposes, never expire
        expires off;
        # expires 30d;
    }

    location /socket.io {
        include /etc/nginx/snippets/ssl-proxy-params.conf;
        proxy_http_version 1.1;
        proxy_buffering off;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \"Upgrade\";
        proxy_pass http://127.0.0.1:2420/socket.io;
    }

}
" | tee /etc/nginx/sites-available/pleb-vpn_ssl.conf

    echo "## pleb-vpn_tor.conf

server {
    listen 2422;
    server_name _;

    include /etc/nginx/snippets/gzip-params.conf;

    access_log /var/log/nginx/access_pleb-vpn.log;
    error_log /var/log/nginx/error_pleb-vpn.log;

    location / {
        proxy_pass http://127.0.0.1:2420;

        include /etc/nginx/snippets/ssl-proxy-params.conf;

    }

    location /static/ {
        alias /home/admin/pleb-vpn/webui/static/;
        # for debug purposes, never expire
        expires off;
        # expires 30d;
    }

    location /socket.io {
        include /etc/nginx/snippets/ssl-proxy-params.conf;
        proxy_http_version 1.1;
        proxy_buffering off;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \"Upgrade\";
        proxy_pass http://127.0.0.1:2420/socket.io;
    }

}
" | tee /etc/nginx/sites-available/pleb-vpn_tor.conf

    echo "## pleb-vpn_tor_ssl.conf

server {
    listen 2423 ssl http2;
    server_name _;

    include /etc/nginx/snippets/ssl-params.conf;
    include /etc/nginx/snippets/ssl-certificate-app-data.conf;

    include /etc/nginx/snippets/gzip-params.conf;

    access_log /var/log/nginx/access_pleb-vpn.log;
    error_log /var/log/nginx/error_pleb-vpn.log;

    location / {
        proxy_pass http://127.0.0.1:2420;

        include /etc/nginx/snippets/ssl-proxy-params.conf;

    }

    location /static/ {
        alias /home/admin/pleb-vpn/webui/static/;
        # for debug purposes, never expire
        expires off;
        # expires 30d;
    }

    location /socket.io {
        include /etc/nginx/snippets/ssl-proxy-params.conf;
        proxy_http_version 1.1;
        proxy_buffering off;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \"Upgrade\";
        proxy_pass http://127.0.0.1:2420/socket.io;
    }

}
" | tee /etc/nginx/sites-available/pleb-vpn_tor_ssl.conf

    # symlink to sites-enabled
    ln -s /etc/nginx/sites-available/pleb-vpn_ssl.conf /etc/nginx/sites-enabled/pleb-vpn_ssl.conf
    ln -s /etc/nginx/sites-available/pleb-vpn_tor.conf /etc/nginx/sites-enabled/pleb-vpn_tor.conf      
    ln -s /etc/nginx/sites-available/pleb-vpn_tor_ssl.conf /etc/nginx/sites-enabled/pleb-vpn_tor_ssl.conf

    # test and reload nginx
    nginx -t
    if [ $? -eq 0 ]; then
      echo "nginx config good"
      systemctl reload nginx
    else
      echo "Error: nginx test config fail"
      exit 1
    fi

    # get tor address for Pleb-VPN if tor is active
    if [ "${runBehindTor}" = "on" ]; then
      # make sure to keep in sync with tor.network.sh script
      /home/admin/config.scripts/tor.onion-service.sh pleb-vpn 80 2422 443 2423
    fi
  fi

  # remove git attributes from pleb-vpn folders if present (updates now done via releases)
  if [ -d /home/admin/pleb-vpn/.git ]; then
    rm -rf /home/admin/pleb-vpn/.git
    rm -rf /mnt/hdd/app-data/pleb-vpn/.git
  fi

fi

# update version
setting ${plebVPNConf} "2" "version" "'${ver}'"
