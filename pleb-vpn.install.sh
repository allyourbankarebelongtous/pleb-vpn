#!/bin/bash

# initial install script for pleb-vpn
# used for installing or uninstalling pleb-vpn on raspiblitz
# establishes system configuration backups using pleb-vpn.backup.sh and restores on uninstall
# sets initial values in pleb-vpn.conf, including LAN, lndConfFile, CLNConfFile

ver="v1.1.0-alpha.3" 

if [ -d "/mnt/hdd/mynode" ]; then
  nodetype="mynode"
  homedir="/mnt/hdd/mynode/pleb-vpn"
  execdir="/opt/mynode/pleb-vpn"
  firewallConf="/usr/bin/mynode_firewall.sh"
elif [ -f "/mnt/hdd/raspiblitz.conf" ]; then
  nodetype="raspiblitz"
  homedir="/mnt/hdd/app-data/pleb-vpn"
  execdir="/home/admin/pleb-vpn"
fi

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
  if [[ ${VALUE} == *":"* ]]; then
    sed -i --follow-symlinks "s/^${NAME}=.*/${NAME}=${VALUE}/g" ${FILE}
  else
    sed -i --follow-symlinks "s:^${NAME}=.*:${NAME}=${VALUE}:g" ${FILE}
  fi
}

on() 
{
  # only for new install

  # check if sudo
  if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (with sudo)"
    exit 1
  fi
  # wget tar.gz from github and put in execdir
  if [ "${nodetype}" = "raspiblitz" ]; then
    cd /home/admin
    mkdir /home/admin/pleb-vpn-tmp
    cd /home/admin/pleb-vpn-tmp
    wget https://github.com/allyourbankarebelongtous/pleb-vpn/archive/refs/tags/${ver}.tar.gz
    tar -xzf ${ver}.tar.gz
    cd pleb-vpn-*
    isSuccess=$(ls | grep -c plebvpn_common)
    if [ ${isSuccess} -eq 0 ]; then
      echo "error: download and unzip failed. Check internet connection and version number and try again."
      rm -rf /home/admin/pleb-vpn-tmp
      exit 1
    else
      rm -rf /home/admin/pleb-vpn-tmp/pleb-vpn/${ver}.tar.gz
      mkdir ${execdir}
      cp -p -r . ${execdir}
      rm -rf /home/admin/pleb-vpn-tmp
    fi
  elif [ "${nodetype}" = "mynode" ]; then
    if [ ! -d ${execdir}/plebvpn_common ]; then
      if [ -d ${execdir}/pleb-vpn/plebvpn_common ]; then
        cp -p -r ${execdir}/pleb-vpn /opt/mynode/
        rm -rf ${execdir}/pleb-vpn
      else
        cd /home/admin
        mkdir /home/admin/pleb-vpn-tmp
        cd /home/admin/pleb-vpn-tmp
        wget https://github.com/allyourbankarebelongtous/pleb-vpn/archive/refs/tags/${ver}.tar.gz
        tar -xzf ${ver}.tar.gz
        cd pleb-vpn-*
        isSuccess=$(ls | grep -c plebvpn_common)
        if [ ${isSuccess} -eq 0 ]; then
          echo "error: download and unzip failed. Check internet connection and version number and try again."
          rm -rf /home/admin/pleb-vpn-tmp
          exit 1
        else
          rm -rf /home/admin/pleb-vpn-tmp/pleb-vpn/${ver}.tar.gz
          mkdir ${execdir}
          cp -p -r . ${execdir}
          rm -rf /home/admin/pleb-vpn-tmp
        fi
      fi
    fi
  fi
  chown -R admin:admin ${execdir}
  chmod -R 755 ${execdir}

  # check for, and if present, remove updates.sh and update_requirements.txt
  isUpdateScript=$(ls ${execdir} | grep -c updates.sh)
  if [ ${isUpdateScript} -eq 1 ]; then
    # only used for updates, not new installs, so remove
    rm ${execdir}/updates.sh
  fi
  isUpdateReqs=$(ls ${execdir} | grep -c update_requirements.txt)
  if [ ${isUpdateReqs} -eq 1 ]; then
    # only used for updates, not new installs, so remove
    rm ${execdir}/update_requirements.txt
  fi

  # make payments directory and copy files to hard drive
  mkdir ${execdir}/payments/keysends
  if [ "${nodetype}" = "raspiblitz" ]; then
    # copy the files to /mnt/hdd/app-data/pleb-vpn
    cp -p -r ${execdir} /mnt/hdd/app-data/
    # fix permissions
    chown -R admin:admin ${homedir}
    chmod -R 755 ${homedir}
  elif [ "${nodetype}" = "mynode" ]; then
    # copy the files to /mnt/hdd/mynode/pleb-vpn
    cp -p -r ${execdir} /mnt/hdd/mynode/
    # fix permissions
    chown -R admin:admin ${homedir}
    chmod -R 755 ${homedir}
  fi
  # create and symlink pleb-vpn.conf
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







"| tee ${homedir}/pleb-vpn.conf

  # symlink pleb-vpn.conf
  ln -sf ${homedir}/pleb-vpn.conf ${execdir}/pleb-vpn.conf
  if [ "${nodetype}" = "raspiblitz" ]; then
    # backup critical files and configs
    ${execdir}/pleb-vpn.backup.sh backup
  fi

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
" > ${execdir}/payments/${freq}${node}payments.sh
    ((inc++))
  done
  cp -p ${execdir}/payments/*lndpayments.sh ${homedir}/payments/
  cp -p ${execdir}/payments/*clnpayments.sh ${homedir}/payments/
  # fix permissions
  chown -R admin:admin ${homedir}
  chmod -R 755 ${homedir}
  # fix permissions
  chown -R admin:admin ${execdir}
  chmod -R 755 ${execdir}
  # initialize pleb-vpn.conf
  plebVPNConf="${homedir}/pleb-vpn.conf"
  # get initial values
  if [ "${nodetype}" = "raspiblitz" ]; then
    source <(/home/admin/_cache.sh get internet_localip)
    source <(/home/admin/config.scripts/network.aliases.sh getvars cl)
    source <(/home/admin/config.scripts/network.aliases.sh getvars lnd)
  fi
  if [ "${nodetype}" = "mynode" ]; then
    internet_localip=$(hostname -I | awk '{print $1}')
    lndConfFile="/mnt/hdd/mynode/lnd/lnd.conf"
    CLCONF=""
  fi
  LAN=$(echo "${internet_localip}" | sed 's/^\(.*\)\.\(.*\)\.\(.*\)\.\(.*\)$/\1\.\2\.\3/g')
  setting ${plebVPNConf} "2" "lndconffile" "'${lndConfFile}'"
  setting ${plebVPNConf} "2" "clnconffile" "'${CLCONF}'"
  setting ${plebVPNConf} "2" "lan" "'${LAN}'"
  setting ${plebVPNConf} "2" "version" "'${ver}'"
  setting ${plebVPNConf} "2" "latestversion" "'${ver}'"
  setting ${plebVPNConf} "2" "nodetype" "'${nodetype}'"

  # for raspiblitz ssh menu install
  if [ "${nodetype}" = "raspiblitz" ]; then 

    # make persistant with custom-installs.sh
    isPersistant=$(cat /mnt/hdd/app-data/custom-installs.sh | grep -c /mnt/hdd/app-data/pleb-vpn/pleb-vpn.install.sh)
    if [ ${isPersistant} -eq 0 ]; then
      echo "
# pleb-vpn restore
/mnt/hdd/app-data/pleb-vpn/pleb-vpn.install.sh restore
# get latest pleb-vpn update
/mnt/hdd/app-data/pleb-vpn/pleb-vpn.install.sh update 1
" | tee -a /mnt/hdd/app-data/custom-installs.sh
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
    sed -i "${insertLine}i${Line}" ${mainMenu}
    sectionName="/home/admin/99connectMenu.sh"
    sectionLine=$(cat ${mainMenu} | grep -n "${sectionName}" | cut -d ":" -f1)
    echo "# sectionLine(${sectionLine})"
    insertLine=$(expr $sectionLine + 2)
    echo "# insertLine(${insertLine})"
    Line='PLEB-VPN)'
    sed -i "${insertLine}i        ${Line}" ${mainMenu}
    insertLine=$(expr $sectionLine + 3)
    Line='/home/admin/pleb-vpn/pleb-vpnMenu.sh'
    sed -i "${insertLine}i            ${Line}" ${mainMenu}
    insertLine=$(expr $sectionLine + 4)
    Line=';;'
    sed -i "${insertLine}i            ${Line}" ${mainMenu}

    # add pleb-vpn to 00infoBlitz.sh for status check
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

  # install webui
  cd ${execdir}
  echo "installing virtualenv..."
  apt install -y virtualenv
  virtualenv -p python3 .venv
  # install requirements
  echo "installing requirements..."
  ${execdir}/.venv/bin/pip install -r ${execdir}/requirements.txt

  # allow through firewall
  if [ "${nodetype}" = "raspiblitz" ]; then
    ufw allow 2420 comment 'allow Pleb-VPN HTTP'
    ufw allow 2421 commment 'allow Pleb-VPN HTTPS'
  fi
  if [ "${nodetype}" = "mynode" ]; then
    # if installed from install script and not from mynode app store, allow through firewall to persist on restarts
    if [ $(ls /usr/share/mynode_apps | grep -c pleb-vpn) -eq 0 ]; then
      ufw allow 2420 comment 'allow Pleb-VPN HTTP'
      ufw allow 2421 commment 'allow Pleb-VPN HTTPS'
      # add new rules to firewallConf
      sectionLine=$(cat ${firewallConf} | grep -n "^\# Add firewall rules" | cut -d ":" -f1 | head -n 1)
      insertLine=$(expr $sectionLine + 1)
      sed -i "${insertLine}iufw allow 2420 comment 'allow Pleb-VPN HTTP'" ${firewallConf}
      sed -i "${insertLine}iufw allow 2421 comment 'allow Pleb-VPN HTTPS'" ${firewallConf}
    fi
  fi

  # create systemd service
  echo "Install pleb-vpn.service file for pleb-vpn application server"
  if [ "${nodetype}" = "raspiblitz" ]; then
    echo "
[Unit]
Description=Pleb-VPN guincorn app
Wants=network.target
After=network.target mnt-hdd.mount

[Service]
WorkingDirectory=/home/admin/pleb-vpn
ExecStart=/home/admin/pleb-vpn/.venv/bin/gunicorn -k geventwebsocket.gunicorn.workers.GeventWebSocketWorker -w 1 -b 0.0.0.0:2420 main:app
User=root
Group=root
Type=simple
Restart=always
StandardOutput=journal
StandardError=journal
RestartSec=60

# Hardening
PrivateTmp=true

[Install]
WantedBy=multi-user.target" | tee "/etc/systemd/system/pleb-vpn.service"
  elif [ "${nodetype}" = "mynode" ]; then
    # create systemd service if no service exists
    if [ $(ls /etc/systemd/system | grep -c pleb-vpn.service) -eq 0 ]; then
      echo "
# pleb-vpn service
# /etc/systemd/system/pleb-vpn.service

[Unit]
Description=pleb-vpn
Wants=www.service docker_images.service
After=www.service docker_images.service

[Service]
WorkingDirectory=/opt/mynode/pleb-vpn

ExecStartPre=/usr/bin/is_not_shutting_down.sh
ExecStartPre=/bin/bash -c 'if [ -f /usr/bin/service_scripts/pre_pleb-vpn.sh ]; then /bin/bash /usr/bin/service_scripts/pre_pleb-vpn.sh; fi'
ExecStart=/bin/bash -c \"/opt/mynode/pleb-vpn/.venv/bin/gunicorn -k geventwebsocket.gunicorn.workers.GeventWebSocketWorker -w 1 -b 0.0.0.0:2420 main:app\"
ExecStartPost=/bin/bash -c 'if [ -f /usr/bin/service_scripts/post_pleb-vpn.sh ]; then /bin/bash /usr/bin/service_scripts/post_pleb-vpn.sh; fi'
#ExecStop=FILL_IN_EXECSTOP_AND_UNCOMMENT_IF_NEEDED

User=root
Group=root
Type=simple
TimeoutSec=120
Restart=always
RestartSec=60
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=pleb-vpn

[Install]
WantedBy=multi-user.target" | tee "/etc/systemd/system/pleb-vpn.service"
    fi

    # create /usr/bin/service_scripts/pre_pleb-vpn.sh if it doesn't exist
    if [ ! -f /usr/bin/service_scripts/pre_pleb-vpn.sh ]; then
      echo "#!/bin/bash

# This will run prior to launching the application

# create pleb-vpn.conf and initialize app if not already done
if [ ! -f /mnt/hdd/mynode/pleb-vpn/pleb-vpn.conf ]; then
  chmod +x /opt/mynode/pleb-vpn/pleb-vpn.install.sh
  /opt/mynode/pleb-vpn/pleb-vpn.install.sh on
fi

# re-initalize app on re-install of mynode
if [ ! -f /opt/mynode/pleb-vpn/pleb-vpn.conf ]; then
  chmod +x /mnt/hdd/mynode/pleb-vpn.install.sh
  /mnt/hdd/mynode/pleb-vpn/pleb-vpn.install.sh restore
fi
" | tee /usr/bin/service_scripts/pre_pleb-vpn.sh
    fi
  fi
  systemctl enable pleb-vpn.service
  systemctl start pleb-vpn.service

  # create nginx files
  if [ "${nodetype}" = "raspiblitz" ]; then
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

  elif [ "${nodetype}" = "mynode" ]; then
    # only used if not installed via the appstore
    if [ $(ls /usr/share/mynode_apps | grep -c pleb-vpn) -eq 0 ]; then
      echo "server {
    listen 2421 ssl;
    server_name pleb-vpn;

    include /etc/nginx/mynode/mynode_ssl_params.conf;
    include /etc/nginx/mynode/mynode_ssl_cert_key.conf;

    access_log /var/log/nginx/access_pleb-vpn.log;
    error_log /var/log/nginx/error_pleb-vpn.log;

    location / {
        proxy_pass http://127.0.0.1:2420;

        include /etc/nginx/mynode/mynode_ssl_proxy_params.conf;

    }

    location /static/ {
        alias /opt/mynode/pleb-vpn/webui/static/;
        # for debug purposes, always expire
        expires off;
        # expires 30d;
    }

    location /socket.io {
        include /etc/nginx/mynode/mynode_ssl_proxy_params.conf;
        proxy_http_version 1.1;
        proxy_buffering off;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \"Upgrade\";
        proxy_pass http://127.0.0.1:2420/socket.io;
    }

}
" | tee /etc/nginx/sites-enabled/https_pleb-vpn.conf
    fi

    # test and reload nginx
    nginx -t
    if [ $? -eq 0 ]; then
      echo "nginx config good"
      systemctl reload nginx
    else
      echo "Error: nginx test config fail"
      exit 1
    fi
  fi

  exit 0
}

update() 
{
  local skip_key="${1}"
  plebVPNConf="${homedir}/pleb-vpn.conf"
  source <(cat ${plebVPNConf} | sed '1d')

  # check for new version and update new version if it doesn't exists
  if [ "${latestversion}" = "${version}" ]; then
    # see if there's a newer version
    latestversion=$(${execdir}/.venv/bin/python ${execdir}/check_update.py)
    if [ "${latestversion}" = "${version}" ]; then
      echo "already up to date with the latest version"
      exit 0
    fi
  fi

  # download zip file into temp directory
  mkdir /home/admin/pleb-vpn-tmp
  cd /home/admin/pleb-vpn-tmp
  wget https://github.com/allyourbankarebelongtous/pleb-vpn/archive/refs/tags/${latestversion}.tar.gz
  tar -xzf ${latestversion}.tar.gz
  cd pleb-vpn-*
  isSuccess=$(ls | grep -c plebvpn_common)
  if [ ${isSuccess} -eq 0 ]; then
    echo "error: download and unzip failed. Check internet connection and version number and try again."
    if [ ! "${skip_key}" = "1" ]; then
      echo "Press ENTER to continue"
      read key </dev/tty
    fi
    rm -rf /home/admin/pleb-vpn-tmp
    exit 1
  else
    cp -p -r . ${execdir}
    cp -p -r . ${homedir}

    cd /home/admin
    rm -rf /home/admin/pleb-vpn-tmp
    # fix permissions
    chown -R admin:admin ${homedir}
    chown -R admin:admin ${execdir}
    chmod -R 755 ${homedir}
    chmod -R 755 ${execdir}
    # check for updates.sh and if exists, run it, then delete it
    isUpdateScript=$(ls ${execdir} | grep -c updates.sh)
    if [ ${isUpdateScript} -eq 1 ]; then
      ${execdir}/updates.sh
      rm ${execdir}/updates.sh
      rm ${homedir}/updates.sh
    fi
    # check for update_requirements.txt and if it exists, run it, then delete it
    isUpdateReqs=$(ls ${execdir} | grep -c update_requirements.txt)
    if [ ${isUpdateReqs} -eq 1 ]; then
      ${execdir}/.venv/bin/pip install -r ${execdir}/update_requirements.txt
      rm ${execdir}/update_requirements.txt
      rm ${homedir}/update_requirements.txt
    fi
    # update version in pleb-vpn.conf
    setting "${plebVPNConf}" "2" "version" "'${latestversion}'"
    setting "${plebVPNConf}" "2" "latestversion" "'${latestversion}'"
    echo "Update success!" 
    systemctl restart pleb-vpn.service
  fi
  if [ ! "${skip_key}" = "1" ]; then
    echo "Press ENTER to continue"
    read key </dev/tty
  fi
  echo "exiting script with exit code 0"
  exit 0
}

restore() 
{ 
  plebVPNConf="${homedir}/pleb-vpn.conf"
  source <(cat ${plebVPNConf} | sed '1d')
  # fix permissions
  chown -R admin:admin ${homedir}
  chmod -R 755 ${homedir}
  if [ "${nodetype}" = "raspiblitz" ]; then
    rm -rf ${homedir}/.backups
    # copy files to /home/admin/pleb-vpn
    cp -p -r ${homedir} /home/admin/
  elif [ "${nodetype}" = "mynode" ]; then
    # copy files to /opt/mynode/pleb-vpn
    cp -p -r ${homedir} /opt/mynode/
  fi
  # remove and symlink pleb-vpn.conf
  rm ${execdir}/pleb-vpn.conf
  ln -s ${homedir}/pleb-vpn.conf ${execdir}/pleb-vpn.conf
  # fix permissions
  chown -R admin:admin ${execdir}
  chmod -R 755 ${execdir}

  # install webui
  cd ${execdir}
  echo "installing virtualenv..."
  apt install -y virtualenv
  virtualenv -p python3 .venv
  # install requirements
  echo "installing requirements..."
  ${execdir}/.venv/bin/pip install -r ${execdir}/requirements.txt

  # allow through firewall
  ufw allow 2420 comment 'allow Pleb-VPN HTTP'
  ufw allow 2421 commment 'allow Pleb-VPN HTTPS'
  if [ "${nodetype}" = "mynode" ]; then
    # if installed from install script and not from mynode app store, allow through firewall to persist on restarts
    if [ $(ls /usr/share/mynode_apps | grep -c pleb-vpn) -eq 0 ]; then
      lineExists=$(cat $firewallConf | grep -c "allow Pleb-VPN HTTP")
      if [ $lineExists -eq 0 ]; then
        # add new rules to firewallConf
        sectionLine=$(cat ${firewallConf} | grep -n "^\# Add firewall rules" | cut -d ":" -f1 | head -n 1)
        insertLine=$(expr $sectionLine + 1)
        sed -i "${insertLine}iufw allow 2420 comment 'allow Pleb-VPN HTTP'" ${firewallConf}
        sed -i "${insertLine}iufw allow 2421 comment 'allow Pleb-VPN HTTPS'" ${firewallConf}
      fi
    fi
  fi

  if [ "${nodetype}" = "raspiblitz" ]; then
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
    sed -i "${insertLine}i${Line}" ${mainMenu}
    sectionName="/home/admin/99connectMenu.sh"
    sectionLine=$(cat ${mainMenu} | grep -n "${sectionName}" | cut -d ":" -f1)
    echo "# sectionLine(${sectionLine})"
    insertLine=$(expr $sectionLine + 2)
    echo "# insertLine(${insertLine})"
    Line='PLEB-VPN)'
    sed -i "${insertLine}i        ${Line}" ${mainMenu}
    insertLine=$(expr $sectionLine + 3)
    Line='/home/admin/pleb-vpn/pleb-vpnMenu.sh'
    sed -i "${insertLine}i            ${Line}" ${mainMenu}
    insertLine=$(expr $sectionLine + 4)
    Line=';;'
    sed -i "${insertLine}i            ${Line}" ${mainMenu}
    # create systemd service
    echo "
[Unit]
Description=Pleb-VPN guincorn app
Wants=network.target
After=network.target mnt-hdd.mount

[Service]
WorkingDirectory=/home/admin/pleb-vpn
ExecStart=/home/admin/pleb-vpn/.venv/bin/gunicorn -k geventwebsocket.gunicorn.workers.GeventWebSocketWorker -w 1 -b 0.0.0.0:2420 main:app
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
  elif [ "${nodetype}" = "mynode" ]; then
    # create systemd service if no service exists
    if [ $(ls /etc/systemd/system | grep -c pleb-vpn.service) -eq 0 ]; then
      echo "
# pleb-vpn service
# /etc/systemd/system/pleb-vpn.service

[Unit]
Description=pleb-vpn
Wants=www.service docker_images.service
After=www.service docker_images.service

[Service]
WorkingDirectory=/opt/mynode/pleb-vpn

ExecStartPre=/usr/bin/is_not_shutting_down.sh
ExecStartPre=/bin/bash -c 'if [ -f /usr/bin/service_scripts/pre_pleb-vpn.sh ]; then /bin/bash /usr/bin/service_scripts/pre_pleb-vpn.sh; fi'
ExecStart=/bin/bash -c \"/opt/mynode/pleb-vpn/.venv/bin/gunicorn -k geventwebsocket.gunicorn.workers.GeventWebSocketWorker -w 1 -b 0.0.0.0:2420 main:app\"
ExecStartPost=/bin/bash -c 'if [ -f /usr/bin/service_scripts/post_pleb-vpn.sh ]; then /bin/bash /usr/bin/service_scripts/post_pleb-vpn.sh; fi'
#ExecStop=FILL_IN_EXECSTOP_AND_UNCOMMENT_IF_NEEDED

User=root
Group=root
Type=simple
TimeoutSec=120
Restart=always
RestartSec=60
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=pleb-vpn

[Install]
WantedBy=multi-user.target" | tee "/etc/systemd/system/pleb-vpn.service"
    fi
    # create /usr/bin/service_scripts/pre_pleb-vpn.sh if it doesn't exist
    if [ ! -f /usr/bin/service_scripts/pre_pleb-vpn.sh ]; then
      echo "#!/bin/bash

# This will run prior to launching the application

# create pleb-vpn.conf and initialize app if not already done
if [ ! -f /mnt/hdd/mynode/pleb-vpn/pleb-vpn.conf ]; then
  chmod +x /opt/mynode/pleb-vpn/pleb-vpn.install.sh
  /opt/mynode/pleb-vpn/pleb-vpn.install.sh on
fi

# re-initalize app on re-install of mynode
if [ ! -f /opt/mynode/pleb-vpn/pleb-vpn.conf ]; then
  chmod +x /mnt/hdd/mynode/pleb-vpn.install.sh
  /mnt/hdd/mynode/pleb-vpn/pleb-vpn.install.sh restore
fi
" | tee /usr/bin/service_scripts/pre_pleb-vpn.sh
    fi
  fi

  # enable and start systemd service
  systemctl enable pleb-vpn.service
  systemctl start pleb-vpn.service

  # create nginx files
  if [ "${nodetype}" = "raspiblitz" ]; then
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

  elif [ "${nodetype}" = "mynode" ]; then
    # only used if not installed via the appstore
    if [ $(ls /usr/share/mynode_apps | grep -c pleb-vpn) -eq 0 ]; then
      echo "server {
    listen 2421 ssl;
    server_name pleb-vpn;

    include /etc/nginx/mynode/mynode_ssl_params.conf;
    include /etc/nginx/mynode/mynode_ssl_cert_key.conf;

    access_log /var/log/nginx/access_pleb-vpn.log;
    error_log /var/log/nginx/error_pleb-vpn.log;

    location / {
        proxy_pass http://127.0.0.1:2420;

        include /etc/nginx/mynode/mynode_ssl_proxy_params.conf;

    }

    location /static/ {
        alias /opt/mynode/pleb-vpn/webui/static/;
        # for debug purposes, never expire
        expires off;
        # expires 30d;
    }

    location /socket.io {
        include /etc/nginx/mynode/mynode_ssl_proxy_params.conf;
        proxy_http_version 1.1;
        proxy_buffering off;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \"Upgrade\";
        proxy_pass http://127.0.0.1:2420/socket.io;
    }

}
" | tee /etc/nginx/sites-enabled/https_pleb-vpn.conf
    fi

    # test and reload nginx
    nginx -t
    if [ $? -eq 0 ]; then
      echo "nginx config good"
      systemctl reload nginx
    else
      echo "Error: nginx test config fail"
      exit 1
    fi
  fi

  # step through pleb-vpn.conf and restore services
  source ${plebVPNConf}
  if [ "${plebvpn}" = "on" ]; then
    ${execdir}/vpn-install.sh on 1
  fi
  if [ "${lndhybrid}" = "on" ]; then
    ${execdir}/lnd-hybrid.sh on 1
  fi
  if [ "${clnhybrid}" = "on" ]; then
    ${execdir}/cln-hybrid.sh on 1
  fi
  if [ "${wireguard}" = "on" ]; then
    ${execdir}/wg-install.sh on 1
  fi
  if [ "${torsplittunnel}" = "on" ]; then
    ${execdir}/tor.split-tunnel.sh on
  fi
  if [ "${letsencrypt_ssl}" = "on" ]; then
    ${execdir}/letsencrypt.install.sh on 1 1
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
    paymentExists=$(cat ${execdir}/payments/${freq}${node}payments.sh | grep -c keysend)
    if ! [ ${paymentExists} -eq 0 ]; then
      # check if systemd unit for frequency and node exists, and if not, create it
      istimer=$(ls /etc/systemd/system/ | grep -c payments-${freq}-${node}.timer)
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
        systemctl enable payments-${freq}-${node}.timer
        systemctl start payments-${freq}-${node}.timer
      fi
    fi
    ((inc++))
  done
  exit 0
}

uninstall() 
{ 
  local mynode_uninstall="${1}"
  plebVPNConf="${homedir}/pleb-vpn.conf"
  source <(cat ${plebVPNConf} | sed '1d')
  # first uninstall services
  if [ "${letsencrypt_ssl}" = "on" ]; then
    ${execdir}/letsencrypt.install.sh off
  fi
  if [ "${torsplittunnel}" = "on" ]; then
    ${execdir}/tor.split-tunnel.sh off 1
  fi
  if [ "${lndhybrid}" = "on" ]; then
    ${execdir}/lnd-hybrid.sh off
  fi
  if [ "${clnhybrid}" = "on" ]; then
    ${execdir}/cln-hybrid.sh off
  fi
  if [ "${wireguard}" = "on" ]; then
    ${execdir}/wg-install.sh off
  fi
  if [ "${plebvpn}" = "on" ]; then
    ${execdir}/vpn-install.sh off
  fi
  # delete all payments
  ${execdir}/payments/managepayments.sh deleteall 1
  # remove extra line from custom-installs if required
  if [ "${nodetype}" = "raspiblitz" ]; then
    extraLine="# pleb-vpn restore"
    lineExists=$(cat /mnt/hdd/app-data/custom-installs.sh | grep -c "${extraLine}")
    if ! [ ${lineExists} -eq 0 ]; then
      sed -i "s:^${extraLine}.*::g" /mnt/hdd/app-data/custom-installs.sh
    fi
    extraLine="/mnt/hdd/app-data/pleb-vpn/pleb-vpn.install.sh"
    lineExists=$(cat /mnt/hdd/app-data/custom-installs.sh | grep -c "${extraLine}")
    if ! [ ${lineExists} -eq 0 ]; then
      sed -i "s:^${extraLine}.*::g" /mnt/hdd/app-data/custom-installs.sh
    fi

    # remove extra lines from 00mainMenu.sh if required
    extraLine='OPTIONS+=(PLEB-VPN "Install and manage PLEB-VPN services")'
    lineExists=$(cat /home/admin/00mainMenu.sh | grep -c "${extraLine}")
    if ! [ ${lineExists} -eq 0 ]; then
      sed -i "s:.*${extraLine}.*::g" /home/admin/00mainMenu.sh
    fi
    extraLine='PLEB-VPN)'
    lineExists=$(cat /home/admin/00mainMenu.sh | grep -c "${extraLine}")
    if ! [ ${lineExists} -eq 0 ]; then
      sed -i "s:.*${extraLine}.*::g" /home/admin/00mainMenu.sh
    fi
    extraLine='/home/admin/pleb-vpn/pleb-vpnMenu.sh'
    lineExists=$(cat /home/admin/00mainMenu.sh | grep -c "${extraLine}")
    if ! [ ${lineExists} -eq 0 ]; then
      sectionLine=$(cat /home/admin/00mainMenu.sh | grep -n "${extraLine}" | cut -d ":" -f1)
      nextLine=$(expr $sectionLine + 1)
      sed -i "${nextLine}d" /home/admin/00mainMenu.sh
      sed -i "s:.*${extraLine}.*::g" /home/admin/00mainMenu.sh
    fi

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
  fi

  # remove rules from firewall
  ufw delete allow 2420
  ufw delete allow 2421
  if [ "${nodetype}" = "mynode" ]; then
    # remove from firewallConf
    while [ $(cat ${firewallConf} | grep -c "ufw allow 2420 comment 'allow Pleb-VPN HTTP'") -gt 0 ];
    do
      sed -i "/ufw allow 2420 comment 'allow Pleb-VPN HTTP'/d" ${firewallConf}
    done
    while [ $(cat ${firewallConf} | grep -c "ufw allow 2421 comment 'allow Pleb-VPN HTTPS'") -gt 0 ];
    do
      sed -i "/ufw allow 2421 comment 'allow Pleb-VPN HTTPS'/d" ${firewallConf}
    done
  fi

  # delete files
  if [ "${nodetype}" = "raspiblitz" ]; then
    # delete nginx files
    sudo rm /etc/nginx/sites-available/pleb-vpn*
    sudo rm /etc/nginx/sites-enabled/pleb-vpn*
  fi
  rm -rf ${homedir}
  # these files will be deleted by mynode's uninstaller, so skip if uninstalling via mynode uninstaller
  if [ ! "${mynode_uninstall}" = "1" ]; then
    rm -rf ${execdir}
    rm /etc/nginx/sites-enabled/https_pleb-vpn.conf
    rm /usr/bin/service_scripts/pre_pleb-vpn.sh

    # stop and remove pleb-vpn.service
    rm /etc/systemd/system/pleb-vpn.service
    systemctl disable pleb-vpn.service
    systemctl stop pleb-vpn.service
  fi

  exit 0
}

case "${1}" in
  on) on ;;
  update) update "${2}" ;;
  restore) restore ;;
  uninstall) uninstall "${2}" ;;
  *) echo "install script for installing, updating, restoring after blitz update, or uninstalling pleb-vpn"; echo "pleb-vpn.install.sh [on|update|uninstall]"; exit 1 ;;
esac
