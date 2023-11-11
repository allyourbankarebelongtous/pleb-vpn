#!/bin/bash

# script to turn letsencrypt for BTCPayServer or LNBits on or off

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

# check if sudo
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (with sudo)"
  exit 1
fi

on() {
  if [ "${nodetype}" = "raspiblitz" ]; then
    source /mnt/hdd/raspiblitz.conf
  fi
  local keepExisting="${1}"
  local isRestore="${2}"
  local webui="${3}"
  if [ "${webui}" = "1" ]; then
    local letsencryptbtcpay="${4}"
    local letsencryptlnbits="${5}"
    local letsencryptdomain1="${6}"
    local letsencryptdomain2="${7}"
  fi
  apt install -y certbot
  if [ ! "${webui}" = "1" ]; then
    if [ ! "${keepExisting}" = "1" ]; then
      # check for existing challenge
      isExisting=$(ls ${homedir}/letsencrypt | grep -c acmedns.json)
      if [ ! ${isExisting} -eq 0 ]; then
        whiptail --title "Use Existing DNS Authentication?" \
        --yes-button "Use Existing" \
        --no-button "Create New" \
        --yesno "There's an existing DNS authenticaton found from a previous install of letsencrypt. Do you wish to reuse it or to start fresh?" 10 80
        if [ $? -eq 1 ]; then
          keepExisting="0"
        else
          keepExisting="1"
        fi
      else
        keepExisting="0"
      fi
    fi
  fi
  if [ "${keepExisting}" = "0" ]; then
    if [ ! "${webui}" = "1" ]; then
      # new certs with new dns challenge

      # display instructions and confirm ready to install
      whiptail --title "LetsEncrypt Install Instructions" \
      --yes-button "Continue" \
      --no-button "Cancel" \
      --yesno "
This will install a LetsEncrypt cert on your raspiblitz which will allow ssl https
connections over clearnet for BTCPayServer and/or LNBits. 

Before running this script, make sure you:
1) Have a domain name for each service you are attempting to secure
2) Have forwarded port 443 from your VPS (or had your VPS provider do it)
3) Have updated the A record of each domain to ${vpnip}
4) Are ready to update the CNAME record for each domain when instructed

