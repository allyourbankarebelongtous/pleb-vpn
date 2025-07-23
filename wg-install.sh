#!/bin/bash

# install and configure wireguard
# to install and automatically keep current config
# use "wg-install.sh on 1"

# find home directory based on node implementation
if [ -d "/mnt/hdd/mynode/pleb-vpn/" ]; then
  homedir="/mnt/hdd/mynode/pleb-vpn"
  execdir="/opt/mynode/pleb-vpn"
  firewallConf="/usr/bin/mynode_firewall.sh"
  lndCustomConf="/mnt/hdd/mynode/settings/lnd_custom.conf"
elif [ -f "/mnt/hdd/raspiblitz.conf" ] || [ -f "/mnt/hdd/app-data/raspiblitz.conf" ]; then
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
  local webui="${1}"
  message="Wireguard installed, configured, and operating as expected"
  if [ "${wireguard}" = "off" ]; then
    message="Wireguard not installed. Install wireguard in the services menu."
    if [ -d "${homedir}/wireguard" ]; then
      isConfig=$(ls ${homedir}/wireguard | grep -c wg0.conf)
    else
      isConfig="0"
    fi
    if [ ${isConfig} -eq 0 ]; then
      isConfig="no"
    else
      isConfig="yes"
    fi
    if [ "${webui}" = "1" ]; then
      echo "installed=no
config_file_found=${isConfig}
message=${message}" | tee ${execdir}/wireguard_status.tmp
    else
      whiptail --title "WireGuard status" --msgbox "
WireGuard installed: no
Use menu to install wireguard.
" 10 40
    fi
  else
    checkwgIP=$(ip addr | grep wg0 | grep inet | cut -d " " -f6 | cut -d "/" -f1)
    isConfig=$(ls /etc/wireguard | grep -c wg0.conf)
    if [ ${isConfig} -eq 0 ]; then
      isConfig="no"
      clientIPs="error: no wg0.conf file found in /etc/wireguard"
      clientIPselect=()
      clientIPselect+=${clientIPs}
      message="ERROR: no wg0.conf file found. Uninstall and reinstall WireGuard using the menu."
    else
      isConfig="yes"
      clientIPs=$(cat /etc/wireguard/wg0.conf | grep AllowedIPs | cut -d " " -f3 | cut -d "/" -f1)
      clientIPselect=($clientIPs)
    fi
    if [ "${wgip}" = "${checkwgIP}" ]; then
      isrunning="yes"
    else
      isrunning="no"
      message="ERROR: not started. Run 'systemctl enable --now wg-quick@wg0' on cmd line"
    fi
    serviceExists=$(ls /etc/systemd/system/multi-user.target.wants/ | grep -c wg-quick@wg0)
    if [ ${serviceExists} -eq 0 ]; then
      serviceExists="no"
      message="ERROR: no service exists. Run 'systemctl enable --now wg-quick@wg0' on cmd line"
    else
      serviceExists="yes"
    fi
    if [ "${webui}" = "1" ]; then
      echo "installed=yes
operating=${isrunning}
service_installed=${serviceExists}
config_file_found=${isConfig}
server_IP=${wgip}
client1_IP=${clientIPselect[0]}
client2_IP=${clientIPselect[1]}
client3_IP=${clientIPselect[2]}
message=${message}" | tee ${execdir}/wireguard_status.tmp
    else
      whiptail --title "WireGuard status" --msgbox "
WireGuard installed: yes
WireGuard operating: ${isrunning}
WireGuard service installed: ${serviceExists}
WireGuard config file found: ${isConfig}
WireGuard server (node) IP: ${wgip}
WireGuard client 1 (mobile) IP: ${clientIPselect[0]}
WireGuard client 2 (laptop) IP: ${clientIPselect[1]}
WireGuard client 3 (desktop) IP: ${clientIPselect[2]}
${message}
" 16 85
    fi
  fi
  exit 0
}

connect() {
  if [ "${nodetype}" = "raspiblitz" ]; then
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
      qrencode -t ansiutf8 < ${homedir}/wireguard/clients/client1.conf
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
      echo "scp -r admin@${localip}:${homedir}/wireguard/clients/ ."
      echo "Don't forget the . at the end of the command."
      echo
      echo "Use your password A to authenticate file transfer."
      echo "Your client config files will be in your current folder on your computer."
      echo "You should receive three files in the 'clients' folder:"
      echo "client1.conf, client2.conf, and client3.conf. Any conf file can be used with"
      echo "any wireguard client, they're just named that for convenience. The client1.conf"
      echo "client is the one available via QR Code from the menu, so if it's in use with"
      echo "a device already, don't reuse it with another device."
      echo "PRESS ENTER when download is done."
      read key
    fi
  fi
  exit 0
}

