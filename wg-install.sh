#!/bin/bash

# install and configure wireguard
# to install and automatically keep current config
# use "wg-install.sh on 1"

# command info
if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "-help" ]; then
  echo "config script to install, configure, get config files, or uninstall wireguard"
  echo "wg-install.sh [on|off|status|connect]"
  exit 1
fi

plebVPNConf="/mnt/hdd/mynode/pleb-vpn/pleb-vpn.conf"
sed '1d' $plebVPNConf > pleb-vpn.conf.tmp
plebVPNConf="/mnt/hdd/mynode/pleb-vpn/pleb-vpn.conf.tmp"
source ${plebVPNConf}
sudo rm ${plebVPNConf}
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
    sudo sed -i --follow-symlinks "${LINENUMBER}i${NAME}=" ${FILE}
  fi
  echo "# updating setting (${NAME}) with value(${VALUE})"
  sudo sed -i --follow-symlinks "s/^${NAME}=.*/${NAME}=${VALUE}/g" ${FILE}
}

function validWgIP() {
  currentLAN=$(ip rou | grep default | cut -d " " -f3 | sed 's/^\(.*\)\.\(.*\)\.\(.*\)\.\(.*\)$/\1\.\2\.\3/g')
  local ip=$1
  currentWGLAN=$(echo "${ip}" | sed 's/^\(.*\)\.\(.*\)\.\(.*\)\.\(.*\)$/\1\.\2\.\3/g')
  local stat=1
  if [ ! "${currentLAN}" = "${currentWGLAN}" ]; then
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
      OIFS=$IFS
      IFS='.'
      ip=($ip)
      IFS=$OIFS
      [[ ${ip[0]} -eq 10 && ${ip[1]} -le 255 &&
        ${ip[2]} -le 255 && ${ip[3]} -le 252 ]]
      stat=$?
    fi
  fi
  return $stat
}

status() {
  message="Wireguard installed, configured, and operating as expected"
  if [ "${wireguard}" = "off" ]; then
    message="Wireguard not installed. Install wireguard in the services menu."
    if [ -d "/mnt/hdd/mynode/pleb-vpn/wireguard" ]; then
      isConfig=$(sudo ls /mnt/hdd/mynode/pleb-vpn/wireguard | grep -c wg0.conf)
    else
      isConfig=0
    fi
    if [ ${isConfig} -eq 0 ]; then
      isConfig="no"
    else
      isConfig="yes"
    echo "installed=no
config_file_found=${isConfig}
message=${message}" | tee /mnt/hdd/mynode/pleb-vpn/wireguard_status.tmp
    fi
  else
    checkwgIP=$(ip addr | grep wg0 | grep inet | cut -d " " -f6 | cut -d "/" -f1)
    isConfig=$(sudo ls /etc/wireguard | grep -c wg0.conf)
    if [ ${isConfig} -eq 0 ]; then
      isConfig="no"
      clientIPs="error: no wg0.conf file found in /etc/wireguard"
      clientIPselect=()
      clientIPselect+=${clientIPs}
      message="ERROR: no wg0.conf file found. Uninstall and reinstall WireGuard using the menu."
    else
      isConfig="yes"
      clientIPs=$(sudo cat /etc/wireguard/wg0.conf | grep AllowedIPs | cut -d " " -f3 | cut -d "/" -f1)
      clientIPselect=($clientIPs)
    fi
    if [ "${wgip}" = "${checkwgIP}" ]; then
      isrunning="yes"
    else
      isrunning="no"
      message="ERROR: not started. Run 'sudo systemctl enable --now wg-quick@wg0' on cmd line"
    fi
    serviceExists=$(ls /etc/systemd/system/multi-user.target.wants/ | grep -c wg-quick@wg0)
    if [ ${serviceExists} -eq 0 ]; then
      serviceExists="no"
      message="ERROR: no service exists. Run 'sudo systemctl enable --now wg-quick@wg0' on cmd line"
    else
      serviceExists="yes"
    fi
    echo "installed=yes
operating=${isrunning}
service_installed=${serviceExists}
config_file_found=${isConfig}
server_IP=${wgip}
client1_IP=${clientIPselect[0]}
client2_IP=${clientIPselect[1]}
client3_IP=${clientIPselect[2]}
message=${message}" | tee /mnt/hdd/mynode/pleb-vpn/wireguard_status.tmp
  fi
  exit 0
}

