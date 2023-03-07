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

plebVPNConf="/home/admin/pleb-vpn/pleb-vpn.conf"

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
  source <(/home/admin/_cache.sh get internet_localip)
  currentLAN=$(echo "${internet_localip}" | sed 's/^\(.*\)\.\(.*\)\.\(.*\)\.\(.*\)$/\1\.\2\.\3/g')
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
  source ${plebVPNConf}
  message="Wireguard installed, configured, and operating as expected"
  if [ "${wireguard}" = "off" ]; then
    whiptail --title "WireGuard status" --msgbox "
WireGuard installed: no
Use menu to install wireguard.
" 10 40
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
    if [ "${wgIP}" = "${checkwgIP}" ]; then
      isrunning="yes"
    else
      isrunning="no"
      message="ERROR: not started. Run 'sudo systemctl start wg-quick@wg0' on cmd line"
    fi
    serviceExists=$(ls /etc/systemd/system/multi-user.target.wants/ | grep -c wg-quick@wg0)
    if [ ${serviceExists} -eq 0 ]; then
      serviceExists="no"
      message="ERROR: no service exists. Run 'sudo systemctl enable wg-quick@wg0' on cmd line"
    else
      serviceExists="yes"
    fi
    whiptail --title "WireGuard status" --msgbox "
WireGuard installed: yes
WireGuard operating: ${isrunning}
WireGuard service installed: ${serviceExists}
WireGuard config file found: ${isConfig}
WireGuard server (node) IP: ${wgIP}
WireGuard client 1 (mobile) IP: ${clientIPselect[0]}
WireGuard client 2 (laptop) IP: ${clientIPselect[1]}
WireGuard client 3 (desktop) IP: ${clientIPselect[2]}
${message}
" 16 85
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
    echo "qrencode -t ansiutf8 < /etc/wireguard/clients/mobile.conf"
    echo "##############"
    qrencode -t ansiutf8 < /mnt/hdd/app-data/pleb-vpn/wireguard/clients/mobile.conf
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
  source ${plebVPNConf}
  source /mnt/hdd/raspiblitz.conf

  # check if plebvpn is on
  if ! [ "${plebVPN}" = "on" ]; then
    echo "error: turn on plebvpn before enabling wireguard"
    exit 1
  fi
  # determine if previous config files exist
  local keepconfig="${1}"
  isconfig=$(sudo ls /mnt/hdd/app-data/pleb-vpn/wireguard/ | grep -c wg0.conf)
  if ! [ ${isconfig} -eq 0 ]; then
    if [ -z "${keepconfig}" ]; then
      whiptail --title "Use Existing Configuration?" \
      --yes-button "Use Existing Config" \
      --no-button "Create New Config" \
      --yesno "There's an existing configuration found from a previous install of wireguard. Do you wish to reuse it or to start fresh?" 10 80
      if [ $? -eq 1 ]; then
        keepconfig="0"
      else
        keepconfig="1"
      fi
    fi
  else
    keepconfig="0"
  fi
  # install wireguard
  echo "deb http://deb.debian.org/debian/ unstable main" | sudo tee --append /etc/apt/sources.list
  sudo apt-key adv --keyserver   keyserver.ubuntu.com --recv-keys 04EE7237B7D453EC
  sudo apt-key adv --keyserver   keyserver.ubuntu.com --recv-keys 648ACFD622F3D138
  sudo sh -c 'printf "Package: *\nPin: release a=unstable\nPin-Priority: 90\n" > /etc/apt/preferences.d/limit-unstable'
  sudo apt-get update &> /dev/null
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
    sudo touch /var/cache/raspiblitz/.tmp
    sudo chmod 777 /var/cache/raspiblitz/.tmp
    whiptail --title "Wireguard LAN address" --inputbox "Enter your desired wireguard LAN IP, chosing from 10.0.0.0 to 10.255.255.252. Do not use the same IP as your LAN." 11 83 2>/var/cache/raspiblitz/.tmp
    wgIP=$(cat /var/cache/raspiblitz/.tmp)
    validWgIP ${wgIP}
    while [ ! ${?} -eq 0 ]
    do
      whiptail --title "Wireguard LAN address" --inputbox "ERROR: ${wgIP} is an invalid IP address. Enter your desired wireguard LAN IP, chosing from 10.0.0.0 to 10.255.255.252. Do not use the same IP as your LAN." 11 83 2>/var/cache/raspiblitz/.tmp
      wgIP=$(cat /var/cache/raspiblitz/.tmp)
      validWgIP ${wgIP}
    done
    whiptail --title "Wireguard port" --inputbox "Enter the port that is forwarded to you from the VPS for wireguard. If you don't have one, forward one from your VPS or contact your VPS provider to obtain one." 12 80 2>/var/cache/raspiblitz/.tmp
    wgPort=$(cat /var/cache/raspiblitz/.tmp)
    # check to make sure port isn't already used by LND or CLN
    if [ "${wgPort}" = "${lnPort}" ] || [ "${wgPort}" = "${CLNPort}" ]; then
      whiptail --title "Wireguard port" --inputbox "ERROR: You must not use the same port as a previous service. Enter a different port than ${wgPort}." 12 80 2>/var/cache/raspiblitz/.tmp
      wgPort=$(cat /var/cache/raspiblitz/.tmp)
      if [ "${wgPort}" = "${lnPort}" ] || [ "${wgPort}" = "${CLNPort}" ]; then
        echo "error: port must be different than other services"
        exit 1
      fi
    fi
    # add wireguard LAN to pleb-vpn.conf 
    setting ${plebVPNConf} "2" "wgPort" "'${wgPort}'"
    wgLAN=$(echo "${wgIP}" | sed 's/^\(.*\)\.\(.*\)\.\(.*\)\.\(.*\)$/\1\.\2\.\3/')
    serverHost=$(echo "${wgIP}" | cut -d "." -f4)
    client1Host=$(expr $serverHost + 1)
    client2Host=$(expr $serverHost + 2)
    client3Host=$(expr $serverHost + 3)
    client1ip=$(echo "${wgLAN}.${client1Host}")
    client2ip=$(echo "${wgLAN}.${client2Host}")
    client3ip=$(echo "${wgLAN}.${client3Host}")
    # add wireguard LAN to pleb-vpn.conf 
    setting ${plebVPNConf} "2" "wgLAN" "'${wgLAN}'"
    setting ${plebVPNConf} "2" "wgIP" "'${wgIP}'"
    # create config files
    echo "[Interface]
