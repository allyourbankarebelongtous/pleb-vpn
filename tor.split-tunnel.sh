#!/bin/bash

# script to enable split-tunneling of tor on or off for pleb-vpn
### done - adds a create-cgroup.sh file in /home/admin/pleb-vpn/split-tunnel/ which
#   creates a cgroup net_cls for marking traffic
### done - adds a systemd service, pleb-vpn-create-cgroup.service which creates the group
#   on system boot
### done - makes the service a requirement for tor to start
# - decide to use tasks or cgclassify - creates tor-split-tunnel.sh in /home/admin/pleb-vpn/split-tunnel/ which
#   adds the tor pid to the created cgroup (why create-cgroup must be on for tor 
#   to start)
### done - creates a systemd service and timer, pleb-vpn-tor-split-tunnel.service and
# - maybe   pleb-vpn-tor-split-tunnel.timer to start/restart if required tor-split-tunnel.sh
### can also restart on tor restart   (timer is required because if tor restarts it will change pid)
### checks for and adds if required /etc/iproute2/rt_tables.d/novpn-route.conf
### done - adds a nftables-config.sh file to /home/admin/pleb-vpn/split-tunnel/ that
#   checks for and adds the required nftables rules to mark traffic from the cgroup
#   and allow the marked traffic through the firewall without allowing anything else
#   through
### done - creates a systemd service, pleb-vpn-nftables-config.service, that runs on 
#   boot after pleb-vpn-create-cgroup.service to automatically update firewall rules
#   edits /lib/systemd/system/tor@.service and /lib/systemd/system/tor.service to
#   ensure they start in the cgroup.
# For off, script undoes all of the above actions
# script also ensures config is persistent across updates (pleb-vpn.conf and vpn-install.sh changes required
# script is available via SERVICES menu after pleb-vpn is on (requires editing pleb-vpnServicesMenu.sh)

# command info
if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "-help" ]; then
  echo "config script to turn tor split-tunnelng on or off"
  echo "tor.split-tunnel.sh [on|off|status]"
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