connect() {
  whiptail --title "QR code for mobile?" \
  --yes-button "QR code" \
  --no-button "Download" \
  --yesno "The wireguard install comes with three clients already configured.
If you want to connect your mobile device, the QR code is the easiest. 
If you want to connect a laptop or desktop (or additional mobile devices),
download all three config files by chosing 'Download'" 12 80
  if [ ${?} -eq 0 ]; then
    clear
    echo "##############"
    echo "qrencode -t ansiutf8 < /etc/wireguard/clients/client1.conf"
    echo "##############"
    qrencode -t ansiutf8 < /mnt/hdd/app-data/pleb-vpn/wireguard/clients/client1.conf
    echo "Press ENTER when finished."
    read key
  else
    source <(/home/admin/config.scripts/internet.sh status local)
    clear
    echo "***************************************"
    echo "* DOWNLOAD THE WIREGUARD CLIENT FILES *"
    echo "***************************************"
    echo
    echo "To download, open a new terminal on your computer, and"
    echo "COPY, PASTE AND EXECUTE THE FOLLOWING COMMAND:"
    echo "scp -r admin@${localip}:/mnt/hdd/app-data/pleb-vpn/wireguard/clients/ ."
    echo "Don't forget the . at the end of the command."
    echo
    echo "Use your password A to authenticate file transfer."
    echo "Your client config files will be in your current folder on your computer."
    echo "You should receive three files in the 'clients' folder:"
    echo "mobile.conf, laptop.conf, and desktop.conf. Any conf file can be used with"
    echo "any wireguard client, they're just named that for convenience. The mobile.conf"
    echo "client is the one available via QR Code from the menu, so if it's in use with"
    echo "a device already, don't reuse it with another device."
    echo "PRESS ENTER when download is done."
    read key
  fi
  exit 0
}

on() {
  # install and configure wireguard
  local new_config="${1}"

  # check if plebvpn is on
  if ! [ "${plebvpn}" = "on" ]; then
    echo "error: turn on plebvpn before enabling wireguard"
    exit 1
  fi
  # check if this is a new wireguard config
  if [ ! -z "${new_config}" ]; then
    keepconfig="0"
  else
    # determine if config files exist
    isconfig=$(sudo ls /mnt/hdd/mynode/pleb-vpn/wireguard/ | grep -c wg0.conf)
    if [ ${isconfig} -eq 0 ]; then
      echo "error: no config file found"
      exit 10
    fi
    keepconfig="1"
  fi
  # install wireguard
  sudo apt install -y wireguard

  if [ "${keepconfig}" = "0" ]; then
    # configure wireguard keys
    sudo chmod -R 777 /etc/wireguard
    sudo wg genkey | sudo tee /etc/wireguard/server_private_key | wg pubkey > /etc/wireguard/server_public_key
    serverPrivateKey=$(sudo cat /etc/wireguard/server_private_key)
    serverPublicKey=$(sudo cat /etc/wireguard/server_public_key)
    sudo wg genkey | sudo tee /etc/wireguard/client1_private_key | wg pubkey > /etc/wireguard/client1_public_key
    client1PrivateKey=$(sudo cat /etc/wireguard/client1_private_key)
    client1PublicKey=$(sudo cat /etc/wireguard/client1_public_key)
    sudo wg genkey | sudo tee /etc/wireguard/client2_private_key | wg pubkey > /etc/wireguard/client2_public_key
    client2PrivateKey=$(sudo cat /etc/wireguard/client2_private_key)
    client2PublicKey=$(sudo cat /etc/wireguard/client2_public_key)
    sudo wg genkey | sudo tee /etc/wireguard/client3_private_key | wg pubkey > /etc/wireguard/client3_public_key
    client3PrivateKey=$(sudo cat /etc/wireguard/client3_private_key)
    client3PublicKey=$(sudo cat /etc/wireguard/client3_public_key)
    wglan=$(echo "${wgip}" | sed 's/^\(.*\)\.\(.*\)\.\(.*\)\.\(.*\)$/\1\.\2\.\3/')
    serverHost=$(echo "${wgip}" | cut -d "." -f4)
    client1Host=$(expr $serverHost + 1)
    client2Host=$(expr $serverHost + 2)
    client3Host=$(expr $serverHost + 3)
    client1ip=$(echo "${wglan}.${client1Host}")
    client2ip=$(echo "${wglan}.${client2Host}")
    client3ip=$(echo "${wglan}.${client3Host}")
    internet_controller=$(ip rou | grep default | cut -d " " -f5)
    LAN=$(ip rou | grep default | cut -d " " -f3 | sed 's/^\(.*\)\.\(.*\)\.\(.*\)\.\(.*\)$/\1\.\2\.\3/g')
    # add wireguard LAN to pleb-vpn.conf 
    setting ${plebVPNConf} "2" "wglan" "'${wglan}'"
    # create config files
    echo "[Interface]
Address = ${wgip}/24
PrivateKey = ${serverPrivateKey}
ListenPort = ${wgport}

PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -t nat -A POSTROUTING -o ${internet_controller} -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -t nat -D POSTROUTING -o ${internet_controller} -j MASQUERADE

[Peer]
PublicKey = ${client1PublicKey}
AllowedIPs = ${client1ip}/32

[Peer]
PublicKey = ${client2PublicKey}
AllowedIPs = ${client2ip}/32

[Peer]
PublicKey = ${client3PublicKey}
AllowedIPs = ${client3ip}/32
" | sudo tee /etc/wireguard/wg0.conf
    # configure client
    sudo mkdir /etc/wireguard/clients
    echo "[Interface]
Address = ${client1ip}/32
PrivateKey = ${client1PrivateKey}

[Peer]
PublicKey = ${serverPublicKey}
Endpoint = ${vpnip}:${wgport}
AllowedIPs = ${wglan}.0/24, ${LAN}.0/24
" | sudo tee /etc/wireguard/clients/client1.conf
    echo "[Interface]
Address = ${client2ip}/32
PrivateKey = ${client2PrivateKey}

[Peer]
PublicKey = ${serverPublicKey}
Endpoint = ${vpnip}:${wgport}
AllowedIPs = ${wglan}.0/24, ${LAN}.0/24
" | sudo tee /etc/wireguard/clients/client2.conf
    echo "[Interface]
Address = ${client3ip}/32
PrivateKey = ${client3PrivateKey}

[Peer]
PublicKey = ${serverPublicKey}
Endpoint = ${vpnip}:${wgport}
AllowedIPs = ${wglan}.0/24, ${LAN}.0/24
" | sudo tee /etc/wireguard/clients/client3.conf

    # copy keys and config
    sudo rm -rf /mnt/hdd/mynode/pleb-vpn/wireguard
    sudo cp -p -r /etc/wireguard/ /mnt/hdd/mynode/pleb-vpn/
    sudo chown -R admin:admin /mnt/hdd/mynode/pleb-vpn/wireguard
    sudo chmod -R 755 /mnt/hdd/mynode/pleb-vpn/wireguard
  else
    # update pleb-vpn.conf
    wgip=$(cat /mnt/hdd/mynode/pleb-vpn/wireguard/wg0.conf | grep Address | sed 's/^.* = //' | sed 's/^\(.*\)\/\(.*\)$/\1/')
    wglan=$(echo "${wgip}" | sed 's/^\(.*\)\.\(.*\)\.\(.*\)\.\(.*\)$/\1\.\2\.\3/')
    wgport=$(cat /mnt/hdd/mynode/pleb-vpn/wireguard/wg0.conf | grep ListenPort | sed 's/^.* = //')
    setting ${plebVPNConf} "2" "wgport" "'${wgport}'"
    setting ${plebVPNConf} "2" "wglan" "'${wglan}'"
    setting ${plebVPNConf} "2" "wgip" "'${wgip}'"
    # copy keys and config  
    sudo cp -p -r /mnt/hdd/mynode/pleb-vpn/wireguard/ /etc/
  fi
  # open firewall ports
  sudo ufw allow ${wgport}/udp comment "wireguard port"
  sudo ufw allow out on wg0 from any to any
  sudo ufw allow in on wg0 from any to any
  sudo ufw allow in to ${wglan}.0/24
  sudo ufw allow out to ${wglan}.0/24
  # add new rules to firewallConf
  sectionLine=$(cat ${firewallConf} | grep -n "^\# Add firewall rules" | cut -d ":" -f1 | head -n 1)
  insertLine=$(expr $sectionLine + 1)
  sed -i "${insertLine}iufw allow ${wgport}/udp comment 'wireguard port'" ${firewallConf}
  sed -i "${insertLine}iufw allow out on wg0 from any to any" ${firewallConf}
  sed -i "${insertLine}iufw allow in on wg0 from any to any" ${firewallConf}
  sed -i "${insertLine}iufw allow in to ${wglan}.0/24" ${firewallConf}
  sed -i "${insertLine}iufw allow out to ${wglan}.0/24" ${firewallConf}
  # enable ip forward
  sudo sed -i '/net.ipv4.ip_forward/ s/#//' /etc/sysctl.conf
  # enable systemd and fix permissions
  sudo systemctl enable wg-quick@wg0
  sudo systemctl start wg-quick@wg0
  sudo chown -R root:root /etc/wireguard/
  sudo chmod -R 755 /etc/wireguard/
  # start wireguard
  echo "Ok, wireguard installed and configured. Wait 10 seconds before enable..."
  sleep 10
  sudo systemctl restart wg-quick@wg0

  # set wireguard on in pleb-vpn.conf
  setting ${plebVPNConf} "2" "wireguard" "on"
  exit 0
}

