#!/bin/bash

# displays connection info for WebUI

# find home directory based on node implementation
if [ -d "/mnt/hdd/mynode/pleb-vpn/" ]; then
  homedir="/mnt/hdd/mynode/pleb-vpn"
  execdir="/opt/mynode/pleb-vpn"
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

# script only used for raspiblitz currently
if [ "${nodetype}" = "raspiblitz" ]; then
  # check and load raspiblitz config
  # to know which network is running
  source /home/admin/raspiblitz.info
  source /mnt/hdd/raspiblitz.conf

  # get network info
  isInstalled=$(sudo ls /etc/systemd/system/pleb-vpn.service 2>/dev/null | grep -c 'jobs-lndg.service')
  localip=$(hostname -I | awk '{print $1}')
  toraddress=$(sudo cat /mnt/hdd/tor/pleb-vpn/hostname 2>/dev/null)
  fingerprint=$(openssl x509 -in /mnt/hdd/app-data/nginx/tls.cert -fingerprint -noout | cut -d"=" -f2)
  httpPort="2420"
  httpsPort="2421"

  if [ "${runBehindTor}" = "on" ] && [ ${#toraddress} -gt 0 ]; then
    # Info with TOR
    sudo /home/admin/config.scripts/blitz.display.sh qr "${toraddress}"
    whiptail --title " Pleb-VPN " --msgbox "Open in your local web browser:
http://${localip}:${httpPort}\n
https://${localip}:${httpsPort} with Fingerprint:
${fingerprint}\n
Username is admin. Use your Password B to login.\n
Hidden Service address for TOR Browser (see LCD for QR):\n${toraddress}
" 18 67
    sudo /home/admin/config.scripts/blitz.display.sh hide
  else
    # Info without TOR
    whiptail --title " Pleb-VPN " --msgbox "Open in your local web browser:
http://${localip}:${httpPort}\n
Or https://${localip}:${httpsPort} with Fingerprint:
${fingerprint}\n
Username is admin. Use your Password B to login.\n
Activate TOR or Pleb-VPN Wireguard to access the web\n
interface from outside your local network.
" 18 67
  fi
  echo "please wait ..."
  exit 0
fi