status() {
  source ${plebVPNConf}

  echo "checking configuration"
  if [ "${tor-split-tunnel}" = "off" ]; then
    whiptail --title "Tor Split-Tunnel status" --msgbox "
Tor Split-Tunnel service is off by config.
Use menu to install Pleb-VPN.
" 9 40
    exit 0
  else
    message="Tor Split-Tunnel service is working normally"
    echo "Checking connection over clearnet with VPN on..."
    VPNclearnetIP=$(curl https://api.ipify.org)
    sleep 5
    echo "Stopping VPN"
    systemctl stop openvpn@plebvpn
    sleep 5
    echo "Checking connection over clearnet with VPN off (should fail)" 
    noVPNclearnetIP=$(curl https://api.ipify.org)
    sleep 5
    if [ "${noVPNclearnetIP}" = "" ]; then
      firewallOK="yes"
    else
      firewallOK="no"
      message="error...firewall not configured. Clearnet accessible when VPN is off. Uninstall and re-install pleb-vpn"
    fi
    echo "Checking connection over tor with VPN off..."
    noVPNtorIP=$(torify curl http://api.ipify.org)
    sleep 5
    if [ ! "${noVPNtorIP}" = "" ]; then
      torSplitTunnelOK="yes"
    else 
      message="error...unable to connect over tor when VPN is down. It's possible that it needs more time to establish a connection. 
Try checking the status using STATUS menu later. If unable to connect, uninstall and re-install Tor Split-Tunnel."
      torSplitTunnelOK="no"
    fi
    echo "Restarting VPN"
    systemctl start openvpn@plebvpn
    sleep 5
    echo "Checking connection over clearnet with VPN on..."
    currentIP=$(curl https://api.ipify.org)
    sleep 5
    if ! [ "${currentIP}" = "${vpnIP}" ]; then
      vpnWorking="no"
      message="ERROR: your current IP does not match your vpnIP"
    else
      vpnWorking="yes"
    fi 
    whiptail --title "Tor Split-Tunnel status" --msgbox "
Split-Tunnel activated: yes
VPN operating: ${vpnWorking}
Tor able to connect when firewall down: ${torSplitTunnelOK}
VPN server IP: ${vpnIP}
VPN server port: ${vpnPort}
Current IP (should match VPN server IP): ${currentIP}
Firewall configuration OK: ${firewallOK}
${message}
" 16 100
    exit 0
  fi
}

on() {
  # configure tor to skip pleb-vpn for redundancy
  source ${plebVPNConf}

  # install dependencies
echo "Checking and installing requirements..."
  # check for cgroup and install
  echo "Checking cgroup-tools..."
  checkcgroup=$(cgcreate -h 2>/dev/null | grep -c "Usage")
  if [ $checkcgroup -eq 0 ]; then
    echo "Installing cgroup-tools..."
    if apt install -y cgroup-tools >/dev/null; then
      echo "> cgroup-tools installed"
      echo
    else
      echo "> failed to install cgroup-tools"
      echo
      exit 1
    fi
  else
    echo "> cgroup-tools found"
    echo
  fi
  # check nftables
  echo "Checking nftables installation..."
  checknft=$(nft -v 2>/dev/null | grep -c "nftables")
  if [ $checknft -eq 0 ]; then
    echo "Installing nftables..."
    if apt install -y nftables >/dev/null; then
      echo "> nftables installed"
      echo
    else
      echo "> failed to install nftables"
      echo
      exit 1
    fi
  else
    echo "> nftables found"
    echo
  fi

  # clean rules from failed install attempts
  echo "cleaning ip rules to prevent duplicate rules"
  OIFNAME=$(ip r | grep default | cut -d " " -f5)
  GATEWAY=$(ip r | grep default | cut -d " " -f3)

  # first check for and remove old names from prior starts
  ip_nat_handles=$(nft -a list table ip nat | grep "meta cgroup 1114129 counter" | sed "s/.*handle //")
  while [ $(nft list table ip nat | grep -c "meta cgroup 1114129 counter") -gt 0 ]
  do
    ruleNumber=$(nft list table ip nat | grep -c "meta cgroup 1114129 counter")
    ip_nat_handle=$(echo "${ip_nat_handles}" | sed -n ${ruleNumber}p)
    nft delete rule ip nat POSTROUTING handle ${ip_nat_handle}
  done
  while [ $(nft list tables | grep -c mangle) -gt 0 ]
  do
    nft delete table ip mangle
  done
  ip_filter_handles=$(nft -a list table ip filter | grep "meta cgroup 1114129 counter" | sed "s/.*handle //")
  while [ $(nft list table ip filter | grep -c "meta cgroup 1114129 counter") -gt 0 ]
  do
    ruleNumber=$(nft list table ip filter | grep -c "meta cgroup 1114129 counter")
    ip_filter_handle=$(echo "${ip_filter_handles}" | sed -n ${ruleNumber}p)
    nft delete rule ip filter ufw-user-output handle ${ip_filter_handle}
  done
  while [ $(ip rule | grep -c "fwmark 0xb lookup novpn") -gt 0 ]
  do
    ip rule del from all table novpn fwmark 11
  done
  while [ $(ip rule | grep -c novpn) -gt 0 ]
  do
    ip rou del from all table novpn default via ${GATEWAY}
  done

  # create routing table
  if [ ! -d /etc/iproute2/rt_tables.d ]; then
    mkdir /etc/iproute2/rt_tables.d/
  fi
  echo "1000 novpn" | tee /etc/iproute2/rt_tables.d/novpn-route.conf

  # create-cgroup.sh
  echo "create create-cgroup.sh in pleb-vpn/split-tunnel..."
  if [ ! -d /home/admin/pleb-vpn/split-tunnel ]; then
    mkdir /home/admin/pleb-vpn/split-tunnel
  fi
  echo '#!/bin/bash

# creates cgroup novpn for processes to skip vpn
modprobe cls_cgroup
if [ ! -d /sys/fs/cgroup/net_cls ]; then
  mkdir /sys/fs/cgroup/net_cls
fi
mount -t cgroup -o net_cls novpn /sys/fs/cgroup/net_cls
cgcreate -t debian-tor:novpn -a debian-tor:novpn -d 775 -f 664 -s 664 -g net_cls:novpn
echo 0x00110011 > /sys/fs/cgroup/net_cls/novpn/net_cls.classid

' | tee /home/admin/pleb-vpn/split-tunnel/create-cgroup.sh
  chmod 755 -R /home/admin/pleb-vpn/split-tunnel
  # run create-cgroup.sh
  echo "execute create-cgroup.sh"
  /home/admin/pleb-vpn/split-tunnel/create-cgroup.sh

  # create pleb-vpn-create-cgroup.service
  echo "create create-cgroup.service to auto-create cgroup on start"
  echo "[Unit]
Description=Creates cgroup for split-tunneling tor from vpn
StartLimitInterval=200
StartLimitBurst=5
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash /home/admin/pleb-vpn/split-tunnel/create-cgroup.sh
[Install]
WantedBy=multi-user.target
" | tee /etc/systemd/system/pleb-vpn-create-cgroup.service

  # add pleb-vpn-create-cgroup.service as a tor requirement
  echo "adding pleb-vpn-create-cgroup.service as a requirement to start tor"
  if [ ! -d /etc/systemd/system/tor@default.service.d ]; then
    mkdir /etc/systemd/system/tor@default.service.d >/dev/null
  fi
  echo "#Don't edit this file, it is created by pleb-vpn split-tunnel
[Unit]
Requires=pleb-vpn-create-cgroup.service
After=pleb-vpn-create-cgroup.service
" | tee /etc/systemd/system/tor@default.service.d/tor-cgroup.conf

  # tor-split-tunnel.sh
  echo "create tor-split-tunnel.sh in pleb-vpn/split-tunnel to add tor to cgroup for split-tunnel"
  echo '#!/bin/bash

# adds tor to cgroup for split-tunneling
tor_pid=$(pgrep -x tor)
cgclassify -g net_cls:novpn $tor_pid
' | tee /home/admin/pleb-vpn/split-tunnel/tor-split-tunnel.sh
  chmod 755 -R /home/admin/pleb-vpn/split-tunnel
  # run tor-split-tunnel.sh
  echo "execute tor-split-tunnel.sh"
  /home/admin/pleb-vpn/split-tunnel/tor-split-tunnel.sh
  
  # create pleb-vpn-tor-split-tunnel.service
  echo "Create tor-split-tunnel.service systemd service..."
######### This service is for a timer to activate
#  echo "[Unit]
#Description=Adding tor process to cgroup novpn
#[Service]
#Type=oneshot
#ExecStart=/bin/bash /home/admin/pleb-vpn/split-tunnel/tor-split-tunnel.sh
#[Install]
#Wants=tor@default.service
#After=tor@default.service
#" | tee /etc/systemd/system/pleb-vpn-tor-split-tunnel.service
########## This service is for stand-alone
  echo "[Unit]
Description=Adding tor process to cgroup novpn
Wants=tor@default.service
After=tor@default.service
[Service]
Type=oneshot
ExecStart=/bin/bash /home/admin/pleb-vpn/split-tunnel/tor-split-tunnel.sh
[Install]
WantedBy=multi-user.target
" | tee /etc/systemd/system/pleb-vpn-tor-split-tunnel.service
  # fix blitzapi.service to start after pleb-vpn-tor-split-tunnel.service
##### might not need...test (only if timer not needed)

  # create pleb-vpn-tor-split-tunnel.timer
##### might not need...test

  # nftables-config.sh
  echo "Creating nftables-config.sh in pleb-vpn/split-tunnel..."
  echo '#!/bin/bash

# adds route and rules to allow novpn cgroup past firewall

# first clean tables from existing duplicate rules
OIFNAME=$(ip r | grep default | cut -d " " -f5)
GATEWAY=$(ip r | grep default | cut -d " " -f3)

# first check for and remove old names from prior starts
ip_nat_handles=$(nft -a list table ip nat | grep "meta cgroup 1114129 counter" | sed "s/.*handle //")
while [ $(nft list table ip nat | grep -c "meta cgroup 1114129 counter") -gt 0 ]
do
  ruleNumber=$(nft list table ip nat | grep -c "meta cgroup 1114129 counter")
  ip_nat_handle=$(echo "${ip_nat_handles}" | sed -n ${ruleNumber}p)
  nft delete rule ip nat POSTROUTING handle ${ip_nat_handle}
done
while [ $(nft list tables | grep -c mangle) -gt 0 ]
do
  nft delete table ip mangle
done
ip_filter_handles=$(nft -a list table ip filter | grep "meta cgroup 1114129 counter" | sed "s/.*handle //")
while [ $(nft list table ip filter | grep -c "meta cgroup 1114129 counter") -gt 0 ]
do
  ruleNumber=$(nft list table ip filter | grep -c "meta cgroup 1114129 counter")
  ip_filter_handle=$(echo "${ip_filter_handles}" | sed -n ${ruleNumber}p)
  nft delete rule ip filter ufw-user-output handle ${ip_filter_handle}
done
while [ $(ip rule | grep -c "fwmark 0xb lookup novpn") -gt 0 ]
do
  ip rule del from all table novpn fwmark 11
done
while [ $(ip rule | grep -c novpn) -gt 0 ]
do
  ip rou del from all table novpn default via ${GATEWAY}
done

# add/refresh rules
nft add rule ip nat POSTROUTING oifname ${OIFNAME} meta cgroup 1114129 counter masquerade
nft add table ip mangle
nft add chain ip mangle markit "{type route hook output priority filter; policy accept;}"
nft add rule ip mangle markit meta cgroup 1114129 counter meta mark set 0xb
nft add rule ip filter ufw-user-output meta cgroup 1114129 counter accept
ip route add default via ${GATEWAY} table novpn
ip rule add fwmark 11 table novpn
' | tee /home/admin/pleb-vpn/split-tunnel/nftables-config.sh
  chmod 755 -R /home/admin/pleb-vpn/split-tunnel
  # run it once
  /home/admin/pleb-vpn/split-tunnel/nftables-config.sh

  # create nftables-config.service
  echo "Create nftables-config systemd service..."
  echo "[Unit]
Description=Configure nftables for split-tunnel process
Wants=pleb-vpn-tor-split-tunnel.service.service
After=pleb-vpn-tor-split-tunnel.service.service
[Service]
Type=oneshot
ExecStart=/bin/bash /home/admin/pleb-vpn/split-tunnel/nftables-config.sh
[Install]
WantedBy=multi-user.target
" | tee /etc/systemd/system/pleb-vpn-nftables-config.service

  # enable and start all services
  echo "enabling services..."
  systemctl daemon-reload >/dev/null
  systemctl enable pleb-vpn-create-cgroup.service
  systemctl enable pleb-vpn-tor-split-tunnel.service
  systemctl enable pleb-vpn-nftables-config.service
  echo "restart tor to pick up new split-tunnel configuration..."
  systemctl stop tor@default.service
  systemctl start pleb-vpn-create-cgroup.service
  systemctl start tor@default.service
  systemctl start pleb-vpn-tor-split-tunnel.service
  systemctl start pleb-vpn-nftables-config.service

  # check configuration
  echo "OK...tor is configured. Wait 2 minutes for tor to start..."
  sleep 60
  echo "wait 1 minutes for tor to start..."
  sleep 60
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
  echo "checking tor..."
  inc=1
  while [ $inc -le 10 ]
  do
    torIP=$(torify curl http://api.ipify.org)
    echo "tor IP = (${torIP})...should not be blank, should not be your home IP, and should not be your VPN IP."
    if [ ! "${torIP}" = "" ]; then
      inc = 5
    else
      ((inc++))
    fi
  done
  if [ ! "${torIP}" = "" ]; then
    echo "tor split-tunnel successful"
  else 
    echo "error...unable to connect over tor when VPN is down. It's possible that it needs more time to establish a connection. 
Try checking the status using STATUS menu later. If unable to connect, uninstall and re-install Tor Split-Tunnel."
    systemctl start openvpn@plebvpn
  fi
  sleep 2
  echo "restarting vpn"
  systemctl start openvpn@plebvpn
  echo "checking vpn IP"
  currentIP=$(curl https://api.ipify.org)
  echo "current IP = (${currentIP})...should be ${vpnIP}"
  echo "tor split-tunneling enabled!"
  sleep 2
  setting ${plebVPNConf} "2" "torSplitTunnel" "on"
  exit 0
}

off() {
  # remove tor split-tunneling process
  source ${plebVPNConf}

  # remove services
  echo "stop and remove systemd services"
  echo "stopping tor..."
  systemctl stop tor@default.service
  echo "stopping split-tunnel services..."
  systemctl stop pleb-vpn-create-cgroup.service
  systemctl stop pleb-vpn-tor-split-tunnel.service
  systemctl stop pleb-vpn-nftables-config.service
  systemctl disable pleb-vpn-create-cgroup.service
  systemctl disable pleb-vpn-tor-split-tunnel.service
  systemctl disable pleb-vpn-nftables-config.service
  rm /etc/systemd/system/pleb-vpn-create-cgroup.service
  rm /etc/systemd/system/pleb-vpn-tor-split-tunnel.service
  rm /etc/systemd/system/pleb-vpn-nftables-config.service

  # fix tor dependency
  echo "remove tor dependency"
  rm /etc/systemd/system/tor@default.service.d/tor-cgroup.conf

  # uninstall cgroup-tools
  echo "uninstall cgroup-tools"
  apt purge -y cgroup-tools

  # clean ip rules
  echo "cleaning ip rules"
  OIFNAME=$(ip r | grep default | cut -d " " -f5)
  GATEWAY=$(ip r | grep default | cut -d " " -f3)
  ip_nat_handles=$(nft -a list table ip nat | grep "meta cgroup 1114129 counter" | sed "s/.*handle //")
  while [ $(nft list table ip nat | grep -c "meta cgroup 1114129 counter") -gt 0 ]
  do
    ruleNumber=$(nft list table ip nat | grep -c "meta cgroup 1114129 counter")
    ip_nat_handle=$(echo "${ip_nat_handles}" | sed -n ${ruleNumber}p)
    nft delete rule ip nat POSTROUTING handle ${ip_nat_handle}
  done
  while [ $(nft list tables | grep -c mangle) -gt 0 ]
  do
    nft delete table ip mangle
  done
  ip_filter_handles=$(nft -a list table ip filter | grep "meta cgroup 1114129 counter" | sed "s/.*handle //")
  while [ $(nft list table ip filter | grep -c "meta cgroup 1114129 counter") -gt 0 ]
  do
    ruleNumber=$(nft list table ip filter | grep -c "meta cgroup 1114129 counter")
    ip_filter_handle=$(echo "${ip_filter_handles}" | sed -n ${ruleNumber}p)
    nft delete rule ip filter ufw-user-output handle ${ip_filter_handle}
  done
  while [ $(ip rule | grep -c "fwmark 0xb lookup novpn") -gt 0 ]
  do
    ip rule del from all table novpn fwmark 11
  done
  while [ $(ip rule | grep -c novpn) -gt 0 ]
  do
    ip rou del from all table novpn default via ${GATEWAY}
  done

  # remove routing table
  rm /etc/iproute2/rt_tables.d/novpn-route.conf

  # remove split-tunnel scripts
  echo "removing split-tunnel scripts"
  rm -rf /home/admin/pleb-vpn/split-tunnel

  # restart tor
  echo "starting tor..."
  systemctl daemon-reload >/dev/null
  systemctl start tor@default.service

  # check configuration
  echo "OK...tor is configured to run over the VPN. Wait 2 minutes for tor to start..."
  sleep 60
  echo "wait 1 minutes for tor to start..."
  sleep 60
  echo "checking configuration"
  echo "stop VPN"
  systemctl stop openvpn@plebvpn
  sleep 5
  echo "VPN stopped"
  echo "checking firewall"
  currentIP=$(curl https://api.ipify.org)
  echo "current IP = (${currentIP})...should be blank"
  if [ "${currentIP}" = "" ]; then
    echo "firewall config ok"
  else 
    echo "error...firewall not configured. Clearnet accessible when VPN is off. Uninstall and re-install all of pleb-vpn."
    systemctl start openvpn@plebvpn
    exit 1
  fi
  echo "checking tor..."
  inc=1
  while [ $inc -le 10 ]
  do
    torIP=$(torify curl http://api.ipify.org)
    echo "tor IP = (${torIP})...should be blank."
    if [ "${torIP}" = "" ]; then
      inc = 10
    else
      ((inc++))
    fi
  done
  if [ "${torIP}" = "" ]; then
    echo "tor configuration successful"
  else 
    echo "error...tor configuration unsuccessful. Uninstall all of Pleb-VPN to restore configuration."
    systemctl start openvpn@plebvpn
    exit 1
  fi
  sleep 2
  echo "restarting vpn"
  systemctl start openvpn@plebvpn
  sleep 2
  echo "checking VPN IP"
  currentIP=$(curl https://api.ipify.org)
  echo "current IP = (${currentIP})...should be ${vpnIP}"
  echo "tor split-tunneling is disabled and removed"
  sleep 2
  setting ${plebVPNConf} "2" "torSplitTunnel" "off"
  exit 0
}

case "${1}" in
  on) on ;;
  off) off ;;
  status) status ;;
esac
