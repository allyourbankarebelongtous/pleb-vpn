#!/bin/bash

# backs up on initial install of pleb-vpn and on raspiblitz updates
# restores on RESTORE-DEFAULTS or UNINSTALL-ALL from menu

# command info
if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "-help" ]; then
  echo "config script to backup or restore critical files before installing or after uninstalling pleb-vpn"
  echo "pleb-vpn.backup.sh [backup|restore]"
  exit 1
fi

backup() {
  # backs up critical files to /mnt/hdd/app-data/pleb-vpn/.backups
  sudo mkdir /mnt/hdd/app-data/pleb-vpn/.backups
  sudo chown admin:admin /mnt/hdd/app-data/pleb-vpn/.backups
  sudo chmod 755 /mnt/hdd/app-data/pleb-vpn/.backups
  # backup custom-installs.sh
  sudo cp -p /mnt/hdd/app-data/custom-installs.sh /mnt/hdd/app-data/pleb-vpn/.backups/
  # backup ufw settings
  sudo cp -p -r /etc/ufw/ /mnt/hdd/app-data/pleb-vpn/.backups/
  # backup raspiblitz.conf
  sudo cp -p /mnt/hdd/raspiblitz.conf /mnt/hdd/app-data/pleb-vpn/.backups/
  # backup lnd.check.sh
  sudo cp -p /home/admin/config.scripts/lnd.check.sh /mnt/hdd/app-data/pleb-vpn/.backups/
  # backup 00mainMenu.sh
  sudo cp -p /home/admin/00mainMenu.sh /mnt/hdd/app-data/pleb-vpn/.backups/
  # backup sysctl.conf
  sudo cp -p /etc/sysctl.conf /mnt/hdd/app-data/pleb-vpn/.backups/
  # backup lnd.conf (if exists)
  lndconfExists=$(sudo ls /mnt/hdd/lnd | grep -c lnd.conf)
  if ! [ ${lndconfExists} -eq 0 ]; then
    sudo cp -p /mnt/hdd/lnd/lnd.conf /mnt/hdd/app-data/pleb-vpn/.backups/
  fi
  # backup .lightning/config (if exists)
  clnconfExists=$(sudo ls /home/bitcoin/.lightning/ | grep -c config)
  if ! [ ${clnconfExists} -eq 0 ]; then
    sudo cp -p /home/bitcoin/.lightning/config /mnt/hdd/app-data/pleb-vpn/.backups/
  fi
  exit 0
}

restore() {
  # restores critical files from /mnt/hdd/app-data/pleb-vpn/.backups
  # restore custom installs
  sudo cp -p /mnt/hdd/app-data/pleb-vpn/.backups/custom-installs.sh /mnt/hdd/app-data/
  sudo chown root:root /mnt/hdd/app-data/custom-installs.sh
  sudo chmod 755 /mnt/hdd/app-data/custom-installs.sh
  # restore ufw settings
  sudo ufw disable
  sudo cp -p -r /mnt/hdd/app-data/pleb-vpn/.backups/ufw/ /etc/
  sudo chmod 640 /etc/ufw/*
  sudo chmod 755 /etc/ufw/applications.d
  sudo chmod 644 /etc/ufw/sysctl.conf
  sudo chmod 644 /etc/ufw/ufw.conf
  sudo chmod 644 /etc/ufw/applications.d/*
  sudo chown -R root:root /etc/ufw/
  sudo ufw --force enable
  # restore raspiblitz.conf
  sudo cp -p /mnt/hdd/app-data/pleb-vpn/.backups/raspiblitz.conf /mnt/hdd/
  sudo chown root:sudo /mnt/hdd/raspiblitz.conf
  sudo chmod 664 /mnt/hdd/raspiblitz.conf
  # restore lnd.check.sh
  sudo cp -p /mnt/hdd/app-data/pleb-vpn/.backups/lnd.check.sh /home/admin/config.scripts/
  # restore 00mainMenu.sh
  sudo cp -p /mnt/hdd/app-data/pleb-vpn/.backups/00mainMenu.sh /home/admin/
  # restore sysctl.conf
  sudo cp -p /mnt/hdd/app-data/pleb-vpn/.backups/sysctl.conf /etc/
  sudo chown root:root /etc/sysctl.conf
  sudo chmod 644 /etc/sysctl.conf
  # restore lnd.conf (if exists)
  lndconfExists=$(sudo ls /mnt/hdd/app-data/pleb-vpn/.backups | grep -c lnd.conf)
  if ! [ ${lndconfExists} -eq 0 ]; then
    sudo cp -p /mnt/hdd/app-data/pleb-vpn/.backups/lnd.conf /mnt/hdd/lnd/
    sudo chown bitcoin:bitcoin /mnt/hdd/lnd/lnd.conf
    sudo chmod 644 /mnt/hdd/lnd/lnd.conf
  fi
  # restore .lightning/config (if exists)
  clnconfExists=$(sudo ls /mnt/hdd/app-data/pleb-vpn/.backups | grep -c config)
  if ! [ ${clnconfExists} -eq 0 ]; then
    sudo cp -p /mnt/hdd/app-data/pleb-vpn/.backups/config /home/bitcoin/.lightning/
    sudo chown bitcoin:bitcoin /home/bitcoin/.lightning/config
    sudo chmod 644 /home/bitcoin/.lightning/config
  fi
  exit 0
}

case "${1}" in
  backup) backup ;;
  restore) restore ;;
  *) echo "err=Unknown action: ${1}" ; exit 1 ;;
esac