on() {
  # install and configure wireguard
  local keepconfig="${1}"
  local new_config="${2}"
  local webui="${3}"

  # check if plebvpn is on
  if ! [ "${plebvpn}" = "on" ]; then
    echo "error: turn on plebvpn before enabling wireguard"
    exit 1
  fi
  # check if this is a new wireguard config
  if [ "${new_config}" = "1" ]; then
    keepconfig="0"
  else
    isconfig=$(ls ${homedir}/wireguard/ | grep -c wg0.conf)
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
  fi

  # install wireguard
  apt install -y wireguard

  if [ "${keepconfig}" = "0" ]; then
    # configure wireguard keys
    chmod -R 777 /etc/wireguard
    wg genkey | tee /etc/wireguard/server_private_key | wg pubkey > /etc/wireguard/server_public_key
    serverPrivateKey=$(cat /etc/wireguard/server_private_key)
    serverPublicKey=$(cat /etc/wireguard/server_public_key)
    wg genkey | tee /etc/wireguard/client1_private_key | wg pubkey > /etc/wireguard/client1_public_key
    client1PrivateKey=$(cat /etc/wireguard/client1_private_key)
    client1PublicKey=$(cat /etc/wireguard/client1_public_key)
    wg genkey | tee /etc/wireguard/client2_private_key | wg pubkey > /etc/wireguard/client2_public_key
    client2PrivateKey=$(cat /etc/wireguard/client2_private_key)
    client2PublicKey=$(cat /etc/wireguard/client2_public_key)
    wg genkey | tee /etc/wireguard/client3_private_key | wg pubkey > /etc/wireguard/client3_public_key
    client3PrivateKey=$(cat /etc/wireguard/client3_private_key)
    client3PublicKey=$(cat /etc/wireguard/client3_public_key)
    if [ ! "${webui}" = "1" ]; then
      if [ "${nodetype}" = "raspiblitz" ]; then
        touch /var/cache/raspiblitz/.tmp
        chmod 777 /var/cache/raspiblitz/.tmp
        whiptail --title "Wireguard LAN address" --inputbox "Enter your desired wireguard LAN IP, chosing from 10.0.0.0 to 10.255.255.252. Do not use the same IP as your LAN." 11 83 2>/var/cache/raspiblitz/.tmp
        wgip=$(cat /var/cache/raspiblitz/.tmp)
        validWgIP ${wgip}
        while [ ! ${?} -eq 0 ]
        do
          whiptail --title "Wireguard LAN address" --inputbox "ERROR: ${wgip} is an invalid IP address. Enter your desired wireguard LAN IP, chosing from 10.0.0.0 to 10.255.255.252. Do not use the same IP as your LAN." 11 83 2>/var/cache/raspiblitz/.tmp
          wgip=$(cat /var/cache/raspiblitz/.tmp)
          validWgIP ${wgip}
        done
        whiptail --title "Wireguard port" --inputbox "Enter the port that is forwarded to you from the VPS for wireguard. If you don't have one, forward one from your VPS or contact your VPS provider to obtain one." 12 80 2>/var/cache/raspiblitz/.tmp
        wgport=$(cat /var/cache/raspiblitz/.tmp)
        # check to make sure port isn't already used by LND or CLN
        if [ "${wgport}" = "${lnport}" ] || [ "${wgport}" = "${clnport}" ]; then
          whiptail --title "Wireguard port" --inputbox "ERROR: You must not use the same port as a previous service. Enter a different port than ${wgPort}." 12 80 2>/var/cache/raspiblitz/.tmp
          wgport=$(cat /var/cache/raspiblitz/.tmp)
          if [ "${wgport}" = "${lnport}" ] || [ "${wgport}" = "${clnport}" ]; then
            echo "error: port must be different than other services"
            exit 1
          fi
        fi
        setting ${plebVPNConf} "2" "wgport" "'${wgport}'"
        setting ${plebVPNConf} "2" "wgip" "'${wgip}'"
      fi
    fi
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
" | tee /etc/wireguard/wg0.conf
    # configure client
    mkdir /etc/wireguard/clients
    echo "[Interface]
Address = ${client1ip}/32
PrivateKey = ${client1PrivateKey}

[Peer]
PublicKey = ${serverPublicKey}
Endpoint = ${vpnip}:${wgport}
AllowedIPs = ${wglan}.0/24, ${LAN}.0/24
" | tee /etc/wireguard/clients/client1.conf
    echo "[Interface]
Address = ${client2ip}/32
PrivateKey = ${client2PrivateKey}

[Peer]
PublicKey = ${serverPublicKey}
Endpoint = ${vpnip}:${wgport}
AllowedIPs = ${wglan}.0/24, ${LAN}.0/24
" | tee /etc/wireguard/clients/client2.conf
    echo "[Interface]
Address = ${client3ip}/32
PrivateKey = ${client3PrivateKey}

[Peer]
PublicKey = ${serverPublicKey}
Endpoint = ${vpnip}:${wgport}
AllowedIPs = ${wglan}.0/24, ${LAN}.0/24
" | tee /etc/wireguard/clients/client3.conf

    if [ ! "${webui}" = "1" ]; then
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
    fi

    # copy keys and config
    rm -rf ${homedir}/wireguard
    cp -p -r /etc/wireguard/ ${homedir}/
    chown -R admin:admin ${homedir}/wireguard
    chmod -R 755 ${homedir}/wireguard

  else
    # update pleb-vpn.conf
    wgip=$(cat ${homedir}/wireguard/wg0.conf | grep Address | sed 's/^.* = //' | sed 's/^\(.*\)\/\(.*\)$/\1/')
    wglan=$(echo "${wgip}" | sed 's/^\(.*\)\.\(.*\)\.\(.*\)\.\(.*\)$/\1\.\2\.\3/')
    wgport=$(cat ${homedir}/wireguard/wg0.conf | grep ListenPort | sed 's/^.* = //')
    setting ${plebVPNConf} "2" "wgport" "'${wgport}'"
    setting ${plebVPNConf} "2" "wglan" "'${wglan}'"
    setting ${plebVPNConf} "2" "wgip" "'${wgip}'"
    # copy keys and config  
    cp -p -r ${homedir}/wireguard/ /etc/
  fi

  # open firewall ports
  ufw allow ${wgport}/udp comment "wireguard port"
  ufw allow out on wg0 from any to any
  ufw allow in on wg0 from any to any
  ufw allow in to ${wglan}.0/24
  ufw allow out to ${wglan}.0/24

  if [ "${nodetype}" = "mynode" ]; then
  # add new rules to firewallConf
    sectionLine=$(cat ${firewallConf} | grep -n "^\# Add firewall rules" | cut -d ":" -f1 | head -n 1)
    insertLine=$(expr $sectionLine + 1)
    sed -i "${insertLine}iufw allow ${wgport}/udp comment 'wireguard port'" ${firewallConf}
    sed -i "${insertLine}iufw allow out on wg0 from any to any" ${firewallConf}
    sed -i "${insertLine}iufw allow in on wg0 from any to any" ${firewallConf}
    sed -i "${insertLine}iufw allow in to ${wglan}.0/24" ${firewallConf}
    sed -i "${insertLine}iufw allow out to ${wglan}.0/24" ${firewallConf}
  fi

  # enable ip forward
  sed -i '/net.ipv4.ip_forward/ s/#//' /etc/sysctl.conf
  # enable systemd and fix permissions
  systemctl enable wg-quick@wg0
  systemctl start wg-quick@wg0
  chown -R root:root /etc/wireguard/
  chmod -R 755 /etc/wireguard/
  # start wireguard
  echo "Ok, wireguard installed and configured. Wait 10 seconds before enable..."
  sleep 10
  systemctl restart wg-quick@wg0

  # add wgip to lnd.conf for tls.cert and pick up new tls.cert
  if [ "${nodetype}" = "raspiblitz" ]; then
    if [ "${keepconfig}" = "0" ]; then
      if [ -f "/mnt/hdd/raspiblitz.conf" ]; then
        source /mnt/hdd/raspiblitz.conf
      elif [ -f "/mnt/hdd/app-data/raspiblitz.conf" ]; then
        source /mnt/hdd/app-data/raspiblitz.conf
      fi
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
        setting ${lndConfFile} ${insertLine} "tlsextraip" "${wgip}"
        # remove old tls.cert and tls.key
        rm /mnt/hdd/lnd/tls*
        # restart lnd
        systemctl restart lnd
        if [ "${autoUnlock}" = "on" ]; then
          # wait until wallet unlocked
          echo "waiting for wallet unlock (takes some time)..."
          sleep 5
        else
          # prompt user to unlock wallet
          /home/admin/config.scripts/lnd.unlock.sh
          echo "waiting for wallet unlock (takes some time)..."
          sleep 5
        fi
        # restart nginx
        systemctl restart nginx
        sleep 5
      fi
    fi
  elif [ "${nodetype}" = "mynode" ]; then
    if [ "${keepconfig}" = "0" ]; then
      if [ "${lndhybrid}" = "on" ]; then
        sectionName="Application Options"
        publicIP="${vpnip}"
        echo "# [${sectionName}] config ..."
        sectionLine=$(cat ${lndCustomConf} | grep -n "^\[${sectionName}\]" | cut -d ":" -f1 | head -n 1)
        echo "# sectionLine(${sectionLine})"
        insertLine=$(expr $sectionLine + 1)
        echo "# insertLine(${insertLine})"
        fileLines=$(wc -l ${lndCustomConf} | cut -d " " -f1)
        echo "# fileLines(${fileLines})"
        if [ ${fileLines} -lt ${insertLine} ]; then
          echo "# adding new line for inserts"
          echo "
        " | tee -a ${lndCustomConf}
        fi
        echo "# sectionLine(${sectionLine})"
        setting ${lndCustomConf} ${insertLine} "tlsextraip" "${wgip}"
        # remove old tls.cert and tls.key
        rm /mnt/hdd/mynode/lnd/tls*
        # restart lnd
        systemctl restart lnd
        sleep 5
        # restart nginx
        systemctl restart nginx
        sleep 5
      fi
    fi
  fi

  # set wireguard on in pleb-vpn.conf
  setting ${plebVPNConf} "2" "wireguard" "on"
  exit 0
}

