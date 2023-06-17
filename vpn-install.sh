#!/bin/bash

# installs and configures openvpn, sets killswitch firewall
# also used to uninstall openvpn and restore firewall
# example: "vpn-install.sh on"
# to install and automatically keep current configuration
# use "vpn-install.sh on 1"

# find home directory based on node implementation
if [ -d "/mnt/hdd/mynode/pleb-vpn/" ]; then
  homedir="/mnt/hdd/mynode/pleb-vpn"
  execdir="/opt/mynode/pleb-vpn"
  firewallConf="/usr/bin/mynode_firewall.sh"
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

if [ "${nodetype}" = "raspiblitz" ]; then
  source /mnt/hdd/raspiblitz.conf
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
  local webui="${1}"

  isConfig=$(ls ${homedir}/openvpn/ | grep -c plebvpn.conf)
  message="Pleb-VPN is installed, configured, and operating as expected"
  if [ ${isConfig} -eq 0 ]; then
    isConfig="no"
  else
    isConfig="yes"
  fi
  if [ "${plebvpn}" = "off" ]; then
    message="Pleb-VPN is not installed. Install Pleb-VPN by selecting Pleb-VPN from the Services Menu above."
    if [ "${webui}" = "1" ]; then
      echo "vpn_operating=no
config_exists=${isConfig}
message='${message}'" | tee ${execdir}/pleb-vpn_status.tmp
    else
      whiptail --title "Pleb-VPN status" --msgbox "
Pleb-VPN installed: no
Pleb-VPN config found: ${isConfig}
Use menu to install Pleb-VPN.
" 10 40
    fi
    exit 0
  else
    currentIP=$(curl https://api.ipify.org)
    sleep 1
    if ! [ "${currentIP}" = "${vpnip}" ]; then
      vpnWorking="no"
      message="ERROR: your current IP does not match your vpnIP"
    else
      vpnWorking="yes"
    fi 
    firewallOK="yes"
    killswitchOn=$(ufw status verbose | grep Default | grep -c 'deny (outgoing)')
    if [ ${killswitchOn} -eq 0 ]; then
      killswitchOn="no"
      firewallOK="no"
      message="ERROR: your firewall is not configured properly (should deny outgoing by default).
Otherwise you may leak your home IP if VPN drops."
    else
      killswitchOn="yes"
    fi
    firewallallow=$(ufw status verbose | grep -c 'Anywhere on tun0')
    if [ ${firewallallow} -eq 2 ]; then
      firewallallow="yes"
    else
      firewallallow="no"
      firewallOK="no"
      message="ERROR: your firewall is not configured properly (must allow in/out on tun0).
Otherwise you will not be able to send or receive with VPN on."
    fi
    firewallallowout=$(ufw status verbose | grep "${vpnip} ${vpnport}" | grep -c "ALLOW OUT")
    if [ ${firewallallowout} -eq 1 ]; then
      firewallallowout="yes"
    else
      firewallallowout="no"
      firewallOK="no"
      message="ERROR: your firewall is not configured properly (must allow out on ${vpnip} ${vpnport}/udp).
Otherwise your VPN will not reach the server and connect."
    fi
    serviceExists=$(ls /etc/systemd/system/multi-user.target.wants/ | grep -c openvpn@plebvpn.service)
    if [ ${serviceExists} -eq 0 ]; then
      serviceExists="no"
      message="ERROR: no service exists. Run 'systemctl enable openvpn@plebvpn' on cmd line"
    else
      serviceExists="yes"
    fi
    if [ "${webui}" = "1" ]; then
      echo "vpn_operating=${vpnWorking}
current_ip='${currentIP}'
config_exists=${isConfig}
firewall_configured=${firewallOK}
message='${message}'" | tee ${execdir}/pleb-vpn_status.tmp
    else
      whiptail --title "Pleb-VPN status" --msgbox "
VPN installed: yes
VPN operating: ${vpnWorking}
VPN service installed: ${serviceExists}
VPN config file found: ${isConfig}
VPN server IP: ${vpnip}
VPN server port: ${vpnport}
Current IP (should match VPN server IP): ${currentIP}
Firewall configuration OK: ${firewallOK}
${message}
" 16 100
    fi
    exit 0
  fi
}