Are you ready to continue?
" 20 100
      if [ $? -eq 1 ]; then
        echo "user canceled"
        exit 0
      fi
    fi

    # set up acme dns challenge
    mkdir ${homedir}/letsencrypt
    wget https://github.com/joohoi/acme-dns-certbot-joohoi/raw/master/acme-dns-auth.py
    mv acme-dns-auth.py ${homedir}/letsencrypt
    if [ "${nodetype}" = "mynode" ]; then
      # force script to use python3
      sed -i 's/env python/env python3/' ${homedir}/letsencrypt/acme-dns-auth.py
    fi
    cp ${homedir}/letsencrypt/acme-dns-auth.py /etc/letsencrypt/
    chmod 755 /etc/letsencrypt/acme-dns-auth.py

    # clean up failed/old installs
    if [ $(ls /etc/letsencrypt | grep -c acmedns.json) -gt 0 ]; then
      rm -rf /etc/letsencrypt/accounts &> /dev/null
      rm /etc/letsencrypt/acmedns.json &> /dev/null
      rm -rf /etc/letsencrypt/archive &> /dev/null
      rm -rf /etc/letsencrypt/csr &> /dev/null
      rm -rf /etc/letsencrypt/keys &> /dev/null
      rm -rf /etc/letsencrypt/live &> /dev/null
      rm -rf /etc/letsencrypt/renew* &> /dev/null
    fi

    if [ ! "${webui}" = "1" ]; then
      # get service(s) to enable letsencrypt for
      if [ ${#letsencryptbtcpay} -eq 0 ]; then letsencryptbtcpay="off"; fi
      if [ ${#letsencryptlnbits} -eq 0 ]; then letsencryptlnbits="off"; fi
      OPTIONS=()
      if [ "${BTCPayServer}" = "on" ]; then
        OPTIONS+=(b 'BTCPayServer' ${letsencryptbtcpay})
      fi
      if [ "${BTCPayServer}" = "on" ]; then
        OPTIONS+=(l 'LNBits' ${letsencryptlnbits})
      fi
      CHOICES=$(dialog --title ' Select service(s) to secure ' \
                --checklist ' use spacebar to activate/de-activate ' \
                10 45 10  "${OPTIONS[@]}" 2>&1 >/dev/tty)
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

      # BTCPayServer
      check=$(echo "${CHOICES}" | grep -c "b")
      if [ ${check} -eq 1 ]; then
        letsencryptbtcpay="on"
      fi

      # LNBits
      check=$(echo "${CHOICES}" | grep -c "l")
      if [ ${check} -eq 1 ]; then
        letsencryptlnbits="on";
      fi

      # get domain names
      touch ${execdir}/.tmp
      chmod 777 ${execdir}/.tmp
      whiptail --title "Enter Domain" --inputbox "Enter the first domain name that you wish to secure (example: btcpay.mydomain.com)" 11 80 2>${execdir}/.tmp
      letsencryptdomain1=$(cat ${execdir}/.tmp)
      # check first domain name
      if [ "${letsencryptdomain1}" = "" ]; then
        whiptail --title "Invalid Domain" --inputbox "Domain cannot be blank. 
Re-Enter the first domain name that you wish to secure (example: btcpay.mydomain.com)" 12 80 2>${execdir}/.tmp
        letsencryptdomain1=$(cat ${execdir}/.tmp)
        if [ "${letsencryptdomain1}" = "" ]; then
          echo "ERROR: Invalid domain. Domain cannot be blank. Please try again later"
          echo "LetsEncrypt install canceled"
          exit 1
        fi
      fi
      domain1host=$(host ${letsencryptdomain1} | grep -v IPv6 | cut -d " " -f4 | head -n 1)
      if [ ! "${domain1host}" = "${vpnip}" ]; then
        whiptail --title "Invalid Domain" \
        --yes-button "Check Again" \
        --no-button "Re-Enter Domain" \
        --yesno "
ERROR: ${letsencryptdomain1} resolves to host IP of '${domain1host}'. Are you sure you entered it correctly?
Have you added '${vpnip}' to the A record to point the domain at your VPS? If you entered your 
domain name incorrectly chose <Re-Enter Domain> below. If you fixed your A record and want to check 
the host of ${letsencryptdomain1} again, chose <Check Again> below.
" 20 100
        if [ $? -eq 0 ]; then
          whiptail --title "Enter Domain" --inputbox "Enter the first domain name that you wish to secure (example: btcpay.mydomain.com)" 11 80 2>${execdir}/.tmp
          letsencryptdomain1=$(cat ${execdir}/.tmp)
          domain1host=$(host ${letsencryptdomain1} | grep -v IPv6 | cut -d " " -f4 | head -n 1)
        else
          echo "LetsEncrypt install canceled"
          exit 1
        fi
        if [ ! "${domain1host}" = "${vpnip}" ]; then
          echo "ERROR: ${letsencryptdomain1} points to ${domain1host}, should point to ${vpnip}."
          echo "LetsEncrypt install canceled"
          sleep 10
          exit 1
        fi
      fi
      if [ "${letsencryptbtcpay}" = "on" ] && [ "${letsencryptlnbits}" = "on" ]; then
        whiptail --title "Enter Domain" --inputbox "Enter the second domain name that you wish to secure (example: lnbits.mydomain.com)" 11 80 2>${execdir}/.tmp
        letsencryptdomain2=$(cat ${execdir}/.tmp)
      else
        letsencryptdomain2=""
      fi
      # check second domain name
      if [ ! "${letsencryptdomain2}" = "" ]; then
        domain2host=$(host ${letsencryptdomain2} | grep -v IPv6 | cut -d " " -f4 | head -n 1)
        if [ ! "${domain2host}" = "${vpnip}" ]; then
          whiptail --title "Invalid Domain" \
          --yes-button "Check Again" \
          --no-button "Re-Enter Domain" \
          --yesno "
ERROR: ${letsencryptdomain2} resolves to host IP of '${domain2host}'. Are you sure you entered it correctly?
Have you added '${vpnip}' to the A record to point the domain at your VPS? If you entered your 
domain name incorrectly chose <Re-Enter Domain> below. If you fixed your A record and want to check 
the host of ${letsencryptdomain1} again, chose <Check Again> below.
" 20 120
          if [ $? -eq 0 ]; then
            whiptail --title "Enter Domain" --inputbox "Enter the second domain name that you wish to secure (example: btcpay.mydomain.com)" 11 80 2>${execdir}/.tmp
            letsencryptdomain2=$(cat ${execdir}/.tmp)
            domain2host=$(host ${letsencryptdomain1} | grep -v IPv6 | cut -d " " -f4 | head -n 1)
          else
            echo "LetsEncrypt install canceled"
            exit 1
          fi
          if [ ! "${domain2host}" = "${vpnip}" ]; then
            echo "ERROR: ${letsencryptdomain2} points to ${domain2host}, should point to ${vpnip}."
            echo "LetsEncrypt install canceled"
            sleep 10
            exit 1
          fi
        fi
      fi

      # install certs
      whiptail --title "LetsEncrypt new cert" --msgbox "
CertBot is about to install your LetsEncrypt cert. After the install, the CertBot will
instruct you to add the required DNS CNAME record to the DNS configuration for your domain(s).
Under the HOST portion of the CNAME record you will paste the displayed _acme-challenge.<domain>.
Under the ANSWER portion you will paste the token, which is a long string that looks like this:
a15ce5b2-f170-4c91-97bf-09a5764a88f6.auth.acme-dns.io

IMPORTANT: You must do this for ALL domains that you are attempting to secure!

Once that is done, wait about a minute and then press enter to continue the install. 
If the install fails, check your CNAME records and try again using the raspiblitz menu.

Refer to the tutorial at https://github.com/allyourbankarebelongtous/pleb-vpn for more info.
Contact allyourbankarebelongtous with any questions or issues.
" 19 100
    fi
    # get certs
    if [ ! "${letsencryptdomain2}" = "" ]; then
      certbot certonly --manual --manual-auth-hook /etc/letsencrypt/acme-dns-auth.py --preferred-challenges dns --register-unsafely-without-email --agree-tos --debug-challenges -d ${letsencryptdomain1} -d ${letsencryptdomain2}
    else
      certbot certonly --manual --manual-auth-hook /etc/letsencrypt/acme-dns-auth.py --preferred-challenges dns --register-unsafely-without-email --agree-tos --debug-challenges -d ${letsencryptdomain1}
    fi
    sleep 5

    # check if successful
    isSuccessful=$(ls /etc/letsencrypt | grep -c live)
    if [ ${isSuccessful} -eq 0 ]; then
      echo "LetsEncrypt install unsuccessful...try again"
      exit 1
    else
      echo "LetsEncrypt install success!"
    fi

    # link certs to ${homedir}/letsencrypt
    chmod -R 755 /etc/letsencrypt
    ln -s /etc/letsencrypt/live/"${letsencryptdomain1}"/fullchain.pem "${homedir}"/letsencrypt/tls.cert
    ln -s /etc/letsencrypt/live/"${letsencryptdomain1}"/privkey.pem "${homedir}"/letsencrypt/tls.key

    # create letsencrypt ssl snippet
    if [ "${nodetype}" = "raspiblitz" ]; then
      echo "# ssl-certificate-app-data-letsencrypt.conf

ssl_certificate ${homedir}/letsencrypt/tls.cert;
ssl_certificate_key ${homedir}/letsencrypt/tls.key;
" | tee /etc/nginx/snippets/ssl-certificate-app-data-letsencrypt.conf

      # fix btcpay_ssl.conf
      if [ "${letsencryptbtcpay}" = "on" ]; then
        sed -i 's/ssl-certificate-app-data.conf/ssl-certificate-app-data-letsencrypt.conf/' /etc/nginx/sites-available/btcpay_ssl.conf
        sed -i 's/ssl-certificate-app-data.conf/ssl-certificate-app-data-letsencrypt.conf/' /home/admin/assets/nginx/sites-available/btcpay_ssl.conf
      fi

      # fix lnbits_ssl.conf
      if [ "${letsencryptlnbits}" = "on" ]; then
        sed -i 's/ssl-certificate-app-data.conf/ssl-certificate-app-data-letsencrypt.conf/' /etc/nginx/sites-available/lnbits_ssl.conf
        sed -i 's/ssl-certificate-app-data.conf/ssl-certificate-app-data-letsencrypt.conf/' /home/admin/assets/nginx/sites-available/lnbits_ssl.conf
      fi

    elif [ "${nodetype}" = "mynode" ]; then
      echo "# ssl-certificate-app-data-letsencrypt.conf

ssl_certificate ${homedir}/letsencrypt/tls.cert;
ssl_certificate_key ${homedir}/letsencrypt/tls.key;
" | tee /etc/nginx/mynode/mynode_ssl_cert_key_letsencrypt.conf

      # first create and enable systemd service to check for any changes to localip and update the nginx conf file with the new ip address
      echo "#!/bin/bash

sed '1d' /mnt/hdd/mynode/pleb-vpn/pleb-vpn.conf > /mnt/hdd/mynode/pleb-vpn/pleb-vpn.conf.tmp
source /mnt/hdd/mynode/pleb-vpn/pleb-vpn.conf.tmp
rm /mnt/hdd/mynode/pleb-vpn/pleb-vpn.conf.tmp

localip=\$(hostname -I | awk '{print \$1}')
if [ \"\${letsencryptbtcpay}\" = \"on\" ]; then
  sed -i \"s/\(proxy_pass http:\/\/\).*/\1\${localip}:49392;/\" /etc/nginx/sites-enabled/https_btcpayserver.conf
  sed -i 's/mynode_ssl_cert_key.conf/mynode_ssl_cert_key_letsencrypt.conf/' /etc/nginx/sites-enabled/https_btcpayserver.conf
fi
if [ \"\${letsencryptlnbits}\" = \"on\" ]; then
  sed -i \"s/\(proxy_pass http:\/\/\).*/\1\${localip}:49392;/\" /etc/nginx/sites-enabled/https_lnbits.conf
  sed -i 's/mynode_ssl_cert_key.conf/mynode_ssl_cert_key_letsencrypt.conf/' /etc/nginx/sites-enabled/https_lnbits.conf
fi

systemctl reload nginx
" | tee ${homedir}/letsencrypt/set_nginx_localip.sh
      chown admin:admin ${homedir}/letsencrypt/set_nginx_localip.sh
      chmod 755 ${homedir}/letsencrypt/set_nginx_localip.sh

      echo "[Unit]
Description=Add localip to nginx btcpayserver and lnbits for ssl proxy
After=network.service
[Service]
ExecStart=/bin/bash /mnt/hdd/mynode/pleb-vpn/letsencrypt/set_nginx_localip.sh
User=root
Group=root
Restart=on-failure
RestartSec=5s
[Install]
WantedBy=multi-user.target
" | tee /etc/systemd/system/pleb-vpn-letsencrypt-config.service
    fi

    # save acme authenticaton
    cp -p /etc/letsencrypt/acmedns.json ${homedir}/letsencrypt/

  else
    # use existing DNS authenticaton

    # copy acme-dns-auth.py and acmedns.json
    cp ${homedir}/letsencrypt/acme-dns-auth.py /etc/letsencrypt/
    cp ${homedir}/letsencrypt/acmedns.json /etc/letsencrypt/
    chmod -R 755 /etc/letsencrypt

    # check for domain name(s) in pleb-vpn.conf and if not present, get them from acmedns.json
    if [ "${letsencryptdomain1}" = "" ]; then
      domains=$(cat ${homedir}/letsencrypt/acmedns.json | jq . | grep ": {" | cut -d ":" -f1)
      domainCount=$(cat ${homedir}/letsencrypt/acmedns.json | jq . | grep -c ": {")
      letsencryptdomain1=$(echo "${domains}" | sed -n "1p" | sed 's/ //g' | sed 's/\"//g')
      if [ ${domainCount} -gt 1 ]; then
        letsencryptdomain2=$(echo "${domains}" | sed -n "2p" | sed 's/ //g' | sed 's/\"//g')
      fi
    fi
    if [ ! "${isRestore}" = "1" ]; then
      if [ ! "${webui}" = "1" ]; then

        # get service(s) to enable letsencrypt for
        if [ ${#letsencryptbtcpay} -eq 0 ]; then letsencryptbtcpay="off"; fi
        if [ ${#letsencryptlnbits} -eq 0 ]; then letsencryptlnbits="off"; fi
        OPTIONS=()
        if [ "${BTCPayServer}" = "on" ]; then
          OPTIONS+=(b 'BTCPayServer' ${letsencryptbtcpay})
        fi
        if [ "${BTCPayServer}" = "on" ]; then
          OPTIONS+=(l 'LNBits' ${letsencryptlnbits})
        fi
        CHOICES=$(dialog --title ' Select service(s) to secure ' \
                  --checklist ' use spacebar to activate/de-activate ' \
                  10 45 10  "${OPTIONS[@]}" 2>&1 >/dev/tty)
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

        # BTCPayServer
        check=$(echo "${CHOICES}" | grep -c "b")
        if [ ${check} -eq 1 ]; then
          letsencryptbtcpay="on"
        fi

        # LNBits
        check=$(echo "${CHOICES}" | grep -c "l")
        if [ ${check} -eq 1 ]; then
          letsencryptlnbits="on";
        fi

        whiptail --title "LetsEncrypt re-create cert" \
        --yes-button "Yes" \
        --no-button "No" \
        --yesno "
CertBot is about to re-install your LetsEncrypt cert using the following information:

Domain 1: ${letsencryptdomain1}
Domain 2: ${letsencryptdomain2}
BTCPayServer LetsEncrypt: ${letsencryptbtcpay}
LNBits LetsEncrypt: ${letsencryptlnbits}

If the above information is incorrect, re-run this script and create a new DNS Authentication.

Is the information correct?
" 19 100
        if [ $? -eq 1 ]; then
          echo "user canceled"
          exit 0
        fi
      fi
    fi

    # get certs
    if [ ! "${letsencryptdomain2}" = "" ]; then
      certbot certonly --noninteractive --agree-tos --manual --manual-auth-hook /etc/letsencrypt/acme-dns-auth.py --preferred-challenges dns --register-unsafely-without-email --agree-tos -d ${letsencryptdomain1} -d ${letsencryptdomain2}
    else
      certbot certonly --noninteractive --agree-tos --manual --manual-auth-hook /etc/letsencrypt/acme-dns-auth.py --preferred-challenges dns --register-unsafely-without-email --agree-tos -d ${letsencryptdomain1}
    fi

    # link certs to ${homedir}/letsencrypt
    chmod -R 755 /etc/letsencrypt
    rm ${homedir}/letsencrypt/tls.cert &> /dev/null
    rm ${homedir}/letsencrypt/tls.key &> /dev/null
    ln -s /etc/letsencrypt/live/"${letsencryptdomain1}"/fullchain.pem ${homedir}/letsencrypt/tls.cert
    ln -s /etc/letsencrypt/live/"${letsencryptdomain1}"/privkey.pem ${homedir}/letsencrypt/tls.key

    # create letsencrypt ssl snippet
    if [ "${nodetype}" = "raspiblitz" ]; then
      echo "# ssl-certificate-app-data-letsencrypt.conf

ssl_certificate ${homedir}/letsencrypt/tls.cert;
ssl_certificate_key ${homedir}/letsencrypt/tls.key;
" | tee /etc/nginx/snippets/ssl-certificate-app-data-letsencrypt.conf

      # fix btcpay_ssl.conf
      if [ "${letsencryptbtcpay}" = "on" ]; then
        sed -i 's/ssl-certificate-app-data.conf/ssl-certificate-app-data-letsencrypt.conf/' /etc/nginx/sites-available/btcpay_ssl.conf
        sed -i 's/ssl-certificate-app-data.conf/ssl-certificate-app-data-letsencrypt.conf/' /home/admin/assets/nginx/sites-available/btcpay_ssl.conf
      fi

      # fix lnbits_ssl.conf
      if [ "${letsencryptlnbits}" = "on" ]; then
        sed -i 's/ssl-certificate-app-data.conf/ssl-certificate-app-data-letsencrypt.conf/' /etc/nginx/sites-available/lnbits_ssl.conf
        sed -i 's/ssl-certificate-app-data.conf/ssl-certificate-app-data-letsencrypt.conf/' /home/admin/assets/nginx/sites-available/lnbits_ssl.conf
      fi

    elif [ "${nodetype}" = "mynode" ]; then
      echo "# ssl-certificate-app-data-letsencrypt.conf

ssl_certificate ${homedir}/letsencrypt/tls.cert;
ssl_certificate_key ${homedir}/letsencrypt/tls.key;
" | tee /etc/nginx/mynode/mynode_ssl_cert_key_letsencrypt.conf

      # first create and enable systemd service to check for any changes to localip and update the nginx conf file with the new ip address
      echo "#!/bin/bash

sed '1d' /mnt/hdd/mynode/pleb-vpn/pleb-vpn.conf > /mnt/hdd/mynode/pleb-vpn/pleb-vpn.conf.tmp
source /mnt/hdd/mynode/pleb-vpn/pleb-vpn.conf.tmp
rm /mnt/hdd/mynode/pleb-vpn/pleb-vpn.conf.tmp

localip=\$(hostname -I | awk '{print \$1}')
if [ \"\${letsencryptbtcpay}\" = \"on\" ]; then
  sed -i \"s/\(proxy_pass http:\/\/\).*/\1\${localip}:49392;/\" /etc/nginx/sites-enabled/https_btcpayserver.conf
  sed -i 's/mynode_ssl_cert_key.conf/mynode_ssl_cert_key_letsencrypt.conf/' /etc/nginx/sites-enabled/https_btcpayserver.conf
fi
if [ \"\${letsencryptlnbits}\" = \"on\" ]; then
  sed -i \"s/\(proxy_pass http:\/\/\).*/\1\${localip}:49392;/\" /etc/nginx/sites-enabled/https_lnbits.conf
  sed -i 's/mynode_ssl_cert_key.conf/mynode_ssl_cert_key_letsencrypt.conf/' /etc/nginx/sites-enabled/https_lnbits.conf
fi

systemctl reload nginx
" | tee ${homedir}/letsencrypt/set_nginx_localip.sh
      chown admin:admin ${homedir}/letsencrypt/set_nginx_localip.sh
      chmod 755 ${homedir}/letsencrypt/set_nginx_localip.sh

      echo "[Unit]
Description=Add localip to nginx btcpayserver and lnbits for ssl proxy
After=network.service
[Service]
ExecStart=/bin/bash /mnt/hdd/mynode/pleb-vpn/letsencrypt/set_nginx_localip.sh
User=root
Group=root
Restart=on-failure
RestartSec=5s
[Install]
WantedBy=multi-user.target
" | tee /etc/systemd/system/pleb-vpn-letsencrypt-config.service
    fi

  fi

  # test and reload nginx
  nginx -t
  if [ $? -eq 0 ]; then
    echo "nginx config good"
    systemctl reload nginx
  else
    echo "Error: nginx test config fail"
    exit 1
  fi
  # update pleb-vpn.conf
  if [ ! "${letsencryptdomain2}" = "" ]; then
    setting ${plebVPNConf} "2" "letsencryptdomain2" "'${letsencryptdomain2}'"
  fi
  setting ${plebVPNConf} "2" "letsencryptdomain1" "'${letsencryptdomain1}'"
  setting ${plebVPNConf} "2" "letsencryptbtcpay" "${letsencryptbtcpay}"
  setting ${plebVPNConf} "2" "letsencryptlnbits" "${letsencryptlnbits}"
  setting ${plebVPNConf} "2" "letsencrypt_ssl" "on"
  exit 0
}

off() {
  if [ "${nodetype}" = "raspiblitz" ]; then
    source /mnt/hdd/raspiblitz.conf
  fi
  rm -rf /etc/letsencrypt/live
  apt purge -y certbot
  rm ${homedir}/letsencrypt/tls.cert
  rm ${homedir}/letsencrypt/tls.key

  if [ "${nodetype}" = "raspiblitz" ]; then
    rm /etc/nginx/snippets/ssl-certificate-app-data-letsencrypt.conf
    sed -i 's/ssl-certificate-app-data-letsencrypt.conf/ssl-certificate-app-data.conf/' /etc/nginx/sites-available/btcpay_ssl.conf
    sed -i 's/ssl-certificate-app-data-letsencrypt.conf/ssl-certificate-app-data.conf/' /home/admin/assets/nginx/sites-available/btcpay_ssl.conf
    sed -i 's/ssl-certificate-app-data-letsencrypt.conf/ssl-certificate-app-data.conf/' /etc/nginx/sites-available/lnbits_ssl.conf
    sed -i 's/ssl-certificate-app-data-letsencrypt.conf/ssl-certificate-app-data.conf/' /home/admin/assets/nginx/sites-available/lnbits_ssl.conf
  elif [ "${nodetype}" = "mynode" ]; then
    rm /etc/nginx/mynode/mynode_ssl_cert_key_letsencrypt.conf
    systemctl disable pleb-vpn-letsencrypt-config.service
    rm ${homedir}/letsencrypt/set_nginx_localip.sh
    rm /etc/systemd/system/pleb-vpn-letsencrypt-config.service
    sed -i "s/\(proxy_pass http:\/\/\).*/\1127.0.0.1:49392;/" /etc/nginx/sites-enabled/https_btcpayserver.conf
    sed -i 's/mynode_ssl_cert_key_letsencrypt.conf/mynode_ssl_cert_key.conf/' /etc/nginx/sites-enabled/https_btcpayserver.conf
    sed -i "s/\(proxy_pass http:\/\/\).*/\1127.0.0.1:49392;/" /etc/nginx/sites-enabled/https_lnbits.conf
    sed -i 's/mynode_ssl_cert_key_letsencrypt.conf/mynode_ssl_cert_key.conf/' /etc/nginx/sites-enabled/https_lnbits.conf
  fi

  # reload nginx
  nginx -t
  if [ ! $? -eq 0 ]; then
    echo "ERROR: nginx config error"
    exit 1
  fi
  systemctl reload nginx

  # update pleb-vpn.conf
  setting ${plebVPNConf} "2" "letsencryptdomain2" ""
  setting ${plebVPNConf} "2" "letsencryptdomain1" ""
  setting ${plebVPNConf} "2" "letsencryptbtcpay" "off"
  setting ${plebVPNConf} "2" "letsencryptlnbits" "off"
  setting ${plebVPNConf} "2" "letsencrypt_ssl" "off"
  exit 0
}

case "${1}" in
  on) on "${2}" "${3}" "${4}" "${5}" "${6}" "${7}" "${8}" ;;
  off) off ;;
  *) echo "config script to turn letsencrypt for BTCPayServer or LNBits on or off"; echo "letsencrypt.install.sh [on|off]"; exit 1 ;;
esac