Address = ${wgIP}/24
PrivateKey = ${serverPrivateKey}
ListenPort = ${wgPort}

PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

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
Endpoint = ${vpnIP}:${wgPort}
AllowedIPs = ${wgLAN}.0/24, ${LAN}.0/24
" | sudo tee /etc/wireguard/clients/mobile.conf
    echo "[Interface]
Address = ${client2ip}/32
PrivateKey = ${client2PrivateKey}

[Peer]
PublicKey = ${serverPublicKey}
Endpoint = ${vpnIP}:${wgPort}
AllowedIPs = ${wgLAN}.0/24, ${LAN}.0/24
" | sudo tee /etc/wireguard/clients/laptop.conf
    echo "[Interface]
Address = ${client3ip}/32
PrivateKey = ${client3PrivateKey}

[Peer]
PublicKey = ${serverPublicKey}
Endpoint = ${vpnIP}:${wgPort}
AllowedIPs = ${wgLAN}.0/24, ${LAN}.0/24
" | sudo tee /etc/wireguard/clients/desktop.conf
    playstorelink="https://play.google.com/store/apps/details?id=com.wireguard.android"
    appstorelink="https://apps.apple.com/us/app/wireguard/id1441195209"
    whiptail --title "Install Wireguard on your Phone" \
		--yes-button "Continue" \
		--no-button "StoreLink" \
		--yesno "Open the Android Play Store or Apple App Store on your mobile phone.\n\nSearch for --> 'WireGuard'\n\nWhen app is installed and started --> Continue." 12 65
	  if [ $? -eq 1 ]; then
		whiptail --title " App Store Link " --msgbox "\
To install app on android open the following link:\n
${playstoreLink}\n
To install app on iphone open the following link:\n
${appstoreLink}\n
" 12 70
	  fi
    # copy keys and config
    sudo rm -rf /mnt/hdd/app-data/pleb-vpn/wireguard
    sudo cp -p -r /etc/wireguard/ /mnt/hdd/app-data/pleb-vpn/
    sudo chmod -R 755 /mnt/hdd/app-data/pleb-vpn/wireguard
    # show QR code for mobile config
    echo "##############"
    echo "qrencode -t ansiutf8 < /etc/wireguard/clients/mobile.conf"
    echo "##############"
    qrencode -t ansiutf8 < /mnt/hdd/app-data/pleb-vpn/wireguard/clients/mobile.conf
    echo "Press ENTER when finished."
    read key
  else
    # update pleb-vpn.conf
    wgIP=$(cat /mnt/hdd/app-data/pleb-vpn/wireguard/wg0.conf | grep Address | sed 's/^.* = //' | sed 's/^\(.*\)\/\(.*\)$/\1/')
    wgLAN=$(echo "${wgIP}" | sed 's/^\(.*\)\.\(.*\)\.\(.*\)\.\(.*\)$/\1\.\2\.\3/')
    wgPort=$(cat /mnt/hdd/app-data/pleb-vpn/wireguard/wg0.conf | grep ListenPort | sed 's/^.* = //')
    setting ${plebVPNConf} "2" "wgPort" "'${wgPort}'"
    setting ${plebVPNConf} "2" "wgLAN" "'${wgLAN}'"
    setting ${plebVPNConf} "2" "wgIP" "'${wgIP}'"
    # copy keys and config  
    sudo cp -p -r /mnt/hdd/app-data/pleb-vpn/wireguard/ /etc/
  fi
  # open firewall ports
  sudo ufw allow ${wgPort}/udp comment "wireguard port"
  sudo ufw allow out on wg0 from any to any
  sudo ufw allow in on wg0 from any to any
  sudo ufw allow in to ${wgLAN}.0/24
  sudo ufw allow out to ${wgLAN}.0/24
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
  # add tlsextraip to lnd.conf and recreate tls.cert (if lnd installed)
  if [ "${keepconfig}" = "0" ]; then
    if [ "${lnd}" = "on" ]; then
      source <(/home/admin/config.scripts/network.aliases.sh getvars lnd)
      sectionName="Application Options"
      echo "# [${sectionName}] config ..."
      sectionLine=$(cat ${lndConfFile} | grep -n "^\[${sectionName}\]" | cut -d ":" -f1)
      echo "# sectionLine(${sectionLine})"
      insertLine=$(expr $sectionLine + 1)
      echo "# insertLine(${insertLine})"
      fileLines=$(wc -l ${lndConfFile} | cut -d " " -f1)
      echo "# fileLines(${fileLines})"
      if [ ${fileLines} -lt ${insertLine} ]; then
        echo "# adding new line for inserts"
        echo "
      " | tee -a ${lndConfFile}
      fi
      echo "# sectionLine(${sectionLine})"
      setting ${lndConfFile} ${insertLine} "tlsextraip" "${wgIP}"
      # remove old tls.cert and tls.key
      sudo rm /mnt/hdd/lnd/*.old
      sudo mv /mnt/hdd/lnd/tls.cert /mnt/hdd/lnd/tls.cert.old
      sudo mv /mnt/hdd/lnd/tls.key /mnt/hdd/lnd/tls.key.old
      # restart lnd
      sudo systemctl restart lnd
      if [ "${autoUnlock}" = "on" ]; then
        # wait until wallet unlocked
        echo "waiting for wallet unlock (takes some time)..."
        sleep 30
      else
        # prompt user to unlock wallet
        /home/admin/config.scripts/lnd.unlock.sh
        echo "waiting for wallet unlock (takes some time)..."
        sleep 50
      fi
      # restart nginx
      sudo systemctl restart nginx
    fi
  fi
  # set wireguard on in pleb-vpn.conf
  setting ${plebVPNConf} "2" "wireguard" "on"
  exit 0
}

off() {
  # uninstall wireguard
  source ${plebVPNConf}

  # disable service
  sudo systemctl disable wg-quick@wg0
  sudo systemctl stop wg-quick@wg0
  # uninstall wireguard
  sudo apt purge -y wireguard
  # close firewall ports
  sudo ufw delete allow ${wgPort}/udp
  sudo ufw delete allow out on wg0 from any to any
  sudo ufw delete allow in on wg0 from any to any
  sudo ufw delete allow in to ${wgLAN}.0/24
  sudo ufw delete allow out to ${wgLAN}.0/24
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
