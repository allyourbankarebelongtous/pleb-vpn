#!/bin/bash

# backs up on initial install of pleb-vpn and on raspiblitz updates
# restores on RESTORE-DEFAULTS or UNINSTALL-ALL from menu

if [ -d "/mnt/hdd/mynode" ]; then
  nodetype="mynode"
  homedir="/mnt/hdd/mynode/pleb-vpn"
  execdir="/opt/mynode/pleb-vpn"
  firewallConf="/usr/bin/mynode_firewall.sh"
elif [ -f "/mnt/hdd/raspiblitz.conf" ] || [ -f "/mnt/hdd/app-data/raspiblitz.conf" ]; then
  nodetype="raspiblitz"
  homedir="/mnt/hdd/app-data/pleb-vpn"
  execdir="/home/admin/pleb-vpn"
fi

# check if sudo
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (with sudo)"
  exit 1
fi

backup() {
  # currently only used for raspiblitz
  if [ "${nodetype}" = "raspiblitz" ]; then
    # backs up critical files to /mnt/hdd/app-data/pleb-vpn/.backups
    mkdir /mnt/hdd/app-data/pleb-vpn/.backups
    chown admin:admin /mnt/hdd/app-data/pleb-vpn/.backups
    chmod 755 /mnt/hdd/app-data/pleb-vpn/.backups
    # backup custom-installs.sh
    cp -p /mnt/hdd/app-data/custom-installs.sh /mnt/hdd/app-data/pleb-vpn/.backups/
    # backup ufw settings
    cp -p -r /etc/ufw/ /mnt/hdd/app-data/pleb-vpn/.backups/
    # backup raspiblitz.conf
    cp -p /mnt/hdd/raspiblitz.conf /mnt/hdd/app-data/pleb-vpn/.backups/
    # backup lnd.check.sh
    cp -p /home/admin/config.scripts/lnd.check.sh /mnt/hdd/app-data/pleb-vpn/.backups/
    # backup 00mainMenu.sh
    cp -p /home/admin/00mainMenu.sh /mnt/hdd/app-data/pleb-vpn/.backups/
    # backup sysctl.conf
    cp -p /etc/sysctl.conf /mnt/hdd/app-data/pleb-vpn/.backups/
    # backup lnd.conf (if exists)
    lndconfExists=$(ls /mnt/hdd/lnd | grep -c lnd.conf)
    if ! [ ${lndconfExists} -eq 0 ]; then
      cp -p /mnt/hdd/lnd/lnd.conf /mnt/hdd/app-data/pleb-vpn/.backups/
    fi
    # backup .lightning/config (if exists)
    clnconfExists=$(ls /home/bitcoin/.lightning/ | grep -c config)
    if ! [ ${clnconfExists} -eq 0 ]; then
      cp -p /home/bitcoin/.lightning/config /mnt/hdd/app-data/pleb-vpn/.backups/
    fi
  fi
  exit 0
}

restore() {
  # currently only used for raspiblitz
  if [ "${nodetype}" = "raspiblitz" ]; then
    # restores critical files from /mnt/hdd/app-data/pleb-vpn/.backups
    # restore custom installs
    cp -p /mnt/hdd/app-data/pleb-vpn/.backups/custom-installs.sh /mnt/hdd/app-data/
    chown root:root /mnt/hdd/app-data/custom-installs.sh
    chmod 755 /mnt/hdd/app-data/custom-installs.sh
    # restore ufw settings
    ufw disable
    cp -p -r /mnt/hdd/app-data/pleb-vpn/.backups/ufw/ /etc/
    chmod 640 /etc/ufw/*
    chmod 755 /etc/ufw/applications.d
    chmod 644 /etc/ufw/sysctl.conf
    chmod 644 /etc/ufw/ufw.conf
    chmod 644 /etc/ufw/applications.d/*
    chown -R root:root /etc/ufw/
    ufw --force enable
    # restore raspiblitz.conf
    cp -p /mnt/hdd/app-data/pleb-vpn/.backups/raspiblitz.conf /mnt/hdd/
    chown root:/mnt/hdd/raspiblitz.conf
    chmod 664 /mnt/hdd/raspiblitz.conf
    # restore lnd.check.sh
    cp -p /mnt/hdd/app-data/pleb-vpn/.backups/lnd.check.sh /home/admin/config.scripts/
    # restore 00mainMenu.sh
    cp -p /mnt/hdd/app-data/pleb-vpn/.backups/00mainMenu.sh /home/admin/
    # restore sysctl.conf
    cp -p /mnt/hdd/app-data/pleb-vpn/.backups/sysctl.conf /etc/
    chown root:root /etc/sysctl.conf
    chmod 644 /etc/sysctl.conf
    # restore lnd.conf (if exists)
    lndconfExists=$(ls /mnt/hdd/app-data/pleb-vpn/.backups | grep -c lnd.conf)
    if ! [ ${lndconfExists} -eq 0 ]; then
      cp -p /mnt/hdd/app-data/pleb-vpn/.backups/lnd.conf /mnt/hdd/lnd/
      chown bitcoin:bitcoin /mnt/hdd/lnd/lnd.conf
      chmod 644 /mnt/hdd/lnd/lnd.conf
    fi
    # restore .lightning/config (if exists)
    clnconfExists=$(ls /mnt/hdd/app-data/pleb-vpn/.backups | grep -c config)
    if ! [ ${clnconfExists} -eq 0 ]; then
      cp -p /mnt/hdd/app-data/pleb-vpn/.backups/config /home/bitcoin/.lightning/
      chown bitcoin:bitcoin /home/bitcoin/.lightning/config
      chmod 644 /home/bitcoin/.lightning/config
    fi
  fi
  exit 0
}

case "${1}" in
  backup) backup ;;
  restore) restore ;;
  *) echo "config script to backup or restore critical files before installing or after uninstalling pleb-vpn"; echo "pleb-vpn.backup.sh [backup|restore]"; exit 1 ;;
esac