off() {
  # uninstall wireguard

  # disable service
  sudo systemctl disable wg-quick@wg0
  sudo systemctl stop wg-quick@wg0
  # uninstall wireguard
  sudo apt purge -y wireguard
  # close firewall ports
  sudo ufw delete allow ${wgport}/udp
  sudo ufw delete allow out on wg0 from any to any
  sudo ufw delete allow in on wg0 from any to any
  sudo ufw delete allow in to ${wglan}.0/24
  sudo ufw delete allow out to ${wglan}.0/24
  # remove from firewallConf
  sed -i "/ufw allow ${wgport}.*/d" ${firewallConf}
  sed -i "/ufw allow out on wg0 from any to any/d" ${firewallConf}
  sed -i "/ufw allow in on wg0 from any to any/d" ${firewallConf}
  sed -i "/ufw allow in to ${wglan}\.0\/24/d" ${firewallConf}
  sed -i "/ufw allow out to ${wglan}\.0\/24/d" ${firewallConf}
  # set wireguard off in pleb-vpn.conf
  setting ${plebVPNConf} "2" "wireguard" "off"
  exit 0
}

case "${1}" in
  status) status ;;
  connect) connect ;;
  on) on "${2}" ;;
  off) off ;;
  *) echo "err=Unknown action: ${1}" ; exit 1 ;;
esac 