off() {
  # uninstall wireguard

  # disable service
  systemctl disable wg-quick@wg0
  systemctl stop wg-quick@wg0
  apt purge -y wireguard
  # close firewall ports
  ufw delete allow ${wgport}/udp
  ufw delete allow out on wg0 from any to any
  ufw delete allow in on wg0 from any to any
  ufw delete allow in to ${wglan}.0/24
  ufw delete allow out to ${wglan}.0/24
  if [ "${nodetype}" = "mynode" ]; then
  # remove from firewallConf
    while [ $(cat ${firewallConf} | grep -c "ufw allow ${wgport}") -gt 0 ];
    do
      sed -i "/ufw allow ${wgport}.*/d" ${firewallConf}
    done
    while [ $(cat ${firewallConf} | grep -c "ufw allow out on wg0 from any to any") -gt 0 ];
    do
      sed -i "/ufw allow out on wg0 from any to any/d" ${firewallConf}
    done
    while [ $(cat ${firewallConf} | grep -c "ufw allow in on wg0 from any to any") -gt 0 ];
    do
      sed -i "/ufw allow in on wg0 from any to any/d" ${firewallConf}
    done
    while [ $(cat ${firewallConf} | grep -c "ufw allow in to ${wglan}") -gt 0 ];
    do
      sed -i "/ufw allow in to ${wglan}\.0\/24/d" ${firewallConf}
    done
    while [ $(cat ${firewallConf} | grep -c "ufw allow out to ${wglan}") -gt 0 ];
    do
      sed -i "/ufw allow out to ${wglan}\.0\/24/d" ${firewallConf}
    done
  fi

  # remove tlsextraip from lnd.conf
  if [ "${nodetype}" = "raspiblitz" ]; then
    if [ -f "/mnt/hdd/raspiblitz.conf" ]; then
      source /mnt/hdd/raspiblitz.conf
    elif [ -f "/mnt/hdd/app-data/raspiblitz.conf" ]; then
      source /mnt/hdd/app-data/raspiblitz.conf
    fi
    if [ "${lnd}" = "on" ]; then
      source <(/home/admin/config.scripts/network.aliases.sh getvars lnd)
      sed -i "/^tlsextraip=${wgip}/d" ${lndConfFile}
      # remove tls.cert and tls.key if wireguard is installed to pick up new tls.cert that doesn't include wireguard ip
      rm /mnt/hdd/lnd/tls*
      # restart lnd
      systemctl restart lnd
      sleep 5
      # restart nginx
      systemctl restart nginx
      sleep 5
    fi
  elif [ "${nodetype}" = "mynode" ]; then
    if [ "${lndhybrid}" = "on" ]; then
      sed -i "/^tlsextraip=${wgip}/d" ${lndCustomConf}
      # remove tls.cert and tls.key if wireguard is installed to pick up new tls.cert that doesn't include wireguard ip
      rm /mnt/hdd/mynode/lnd/tls*
      # restart lnd
      systemctl restart lnd
      sleep 5
      # restart nginx
      systemctl restart nginx
      sleep 5
    fi
  fi

  # set wireguard off in pleb-vpn.conf
  setting ${plebVPNConf} "2" "wireguard" "off"
  exit 0
}

case "${1}" in
  status) status "${2}" ;;
  connect) connect ;;
  on) on "${2}" "${3}" "${4}" ;;
  off) off ;;
  *) echo "config script to install, configure, get config files, or uninstall wireguard"; echo "wg-install.sh [on|off|status|connect]"; exit 1 ;;
esac 
