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

ver="1.1beta"

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
  if [[ ${VALUE} == *":"* ]]; then
    sudo sed -i --follow-symlinks "s/^${NAME}=.*/${NAME}=${VALUE}/g" ${FILE}
  else
    sudo sed -i --follow-symlinks "s:^${NAME}=.*:${NAME}=${VALUE}:g" ${FILE}
  fi
}

on() {
  # only for new install

  # check if sudo
  if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (with sudo)"
    exit 1
  fi

####################################### FIX THIS SECTION TO DOWNLOAD A VERSION TAR.GZ FILE INSTEAD ##########################################
  # git pull from github
  if [ "${nodetype}" = "raspiblitz" ]; then
    cd /home/admin/
  elif [ "${nodetype}" = "mynode" ]; then
    cd /opt/mynode/
  fi
  sudo git clone --recursive https://github.com/allyourbankarebelongtous/pleb-vpn.git

################################# FOR TESTING OTHER BRANCHES, NOT FOR PRODUCTION #########################################
  cd ${execdir}
  sudo git checkout -b mynode
  sudo git pull origin mynode 
  sudo git submodule init
  sudo git submodule update

################################# END TESTING #####################################
  sudo chown -R admin:admin ${execdir}
  sudo chmod -R 755 ${execdir}

  # get date of last commit to store in pleb-vpn.conf
  versiondate=$(git log -1 --format=%ci)

  # check for, and if present, remove updates.sh
  isUpdateScript=$(ls ${execdir} | grep -c updates.sh)
  if [ ${isUpdateScript} -eq 1 ]; then
    # only used for updates, not new installs, so remove
    sudo rm ${execdir}/updates.sh
  fi
  sudo mkdir ${execdir}/payments/keysends
  if [ "${nodetype}" = "raspiblitz" ]; then
    # move the files to /mnt/hdd/app-data/pleb-vpn
    sudo cp -p -r ${execdir} /mnt/hdd/app-data/
    # fix permissions
    sudo chown -R admin:admin ${homedir}
    sudo chmod -R 755 ${homedir}
  elif [ "${nodetype}" = "mynode" ]; then
    # move the files to /mnt/hdd/mynode/pleb-vpn
    sudo cp -p -r ${execdir} /mnt/hdd/mynode/
    # fix permissions
    sudo chown -R admin:admin ${homedir}
    sudo chmod -R 755 ${homedir}
  fi
  # create and symlink pleb-vpn.conf
  echo "[PLEBVPN]
version=
versiondate=
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
  if [ "${nodetype}" = "raspiblitz" ]; then
    sudo ln -sf ${homedir}/pleb-vpn.conf ${execdir}/pleb-vpn.conf
    # backup critical files and configs
    ${execdir}/pleb-vpn.backup.sh backup
  elif [ "${nodetype}" = "mynode" ]; then
    sudo ln -sf ${homedir}/pleb-vpn.conf ${execdir}/pleb-vpn.conf
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
  sudo cp -p ${execdir}/payments/*lndpayments.sh ${homedir}/payments/
  sudo cp -p ${execdir}/payments/*clnpayments.sh ${homedir}/payments/
  # fix permissions
  sudo chown -R admin:admin ${homedir}
  sudo chmod -R 755 ${homedir}
  # fix permissions
  sudo chown -R admin:admin ${execdir}
  sudo chmod -R 755 ${execdir}
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
  setting ${plebVPNConf} "2" "versiondate" "'${versiondate}'"
  setting ${plebVPNConf} "2" "nodetype" "'${nodetype}'"

  # for raspiblitz menu install
  if [ "${nodetype}" = "raspiblitz" ]; then 

    # make persistant with custom-installs.sh
    isPersistant=$(cat /mnt/hdd/app-data/custom-installs.sh | grep -c /mnt/hdd/app-data/pleb-vpn/pleb-vpn.install.sh)
    if [ ${isPersistant} -eq 0 ]; then
      echo "
# pleb-vpn restore
/mnt/hdd/app-data/pleb-vpn/pleb-vpn.install.sh restore
# get latest pleb-vpn update
/mnt/hdd/app-data/pleb-vpn/pleb-vpn.install.sh update 1
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

    # add pleb-vpn to 00infoBlitz.sh for status check
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
  fi

  # install webui
  cd ${execdir}
  echo "installing virtualenv..."
  sudo apt install -y virtualenv
  sudo virtualenv -p python3 .venv
  # install requirements
  echo "installing requirements..."
  sudo ${execdir}/.venv/bin/pip install -r ${execdir}/requirements.txt

  # allow through firewall
  sudo ufw allow 2420 comment 'allow Pleb-VPN HTTP'
  if [ "${nodetype}" = "mynode" ]; then
      # add new rules to firewallConf
      sectionLine=$(cat ${firewallConf} | grep -n "^\# Add firewall rules" | cut -d ":" -f1 | head -n 1)
      insertLine=$(expr $sectionLine + 1)
      sed -i "${insertLine}iufw allow 2420 comment 'allow Pleb-VPN HTTP'" ${firewallConf}
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
  elif [ "${nodetype}" = "mynode" ]; then
    echo "
[Unit]
Description=Pleb-VPN guincorn app
Wants=www.service docker_images.service
After=www.service docker_images.service

[Service]
WorkingDirectory=/opt/mynode/pleb-vpn
ExecStartPre=/usr/bin/is_not_shutting_down.sh
ExecStart=/bin/bash -c \"/opt/mynode/pleb-vpn/.venv/bin/gunicorn -k geventwebsocket.gunicorn.workers.GeventWebSocketWorker -w 1 -b 0.0.0.0:2420 main:app\"
User=root
Group=root
Restart=always
Type=simple
TimeoutSec=120
Restart=always
RestartSec=60
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=lndg

[Install]
WantedBy=multi-user.target" | sudo tee "/etc/systemd/system/pleb-vpn.service"
  fi
  sudo systemctl enable pleb-vpn.service
  sudo systemctl start pleb-vpn.service
  exit 0
}

update() {
  plebVPNConf="${homedir}/pleb-vpn.conf"
  plebVPNTempConf="${homedir}/pleb-vpn.conf.tmp"
  sudo sed '1d' $plebVPNConf > $plebVPNTempConf
  source ${plebVPNTempConf}
  sudo rm ${plebVPNTempConf}
  local skip_key="${1}"
  # git clone to temp directory
  sudo mkdir /home/admin/pleb-vpn-tmp
  cd /home/admin/pleb-vpn-tmp
  sudo git clone --recursive https://github.com/allyourbankarebelongtous/pleb-vpn.git
  # these commands are for checking out a specific branch for testing
  cd /home/admin/pleb-vpn-tmp/pleb-vpn
  sudo git checkout -b mynode
  sudo git pull origin mynode
  sudo git submodule init
  sudo git submodule update
  # check if successful
  isSuccess=$(ls /home/admin/pleb-vpn-tmp/ | grep -c pleb-vpn)
  if [ ${isSuccess} -eq 0 ]; then
    echo "error: git clone failed. Check internet connection and try again."
    if [ ! "${skip_key}" = "1" ]; then
      echo "Press ENTER to continue"
      read key </dev/tty
    fi
    sudo rm -rf /home/admin/pleb-vpn-tmp
    exit 1
  else
    sudo systemctl stop pleb-vpn.service
    sudo rm -rf ${execdir}
    if [ "${nodetype}" = "raspiblitz" ]; then
      sudo cp -p -r /home/admin/pleb-vpn-tmp/pleb-vpn /home/admin/
      sudo cp -p -r ${execdir} /mnt/hdd/app-data/
    elif [ "${nodetype}" = "mynode" ]; then
      sudo cp -p -r /home/admin/pleb-vpn-tmp/pleb-vpn /opt/mynode/
      sudo cp -p -r ${execdir} /mnt/hdd/mynode/
    fi
    sudo rm -rf /home/admin/pleb-vpn-tmp
    # fix permissions
    sudo chown -R admin:admin ${homedir}
    sudo chown -R admin:admin ${execdir}
    sudo chmod -R 755 ${homedir}
    sudo chmod -R 755 ${execdir}
    if [ -d ${homedir}/split-tunnel/ ]; then
      sudo cp -p -r ${homedir}/split-tunnel ${execdir}
    fi
    sudo cp -p -r ${homedir}/payments ${execdir}
    sudo ln -s ${homedir}/pleb-vpn.conf ${execdir}/pleb-vpn.conf
    cd /home/admin
    # check for updates.sh and if exists, run it, then delete it
    isUpdateScript=$(ls ${execdir} | grep -c updates.sh)
    if [ ${isUpdateScript} -eq 1 ]; then
      sudo ${execdir}/updates.sh
      sudo rm ${execdir}/updates.sh
      sudo rm ${homedir}/updates.sh
    fi
    # install webui
    cd ${execdir}
    echo "installing virtualenv..."
    sudo apt install -y virtualenv
    sudo virtualenv -p python3 .venv
    # install requirements
    echo "installing requirements..."
    sudo ${execdir}/.venv/bin/pip install -r ${execdir}/requirements.txt
    # start pleb-vpn.service
    sudo systemctl start pleb-vpn.service
    echo "Update success!" 
  fi
  if [ ! "${skip_key}" = "1" ]; then
    echo "Press ENTER to continue"
    read key </dev/tty
  fi
  echo "exiting script with exit code 0"
  exit 0
}

restore() { 
  plebVPNConf="${homedir}/pleb-vpn.conf"
  plebVPNTempConf="${homedir}/pleb-vpn.conf.tmp"
  sudo sed '1d' $plebVPNConf > $plebVPNTempConf
  source ${plebVPNTempConf}
  sudo rm ${plebVPNTempConf}
  # fix permissions
  sudo chown -R admin:admin ${homedir}
  sudo chmod -R 755 ${homedir}
  if [ "${nodetype}" = "raspiblitz" ]; then
    sudo rm -rf ${homedir}/.backups
    # copy files to /home/admin/pleb-vpn
    sudo cp -p -r ${homedir} /home/admin/
  elif [ "${nodetype}" = "mynode" ]; then
    # copy files to /opt/mynode/pleb-vpn
    sudo cp -p -r ${homedir} /opt/mynode/
  fi
  # remove and symlink pleb-vpn.conf
  sudo rm ${execdir}/pleb-vpn.conf
  sudo ln -s ${homedir}/pleb-vpn.conf ${execdir}/pleb-vpn.conf
  # fix permissions
  sudo chown -R admin:admin ${execdir}
  sudo chmod -R 755 ${execdir}

  # install webui
  cd ${execdir}
  echo "installing virtualenv..."
  sudo apt install -y virtualenv
  sudo virtualenv -p python3 .venv
  # install requirements
  echo "installing requirements..."
  sudo ${execdir}/.venv/bin/pip install -r ${execdir}/requirements.txt

  # allow through firewall
  sudo ufw allow 2420 comment 'allow Pleb-VPN HTTP'
  if [ "${nodetype}" = "mynode" ]; then
      # add new rules to firewallConf
      sectionLine=$(cat ${firewallConf} | grep -n "^\# Add firewall rules" | cut -d ":" -f1 | head -n 1)
      insertLine=$(expr $sectionLine + 1)
      sed -i "${insertLine}iufw allow 2420 comment 'allow Pleb-VPN HTTP'" ${firewallConf}
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
    # create systemd service
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
  elif [ "${nodetype}" = "mynode" ]; then
    # create systemd service
    echo "
[Unit]
Description=Pleb-VPN guincorn app
Wants=www.service docker_images.service
After=www.service docker_images.service

[Service]
WorkingDirectory=/opt/mynode/pleb-vpn
ExecStartPre=/usr/bin/is_not_shutting_down.sh
ExecStart=/bin/bash -c \"/opt/mynode/pleb-vpn/.venv/bin/gunicorn -k geventwebsocket.gunicorn.workers.GeventWebSocketWorker -w 1 -b 0.0.0.0:2420 main:app\"
User=root
Group=root
Restart=always
Type=simple
TimeoutSec=120
Restart=always
RestartSec=60
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=lndg

[Install]
WantedBy=multi-user.target" | sudo tee "/etc/systemd/system/pleb-vpn.service"
  fi

  # enable and start systemd service
  sudo systemctl enable pleb-vpn.service
  sudo systemctl start pleb-vpn.service

  # step through pleb-vpn.conf and restore services
  source ${plebVPNConf}
  if [ "${plebvpn}" = "on" ]; then
    sudo ${execdir}/vpn-install.sh on 1
  fi
  if [ "${lndhybrid}" = "on" ]; then
    sudo ${execdir}/lnd-hybrid.sh on 1
  fi
  if [ "${clnhybrid}" = "on" ]; then
    sudo ${execdir}/cln-hybrid.sh on 1
  fi
  if [ "${wireguard}" = "on" ]; then
    sudo ${execdir}/wg-install.sh on 1
  fi
  if [ "${torsplittunnel}" = "on" ]; then
    sudo ${execdir}/tor.split-tunnel.sh on
  fi
  if [ "${letsencrypt_ssl}" = "on" ]; then
    sudo ${execdir}/letsencrypt.install.sh on 1 1
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
      istimer=$(sudo ls /etc/systemd/system/ | grep -c payments-${freq}-${node}.timer)
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
        sudo systemctl enable payments-${freq}-${node}.timer
        sudo systemctl start payments-${freq}-${node}.timer
      fi
    fi
    ((inc++))
  done
  exit 0
}

uninstall() { 
  plebVPNConf="${homedir}/pleb-vpn.conf"
  plebVPNTempConf="${homedir}/pleb-vpn.conf.tmp"
  sudo sed '1d' $plebVPNConf > $plebVPNTempConf
  source ${plebVPNTempConf}
  sudo rm ${plebVPNTempConf}
  # first uninstall services
  if [ "${letsencrypt_ssl}" = "on" ]; then
    sudo ${execdir}/letsencrypt.install.sh off
  fi
  if [ "${torsplittunnel}" = "on" ]; then
    sudo ${execdir}/tor.split-tunnel.sh off 1
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
  sudo ${execdir}/payments/managepayments.sh deleteall 1
  # remove extra line from custom-installs if required
  if [ "${nodetype}" = "raspiblitz" ]; then
    extraLine="# pleb-vpn restore"
    lineExists=$(sudo cat /mnt/hdd/app-data/custom-installs.sh | grep -c "${extraLine}")
    if ! [ ${lineExists} -eq 0 ]; then
      sudo sed -i "s:^${extraLine}.*::g" /mnt/hdd/app-data/custom-installs.sh
    fi
    extraLine="/mnt/hdd/app-data/pleb-vpn/pleb-vpn.install.sh"
    lineExists=$(sudo cat /mnt/hdd/app-data/custom-installs.sh | grep -c "${extraLine}")
    if ! [ ${lineExists} -eq 0 ]; then
      sudo sed -i "s:^${extraLine}.*::g" /mnt/hdd/app-data/custom-installs.sh
    fi

    # remove extra lines from 00mainMenu.sh if required
    extraLine='OPTIONS+=(PLEB-VPN "Install and manage PLEB-VPN services")'
    lineExists=$(sudo cat /home/admin/00mainMenu.sh | grep -c "${extraLine}")
    if ! [ ${lineExists} -eq 0 ]; then
      sudo sed -i "s:.*${extraLine}.*::g" /home/admin/00mainMenu.sh
    fi
    extraLine='PLEB-VPN)'
    lineExists=$(sudo cat /home/admin/00mainMenu.sh | grep -c "${extraLine}")
    if ! [ ${lineExists} -eq 0 ]; then
      sudo sed -i "s:.*${extraLine}.*::g" /home/admin/00mainMenu.sh
    fi
    extraLine='/home/admin/pleb-vpn/pleb-vpnMenu.sh'
    lineExists=$(sudo cat /home/admin/00mainMenu.sh | grep -c "${extraLine}")
    if ! [ ${lineExists} -eq 0 ]; then
      sectionLine=$(sudo cat /home/admin/00mainMenu.sh | grep -n "${extraLine}" | cut -d ":" -f1)
      nextLine=$(expr $sectionLine + 1)
      sudo sed -i "${nextLine}d" /home/admin/00mainMenu.sh
      sudo sed -i "s:.*${extraLine}.*::g" /home/admin/00mainMenu.sh
    fi

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
  fi

  # stop and remove pleb-vpn.service
  sudo systemctl stop pleb-vpn.service
  sudo systemctl disable pleb-vpn.service
  sudo rm /etc/systemd/system/pleb-vpn.service

  # delete files
  sudo rm -rf ${execdir}
  sudo rm -rf ${homedir}
  exit 0
}

case "${1}" in
  on) on ;;
  update) update "${2}" ;;
  restore) restore ;;
  uninstall) uninstall ;;
  *) echo "err=Unknown action: ${1}" ; exit 1 ;;
esac
