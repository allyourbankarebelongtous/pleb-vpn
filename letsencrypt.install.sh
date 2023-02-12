#!/bin/bash

# script to turn letsencrypt for BTCPayServer or LNBits on or off

# command info
if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "-help" ]; then
  echo "config script to turn letsencrypt for BTCPayServer or LNBits on or off"
  echo "letsencrypt.install.sh [on|off]"
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

on() {
  source ${plebVPNConf}
  source /mnt/hdd/raspiblitz.conf
  local keepExisting="${1}"
  sudo apt install -y certbot
  if [ ! "${keepExisting}" = "1" ]; then
    # check for existing challenge
    isExisting=$(ls /mnt/hdd/app-data/pleb-vpn/letsencrypt | grep -c acmedns.json)
    if [ ! ${isExisting} -eq 0 ]; then
      whiptail --title "Use Existing DNS Authentication?" \
      --yes-button "Use Existing Authentication" \
      --no-button "Create New Authentication" \
      --yesno "There's an existing DNS authenticaton found from a previous install of letsencrypt for ${service}. Do you wish to reuse it or to start fresh?" 10 80
      if [ $? -eq 1 ]; then
        keepExisting="0"
      else
        keepExisting="1"
      fi
    else
      keepExisting="0"
    fi
  fi
  if [ "${keepExisting}" = "0" ]; then
    # new certs with new dns challenge

    # set up acme dns challenge
    sudo mkdir /mnt/hdd/app-data/pleb-vpn/letsencrypt
    sudo wget https://github.com/joohoi/acme-dns-certbot-joohoi/raw/master/acme-dns-auth.py
    sudo mv acme-dns-auth.py /mnt/hdd/app-data/pleb-vpn/letsencrypt
    sudo cp /mnt/hdd/app-data/pleb-vpn/letsencrypt/acme-dns-auth.py /etc/letsencrypt/
    sudo chmod 777 /etc/letsencrypt/acme-dns-auth.py

    # clean up failed/old installs
    if [ $(ls /etc/letsencrypt | grep -c acmedns.json) -gt 0 ]; then
      sudo rm -rf /etc/letsencrypt/accounts &> /dev/null
      sudo rm /etc/letsencrypt/acmedns.json &> /dev/null
      sudo rm -rf /etc/letsencrypt/archive &> /dev/null
      sudo rm -rf /etc/letsencrypt/csr &> /dev/null
      sudo rm -rf /etc/letsencrypt/keys &> /dev/null
      sudo rm -rf /etc/letsencrypt/live &> /dev/null
      sudo rm -rf /etc/letsencrypt/renew* &> /dev/null
    fi

    # get service(s) to enable letsencrypt for
    letsencryptBTCPay="off"
    letsencryptLNBits="off"
    OPTIONS=()
    OPTIONS+=(b 'BTCPayServer' ${letsencryptBTCPay})
    OPTIONS+=(l 'LNBits' ${letsencryptLNBits})
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
############ CHECK IF BTCPAY IS INSTALLED
      letsencryptBTCPay="on"
    fi

    # LNBits
    check=$(echo "${CHOICES}" | grep -c "l")
    if [ ${check} -eq 1 ]; then
############ CHECK IF LNBITS IS INSTALLED
      letsencryptLNBits="on";
    fi

    # get domain names
    sudo touch /var/cache/raspiblitz/.tmp
    sudo chmod 777 /var/cache/raspiblitz/.tmp
    whiptail --title "Enter Domain" --inputbox "Enter the first domain name that you wish to secure (example: btcpay.mydomain.com)" 11 80 2>/var/cache/raspiblitz/.tmp
    letsencryptDomain1=$(cat /var/cache/raspiblitz/.tmp)
    whiptail --title "Use a second domain?" \
    --yes-button "Yes" \
    --no-button "No" \
    --yesno "
Do you wish to encrypt a second domain?
(you must have a second domain if you selected both BTCPayServer and LNBits)" 10 80
    if [ $? -eq 1 ]; then
      whiptail --title "Enter Domain" --inputbox "Enter the second domain name that you wish to secure (example: lnbits.mydomain.com)" 11 80 2>/var/cache/raspiblitz/.tmp
      letsencryptDomain2=$(cat /var/cache/raspiblitz/.tmp)
    else
      letsencryptDomain2=""
    fi
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

    # get certs
    if [ ! "${letsencryptDomain2}" = "" ]; then
      sudo certbot certonly --manual --manual-auth-hook /etc/letsencrypt/acme-dns-auth.py --preferred-challenges dns --register-unsafely-without-email --debug-challenges -d ${letsencryptDomain1} -d ${letsencryptDomain2}
    else
      sudo certbot certonly --manual --manual-auth-hook /etc/letsencrypt/acme-dns-auth.py --preferred-challenges dns --register-unsafely-without-email --debug-challenges -d ${letsencryptDomain1}
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

    # link certs to /mnt/hdd/app-data/pleb-vpn/letsencrypt
    sudo ln -s /etc/letsencrypt/live/${letsencryptDomain1}/fullchain.pem /mnt/hdd/app-data/pleb-vpn/letsencrypt/tls.cert
    sudo ln -s /etc/letsencrypt/live/${letsencryptDomain1}/privkey.pem /mnt/hdd/app-data/pleb-vpn/letsencrypt/tls.key

    # create letsencrypt ssl snippet
echo "# ssl-certificate-app-data-letsencrypt.conf

ssl_certificate /mnt/hdd/app-data/pleb-vpn/letsencrypt/tls.cert;
ssl_certificate_key /mnt/hdd/app-data/pleb-vpn/letsencrypt/tls.key;
" | sudo tee /etc/nginx/snippets/ssl-certificate-app-data-letsencrypt.conf

    # fix btcpay_ssl.conf
    if [ "${letsencryptBTCPay}" = "on" ]; then
      sudo sed -i 's/ssl-certificate-app-data.conf/ssl-certificate-app-data-letsencrypt.conf/' /etc/nginx/sites-available/btcpay_ssl.conf
    fi

    # fix lnbits_ssl.conf
    if [ "${letsencryptLNBits}" = "on" ]; then
      sudo sed -i 's/ssl-certificate-app-data.conf/ssl-certificate-app-data-letsencrypt.conf/' /etc/nginx/sites-available/lnbits_ssl.conf
    fi

    # reload nginx
    sudo nginx -t
    sudo systemctl reload nginx

    # update pleb-vpn.conf
    if [ ! "${letsencryptDomain2}" = "" ]; then
      setting ${plebVPNConf} "2" "letsencryptDomain2" "'${letsencryptDomain2}'"
    fi
    setting ${plebVPNConf} "2" "letsencryptDomain1" "'${letsencryptDomain1}'"
    setting ${plebVPNConf} "2" "letsencryptBTCPay" "${letsencryptBTCPay}"
    setting ${plebVPNConf} "2" "letsencryptLNBits" "${letsencryptLNBits}"
    setting ${plebVPNConf} "2" "letsencrypt" "on"
  else

    # move acme-dns-auth.py and acmedns.json
    sudo cp -p /mnt/hdd/app-data/encrypt/acme-dns-auth.py /etc/letsencrypt/
    sudo cp -p /mnt/hdd/app-data/encrypt/acmedns.json /etc/letsencrypt/

    # get certs
    if [ ! "${letsencryptDomain2}" = "" ]; then
      sudo certbot certonly --noninteractive --agree-tos --manual --manual-auth-hook /etc/letsencrypt/acme-dns-auth.py --preferred-challenges dns --register-unsafely-without-email -d ${letsencryptDomain1} -d ${letsencryptDomain2}
    else
      sudo certbot certonly --noninteractive --agree-tos --manual --manual-auth-hook /etc/letsencrypt/acme-dns-auth.py --preferred-challenges dns --register-unsafely-without-email -d ${letsencryptDomain1}
    fi

    # link certs to /mnt/hdd/app-data/pleb-vpn/letsencrypt
    sudo rm /mnt/hdd/app-data/pleb-vpn/letsencrypt/tls.cert &> /dev/null
    sudo rm /mnt/hdd/app-data/pleb-vpn/letsencrypt/tls.key &> /dev/null
    sudo ln -s /etc/letsencrypt/live/${letsencryptDomain1}/fullchain.pem /mnt/hdd/app-data/pleb-vpn/letsencrypt/tls.cert
    sudo ln -s /etc/letsencrypt/live/${letsencryptDomain1}/privkey.pem /mnt/hdd/app-data/pleb-vpn/letsencrypt/tls.key

    # create letsencrypt ssl snippet
echo "# ssl-certificate-app-data-letsencrypt.conf

ssl_certificate /mnt/hdd/app-data/pleb-vpn/letsencrypt/tls.cert;
ssl_certificate_key /mnt/hdd/app-data/pleb-vpn/letsencrypt/tls.key;
" | sudo tee /etc/nginx/snippets/ssl-certificate-app-data-letsencrypt.conf

    # fix btcpay_ssl.conf
    if [ "${letsencryptBTCPay}" = "on" ]; then
      sudo sed -i 's/ssl-certificate-app-data.conf/ssl-certificate-app-data-letsencrypt.conf/' /etc/nginx/sites-available/btcpay_ssl.conf
    fi

    # fix lnbits_ssl.conf
    if [ "${letsencryptLNBits}" = "on" ]; then
      sudo sed -i 's/ssl-certificate-app-data.conf/ssl-certificate-app-data-letsencrypt.conf/' /etc/nginx/sites-available/lnbits_ssl.conf
    fi

    # reload nginx
    sudo nginx -t
    sudo systemctl reload nginx
  fi
  exit 0
}