on() {
  # install and configure openvpn
  local keepconfig="${1}"
  local isRestore="${1}"
  local webui="${2}"
  isconfig=$(ls ${homedir}/openvpn/ | grep -c plebvpn.conf)
  if ! [ ${isconfig} -eq 0 ]; then
    if [ -z "${keepconfig}" ]; then
      if [ ! "{webui}" = "1" ]; then
        whiptail --title "Use Existing Configuration?" \
        --yes-button "Use Existing Config" \
        --no-button "Create New Config" \
        --yesno "There's an existing configuration found from a previous install of openvpn. Do you wish to reuse this config file?" 10 80
        if [ $? -eq 1 ]; then
          keepconfig="0"
        else
          keepconfig="1"
        fi
      fi
    fi
  else
    keepconfig="0"    
  fi

  # install openvpn
  apt-get -y install openvpn

  # get config if not webui or selected to keep config
  if [ "${keepconfig}" = "0" ]; then
    if [ ! "{webui}" = "1" ]; then
      # remove old conf file if applicable
      isfolder=$(ls ${homedir}/ | grep -c openvpn)
      if ! [ ${isfolder} -eq 0 ]; then
        rm -rf ${homedir}/openvpn
      fi
      # get new conf file
      # get local ip
      localip=$(hostname -I | awk '{print $1}')
      # upload plebvpn.conf
      filename=""
      while [ "${filename}" = "" ]
      do
        clear
        echo "********************************"
        echo "* UPLOAD THE PLEBVPN.CONF FILE *"
        echo "********************************"
        echo "If you are using the paid version of pleb-vpn, obtain an openvpn"
        echo "configuration file called plebvpn.conf from allyourbankarebelongtous."
        echo "You can obtain this by contacting @allyourbankarebelongtous on Telegram."
        echo
        echo "If you have a plebvpn.conf file, or if you are using your own openvpn setup"
        echo "upload your configuration file. MAKE SURE IT IS NAMED plebvpn.conf!"
        echo
        echo "To upload, open a new terminal on your laptop,"
        echo "change into the directory where your plebvpn.conf file is and"
        echo "COPY, PASTE AND EXECUTE THE FOLLOWING COMMAND:"
        echo "scp -r plebvpn.conf admin@${localip}:/home/admin/"
        echo
        echo "Use your password A to authenticate file transfer."
        echo "PRESS ENTER when upload is done"
        read key
        # check to see if upload was successful
        isuploaded=$(ls /home/admin/ | grep -c plebvpn.conf)
        if ! [ $isuploaded -eq 0 ]; then
          filename="plebvpn.conf"
          echo "OK - File found: ${filename}"
          echo "PRESS ENTER to continue."
          read key
        else
          echo "# WARNING #"
          echo "There was no plebvpn.conf found in /home/admin/"
          echo "PRESS ENTER to continue & retry ... or 'x' + ENTER to cancel"
          read keyRetry
        fi
        if [ "${keyRetry}" == "x" ] || [ "${keyRetry}" == "X" ] || [ "${keyRetry}" == "'x'" ]; then
          # create no result file and exit
          echo "# USER CANCEL"
          exit 1
        fi
      done
      # move plebvpn.conf
      mkdir ${homedir}/openvpn
      mv /home/admin/plebvpn.conf ${homedir}/openvpn/plebvpn.conf
    fi
  fi

  # get vpnIP for pleb-vpn.conf
  vpnip=$(cat ${homedir}/openvpn/plebvpn.conf | grep remote | sed 's/remote-.*$//g' | cut -d " " -f2)
  vpnport=$(cat ${homedir}/openvpn/plebvpn.conf | grep remote | sed 's/remote-.*$//g' | cut -d " " -f3)
  setting ${plebVPNConf} "2" "vpnport" "'${vpnport}'"
  setting ${plebVPNConf} "2" "vpnip" "'${vpnip}'"
  # copy plebvpn.conf to /etc/openvpn
  cp -p ${homedir}/openvpn/plebvpn.conf /etc/openvpn/
  # fix permissions
  chown admin:admin /etc/openvpn/plebvpn.conf
  chmod 644 /etc/openvpn/plebvpn.conf
  # enable and start openvpn
  systemctl enable openvpn@plebvpn
  systemctl start openvpn@plebvpn
  # check to see if it works
  sleep 10
  currentIP=$(curl https://api.ipify.org)
  sleep 10
  if ! [ "${currentIP}" = "${vpnip}" ]; then
    echo "error: vpn not working"
    echo "your current IP is not your vpn IP"
    exit 1
  else
    echo "OK ... your vpn is now active"
  fi

  # configure firewall
  echo "configuring firewall"
  LAN=$(ip rou | grep default | cut -d " " -f3 | sed 's/^\(.*\)\.\(.*\)\.\(.*\)\.\(.*\)$/\1\.\2\.\3/g')
  # disable firewall 
  ufw disable
  # allow local lan ssh
  ufw allow in to ${LAN}.0/24
  ufw allow out to ${LAN}.0/24
  # set default policy (killswitch)
  ufw default deny outgoing
  ufw default deny incoming
  # allow out on openvpn
  ufw allow out to ${vpnip} port ${vpnport} proto udp
  # force traffic to use openvpn
  ufw allow out on tun0 from any to any
  ufw allow in on tun0 from any to any
  # enable firewall
  ufw --force enable
  if [ "${nodetype}" = "mynode" ]; then
    # allow docker containers out
    ufw allow out to 172.16.0.0/12
    # add new rules to firewallConf
    sectionLine=$(cat ${firewallConf} | grep -n "^\# Add firewall rules" | cut -d ":" -f1 | head -n 1)
    insertLine=$(expr $sectionLine + 1)
    sed -i "${insertLine}iufw allow in to ${LAN}.0/24" ${firewallConf}
    sed -i "${insertLine}iufw allow out to ${LAN}.0/24" ${firewallConf}
    sed -i "${insertLine}iufw allow out to ${vpnip} port ${vpnport} proto udp" ${firewallConf}
    sed -i "${insertLine}iufw allow out on tun0 from any to any" ${firewallConf}
    sed -i "${insertLine}iufw allow in on tun0 from any to any" ${firewallConf}
    sed -i "${insertLine}iufw allow out to 172.16.0.0/12" ${firewallConf}
    sed -i "s/ufw default allow outgoing/ufw default deny outgoing/g" ${firewallConf}
    # allow local mDNS traffic for mynode.local
    sectionLine=$(cat /etc/ufw/before.rules | grep -n "^\# End required lines" | cut -d ":" -f1 | head -n 1)
    insertLine=$(expr $sectionLine + 1)
    sed -i "${insertLine}i-A ufw-before-output -p udp --dport 5353 -j ACCEPT" /etc/ufw/before.rules
    sed -i "${insertLine}i# Allow outgoing mDNS traffic" /etc/ufw/before.rules
    ufw reload
    # fix get_local_ip() to still return lan ip instead of virtual ip from openvpn
    mv /usr/bin/get_local_ip.py /usr/bin/get_local_ip.py.bak
    echo "#!/usr/local/bin/python3

import subprocess

output = subprocess.run(\"hostname -I | awk '{print \$1}'\", stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True)
local_ip = output.stdout.strip('\\n')

print(local_ip)
" | tee /usr/bin/get_local_ip.py
    chmod 755 /usr/bin/get_local_ip.py
  fi
  # check firewall
  # skip test if restore or webui
  if [ ! "${isRestore}" = "1" ]; then
    if [ ! "${webui}" = "1" ]; then
      echo "checking configuration"
      echo "stop vpn"
      systemctl stop openvpn@plebvpn
      echo "vpn stopped"
      echo "checking firewall"
      currentIP=$(curl https://api.ipify.org)
      echo "current IP = (${currentIP})...should be blank"
      if [ "${currentIP}" = "" ]; then
        echo "firewall config ok"
      else 
        echo "error...firewall not configured. Clearnet accessible when VPN is off. Uninstall and re-install pleb-vpn"
        systemctl start openvpn@plebvpn
        exit 1
      fi
      echo "start vpn"
      systemctl start openvpn@plebvpn
      sleep 10
      currentIP=$(curl https://api.ipify.org)
      if ! [ "${currentIP}" = "${vpnIP}" ]; then
        echo "error: vpn not working"
        echo "your current IP is not your vpn IP"
        exit 1
      else
        echo "OK ... your vpn is now active"
      fi
    fi
  fi
  setting ${plebVPNConf} "2" "plebvpn" "on"
  echo "OK ... plebvpn installed and configured!"
  exit 0
}

off() {
  # remove and uninstall openvpn
  local webui="${1}"

  # first ensure that no nodes are operating on clearnet and wireguard and letsencrypt are uninstalled
  if [ "${lndhybrid}" = "on" ] || [ "${clnhybrid}" = "on" ] || [ "${wireguard}" = "on" ] || [ "${letsencrypt_ssl}" = "on" ] || [ "${torsplittunnel}" = "on" ]; then
    echo "# WARNING #"
    echo "you must first disable hybrid mode on your node(s) before removing openvpn"
    echo "otherwise your home IP will be visible"
    echo "you must also disable wireguard and letsencrypt, as they will not function without a static ip"
    exit 1
  fi

  # uninstall openvpn
  apt-get -y purge openvpn 
  rm -rf /etc/openvpn
  # configure firewall
  echo "configuring firewall"
  # disable firewall 
  ufw disable
  # set default policy
  ufw default allow outgoing
  ufw default deny incoming
  # remove openvpn rule
  ufw delete allow out to ${vpnip} port ${vpnport} proto udp
  # delete force traffic to use openvpn
  ufw delete allow out on tun0 from any to any
  ufw delete allow in on tun0 from any to any
  # enable firewall
  ufw --force enable
  if [ "${nodetype}" = "mynode" ]; then
    # remove allow out for docker containers as default is now allow outgoing
    ufw delete allow out to 172.16.0.0/12
    # delete rules from firewallConf
    LAN=$(ip rou | grep default | cut -d " " -f3 | sed 's/^\(.*\)\.\(.*\)\.\(.*\)\.\(.*\)$/\1\.\2\.\3/g')
    while [ $(cat ${firewallConf} | grep -c "ufw allow in to ${LAN}") -gt 0 ];
    do
      sed -i "/ufw allow in to ${LAN}\.0\/24/d" ${firewallConf}
    done
    while [ $(cat ${firewallConf} | grep -c "ufw allow out to ${LAN}") -gt 0 ];
    do
      sed -i "/ufw allow out to ${LAN}\.0\/24/d" ${firewallConf}
    done
    while [ $(cat ${firewallConf} | grep -c "ufw allow out to ${vpnip} port ${vpnport} proto udp") -gt 0 ];
    do
      sed -i "/ufw allow out to ${vpnip} port ${vpnport} proto udp/d" ${firewallConf}
    done
    while [ $(cat ${firewallConf} | grep -c "ufw allow out on tun0 from any to any") -gt 0 ];
    do
      sed -i "/ufw allow out on tun0 from any to any/d" ${firewallConf}
    done
    while [ $(cat ${firewallConf} | grep -c "ufw allow out to 172.16.0.0/12") -gt 0 ];
    do
      sed -i "/ufw allow out to 172\.16\.0\.0\/12/d" ${firewallConf}
    done
    while [ $(cat ${firewallConf} | grep -c "ufw allow in on tun0 from any to any") -gt 0 ];
    do
      sed -i "/ufw allow in on tun0 from any to any/d" ${firewallConf}
    done
    sed -i "s/ufw default deny outgoing/ufw default allow outgoing/g" ${firewallConf}
    # remove allow local mDNS traffic for mynode.local
    sed -i  '/^# Allow outgoing mDNS traffic/d' /etc/ufw/before.rules
    sed -i '/^-A ufw-before-output -p udp --dport 5353 -j ACCEPT/d' /etc/ufw/before.rules
    ufw reload
    # return get_local_ip() to default
    rm /usr/bin/get_local_ip.py
    mv /usr/bin/get_local_ip.py.bak /usr/bin/get_local_ip.py
  fi
  setting ${plebVPNConf} "2" "vpnport" "''"
  setting ${plebVPNConf} "2" "vpnip" "''"
  setting ${plebVPNConf} "2" "plebvpn" "off"
  exit 0
}

case "${1}" in
  status) status "${2}" ;;
  on) on "${2}" "${3}" ;;
  off) off "${2}" ;;
  *) echo "config script to install and configure or uninstall openvpn"; echo "vpn-install.sh [on|off|status]"; exit 1 ;;
esac 
