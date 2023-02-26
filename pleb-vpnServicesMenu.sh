#!/bin/bash

# pleb-VPN services menu

plebVPNConf="/home/admin/pleb-vpn/pleb-vpn.conf"
source ${plebVPNConf}
source /mnt/hdd/raspiblitz.conf

# default values
if [ ${#plebVPN} -eq 0 ]; then plebVPN="off"; fi
if [ ${#wireguard} -eq 0 ]; then wireguard="off"; fi
if [ ${#clnHybrid} -eq 0 ]; then clnHybrid="off"; fi
if [ ${#lndHybrid} -eq 0 ]; then lndHybrid="off"; fi
if [ ${#torSplitTunnel} -eq 0 ]; then torSplitTunnel="off"; fi
if [ ${#letsencrypt_ssl} -eq 0 ]; then letsencrypt_ssl="off"; fi

OPTIONS=()

OPTIONS+=(vpn 'Pleb-VPN OpenVPN Connection' ${plebVPN})

# if plebVPN = on then show other services
if [ "${plebVPN}" = "on" ]; then
  OPTIONS+=(wg 'WireGuard personal VPN' ${wireguard})
  OPTIONS+=(tnl 'Tor Split-Tunnel from Pleb-VPN' ${torSplitTunnel})
  # if CLN is on in raspiblitz.conf
  if [ "${lightning}" == "cl" ] || [ "${cl}" == "on" ]; then
    OPTIONS+=(cln 'Core Lightning Hybrid Mode' ${clnHybrid})
  fi
  # if LND is on in raspiblitz.conf
  if [ "${lightning}" == "lnd" ] || [ "${lnd}" == "on" ]; then
    OPTIONS+=(lnd 'LND Hybrid Mode' ${lndHybrid})
  fi
  # if BTCPayServer or LNBits is on in raspiblitz.conf
  if [ "${BTCPayServer}" == "on" ] || [ "${LNBits}" == "on" ]; then
    OPTIONS+=(ssl 'LetsEncrypt for BTCPay and/or LNBits' ${letsencrypt_ssl})
  fi
fi
CHOICES=$(dialog --title ' Activate Pleb-VPN Services ' \
          --checklist ' use spacebar to activate/de-activate ' \
          20 55 20  "${OPTIONS[@]}" 2>&1 >/dev/tty)

dialogcancel=$?
echo "done dialog"
clear

# check if user canceled dialog
echo "dialogcancel(${dialogcancel})"
if [ ${dialogcancel} -eq 1 ]; then
  echo "user canceled"
  exit 0
elif [ ${dialogcancel} -eq 255 ]; then
  echo "ESC pressed"
  exit 0
fi

# plebVPN
choice="off"; check=$(echo "${CHOICES}" | grep -c "vpn")
if [ ${check} -eq 1 ]; then choice="on"; fi
if [ "${plebVPN}" != "${choice}" ]; then
  echo "PlebVPN Setting changed .."
  anychange=1
  sudo -u admin /home/admin/pleb-vpn/vpn-install.sh ${choice}
  source ${plebVPNConf}
  if [ "${choice}" =  "on" ]; then
    sudo -u admin /home/admin/pleb-vpn/vpn-install.sh status
  fi
else
  echo "plebVPN unchanged."
fi

# WireGuard
choice="off"; check=$(echo "${CHOICES}" | grep -c "wg")
if [ ${check} -eq 1 ]; then choice="on"; fi
if [ "${wireguard}" != "${choice}" ]; then
  echo "WireGuard Setting changed .."
  anychange=1
  sudo -u admin /home/admin/pleb-vpn/wg-install.sh ${choice}
  source ${plebVPNConf}
  if [ "${choice}" =  "on" ]; then
    sudo -u admin /home/admin/pleb-vpn/wg-install.sh status
  fi
else
  echo "WireGuard unchanged."
fi

# CLN Hybrid
choice="off"; check=$(echo "${CHOICES}" | grep -c "cln")
if [ ${check} -eq 1 ]; then choice="on"; fi
if [ "${clnHybrid}" != "${choice}" ]; then
  echo "CLN Hybrid Setting changed .."
  anychange=1
  sudo -u admin /home/admin/pleb-vpn/cln-hybrid.sh ${choice}
  source <(/home/admin/_cache.sh get ln_default_locked)
  if [ "${clEncryptedHSM}" = "off" ]; then
    # wait until wallet unlocked
    echo "waiting for wallet unlock (takes some time)..."
    sleep 40
  else
    /home/admin/config.scripts/cl.hsmtool.sh unlock
    sleep 5
  fi
  sudo -u admin /home/admin/pleb-vpn/cln-hybrid.sh status
else
  echo "CLN Hybrid unchanged."
fi

# LND Hybrid
choice="off"; check=$(echo "${CHOICES}" | grep -c "lnd")
if [ ${check} -eq 1 ]; then choice="on"; fi
if [ "${lndHybrid}" != "${choice}" ]; then
  echo "LND Hybrid Setting changed .."
  anychange=1
  sudo -u admin /home/admin/pleb-vpn/lnd-hybrid.sh ${choice}
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
  sudo -u admin /home/admin/pleb-vpn/lnd-hybrid.sh status
else
  echo "LND Hybrid unchanged."
fi

# Tor Split-Tunnel
choice="off"; check=$(echo "${CHOICES}" | grep -c "tnl")
if [ ${check} -eq 1 ]; then choice="on"; fi
if [ "${torSplitTunnel}" != "${choice}" ]; then
  echo "Tor Split-Tunnel Setting changed .."
  anychange=1
  sudo /home/admin/pleb-vpn/tor.split-tunnel.sh ${choice}
  source ${plebVPNConf}
  if [ "${choice}" =  "on" ]; then
    sudo /home/admin/pleb-vpn/tor.split-tunnel.sh status 1
  fi
else
  echo "Tor Split-Tunnel unchanged."
fi

# LetsEncrypt
choice="off"; check=$(echo "${CHOICES}" | grep -c "ssl")
if [ ${check} -eq 1 ]; then choice="on"; fi
if [ "${letsencrypt_ssl}" != "${choice}" ]; then
  echo "LetsEncrypt Setting changed .."
  anychange=1
  sudo /home/admin/pleb-vpn/letsencrypt.install.sh ${choice}
else
  echo "LetsEncrypt unchanged."
fi

if [ ${anychange} -eq 0 ]; then
     dialog --msgbox "NOTHING CHANGED!\nUse Spacebar to check/uncheck services." 8 58
     exit 0
fi