off() {
  source ${plebVPNConf}
  source /mnt/hdd/raspiblitz.conf
  sudo rm -rf /etc/letsencrypt/live
  sudo apt purge -y certbot
  sudo rm /etc/nginx/snippets/ssl-certificate-app-data-letsencrypt.conf
  if [ "${letsencryptBTCPay}" = "on" ]; then
    sudo sed -i 's/ssl-certificate-app-data-letsencrypt.conf/ssl-certificate-app-data.conf/' /etc/nginx/sites-available/btcpay_ssl.conf
  fi
  if [ "${letsencryptLNBits}" = "on" ]; then
    sudo sed -i 's/ssl-certificate-app-data-letsencrypt.conf/ssl-certificate-app-data.conf/' /etc/nginx/sites-available/lnbits_ssl.conf
  fi

  # reload nginx
  sudo nginx -t
  sudo systemctl reload nginx

  # update pleb-vpn.conf
  setting ${plebVPNConf} "2" "letsencryptDomain2" ""
  setting ${plebVPNConf} "2" "letsencryptDomain1" ""
  setting ${plebVPNConf} "2" "letsencryptBTCPay" "off"
  setting ${plebVPNConf} "2" "letsencryptLNBits" "off"
  setting ${plebVPNConf} "2" "letsencrypt" "off"
  exit 0
}

case "${1}" in
  on) on "${2}" ;;
  off) off ;;
esac