#!/bin/bash

# installs and configures openvpn, sets killswitch firewall
# also used to uninstall openvpn and restore firewall
# example: "vpn-install.sh on"
# to install and automatically keep current configuration
# use "vpn-install.sh on 1"

# command info
if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "-help" ]; then
  echo "config script to install and configure or uninstall openvpn"
  echo "vpn-install.sh [on|off|status]"
  exit 1
fi

plebVPNConf="/mnt/hdd/mynode/pleb-vpn/pleb-vpn.conf"
firewallConf="/usr/bin/mynode_firewall.sh"

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
  source ${plebVPNConf}

  isConfig=$(ls /mnt/hdd/mynode/pleb-vpn/openvpn/ | grep -c plebvpn.conf)
  message="Pleb-VPN is installed, configured, and operating as expected"
  if [ ${isConfig} -eq 0 ]; then
    isConfig="no"
  else
    isConfig="yes"
  fi
  if [ "${plebvpn}" = "off" ]; then
    message="Pleb-VPN is not installed. Install Pleb-VPN by selecting Pleb-VPN from the Services Menu above."
    echo "vpn_operating=no
config_exists=${isConfig}
message='${message}'" | tee /mnt/hdd/mynode/pleb-vpn/pleb-vpn_status.tmp
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
    killswitchOn=$(sudo ufw status verbose | grep Default | grep -c 'deny (outgoing)')
    if [ ${killswitchOn} -eq 0 ]; then
      killswitchOn="no"
      firewallOK="no"
      message="ERROR: your firewall is not configured properly (should deny outgoing by default).
Otherwise you may leak your home IP if VPN drops."
    else
      killswitchOn="yes"
    fi
    firewallallow=$(sudo ufw status verbose | grep -c 'Anywhere on tun0')
    if [ ${firewallallow} -eq 2 ]; then
      firewallallow="yes"
    else
      firewallallow="no"
      firewallOK="no"
      message="ERROR: your firewall is not configured properly (must allow in/out on tun0).
Otherwise you will not be able to send or receive with VPN on."
    fi
    firewallallowout=$(sudo ufw status verbose | grep "${vpnip} ${vpnport}" | grep -c "ALLOW OUT")
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
      message="ERROR: no service exists. Run 'sudo systemctl enable openvpn@plebvpn' on cmd line"
    else
      serviceExists="yes"
    fi
    echo "vpn_operating=${vpnWorking}
current_ip='${currentIP}'
config_exists=${isConfig}
firewall_configured=${firewallOK}
message='${message}'" | tee /mnt/hdd/mynode/pleb-vpn/pleb-vpn_status.tmp
    exit 0
  fi
}

on() {
  # install and configure openvpn
  source ${plebVPNConf}

  # install openvpn
  sudo apt-get -y install openvpn

  # get vpnIP for pleb-vpn.conf
  vpnip=$(cat /mnt/hdd/mynode/pleb-vpn/openvpn/plebvpn.conf | grep remote | sed 's/remote-.*$//g' | cut -d " " -f2)
  vpnport=$(cat /mnt/hdd/mynode/pleb-vpn/openvpn/plebvpn.conf | grep remote | sed 's/remote-.*$//g' | cut -d " " -f3)
  setting ${plebVPNConf} "2" "vpnport" "'${vpnport}'"
  setting ${plebVPNConf} "2" "vpnip" "'${vpnip}'"
  # copy plebvpn.conf to /etc/openvpn
  sudo cp -p /mnt/hdd/mynode/pleb-vpn/openvpn/plebvpn.conf /etc/openvpn/
  # fix permissions
  sudo chown admin:admin /etc/openvpn/plebvpn.conf
  sudo chmod 644 /etc/openvpn/plebvpn.conf
  # enable and start openvpn
  sudo systemctl enable openvpn@plebvpn
  sudo systemctl start openvpn@plebvpn
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
  sudo ufw disable
  # allow local lan ssh
  sudo ufw allow in to ${LAN}.0/24
  sudo ufw allow out to ${LAN}.0/24
  # set default policy (killswitch)
  sudo ufw default deny outgoing
  sudo ufw default deny incoming
  # allow out on openvpn
  sudo ufw allow out to ${vpnip} port ${vpnport} proto udp
  # force traffic to use openvpn
  sudo ufw allow out on tun0 from any to any
  sudo ufw allow in on tun0 from any to any
  # enable firewall
  sudo ufw --force enable
  # add new rules to firewallConf
  sectionLine=$(cat ${firewallConf} | grep -n "^\# Add firewall rules" | cut -d ":" -f1 | head -n 1)
  insertLine=$(expr $sectionLine + 1)
  sed -i "${insertLine}iufw allow in to ${LAN}.0/24" ${firewallConf}
  sed -i "${insertLine}iufw allow out to ${LAN}.0/24" ${firewallConf}
  sed -i "${insertLine}iufw allow out to ${vpnip} port ${vpnport} proto udp" ${firewallConf}
  sed -i "${insertLine}iufw allow out on tun0 from any to any" ${firewallConf}
  sed -i "${insertLine}iufw allow in on tun0 from any to any" ${firewallConf}
  sed -i "s/ufw default allow outgoing/ufw default deny outgoing/g" ${firewallConf}
  setting ${plebVPNConf} "2" "plebvpn" "on"
  echo "OK ... plebvpn installed and configured!"
  exit 0
}

off() {
  # remove and uninstall openvpn
  source ${plebVPNConf}

  # uninstall openvpn
  sudo apt-get -y purge openvpn 
  sudo rm -rf /etc/openvpn
  # configure firewall
  echo "configuring firewall"
  # disable firewall 
  sudo ufw disable
  # set default policy
  sudo ufw default allow outgoing
  sudo ufw default deny incoming
  # remove openvpn rule
  sudo ufw delete allow out to ${vpnip} port ${vpnport} proto udp
  # delete force traffic to use openvpn
  sudo ufw delete allow out on tun0 from any to any
  sudo ufw delete allow in on tun0 from any to any
  # enable firewall
  sudo ufw --force enable
  # add new rules to firewallConf
  LAN=$(ip rou | grep default | cut -d " " -f3 | sed 's/^\(.*\)\.\(.*\)\.\(.*\)\.\(.*\)$/\1\.\2\.\3/g')
  sed -i "/ufw allow in to ${LAN}\.0\/24/d" ${firewallConf}
  sed -i "/ufw allow out to ${LAN}\.0\/24/d" ${firewallConf}
  sed -i "/ufw allow out to ${vpnip} port ${vpnport} proto udp/d" ${firewallConf}
  sed -i "/ufw allow out on tun0 from any to any/d" ${firewallConf}
  sed -i "/ufw allow in on tun0 from any to any/d" ${firewallConf}
  sed -i "s/ufw default deny outgoing/ufw default allow outgoing/g" ${firewallConf}
  setting ${plebVPNConf} "2" "vpnport" "''"
  setting ${plebVPNConf} "2" "vpnip" "''"
  setting ${plebVPNConf} "2" "plebvpn" "off"
  exit 0
}

case "${1}" in
  status) status ;;
  on) on "${2}" ;;
  off) off ;;
  *) echo "err=Unknown action: ${1}" ; exit 1 ;;
esac 
