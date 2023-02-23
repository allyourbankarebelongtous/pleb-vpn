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
  local isRestore="${2}"
  sudo apt install -y certbot
  if [ ! "${keepExisting}" = "1" ]; then
    # check for existing challenge
    isExisting=$(ls /mnt/hdd/app-data/pleb-vpn/letsencrypt | grep -c acmedns.json)
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
  if [ "${keepExisting}" = "0" ]; then
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
3) Have updated the A record of each domain to ${vpnIP}
4) Are ready to update the CNAME record for each domain when instructed

Are you ready to continue?
" 20 100
    if [ $? -eq 1 ]; then
      echo "user canceled"
      exit 0
    fi

    # set up acme dns challenge
    sudo mkdir /mnt/hdd/app-data/pleb-vpn/letsencrypt
    sudo wget https://github.com/joohoi/acme-dns-certbot-joohoi/raw/master/acme-dns-auth.py
    sudo mv acme-dns-auth.py /mnt/hdd/app-data/pleb-vpn/letsencrypt
    sudo cp /mnt/hdd/app-data/pleb-vpn/letsencrypt/acme-dns-auth.py /etc/letsencrypt/
    sudo chmod 755 /etc/letsencrypt/acme-dns-auth.py

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
    if [ ${#letsencryptBTCPay} -eq 0 ]; then letsencryptBTCPay="off"; fi
    if [ ${#letsencryptLNBits} -eq 0 ]; then letsencryptLNBits="off"; fi
    OPTIONS=()
    if [ "${BTCPayServer}" = "on" ]; then
      OPTIONS+=(b 'BTCPayServer' ${letsencryptBTCPay})
    fi
    if [ "${BTCPayServer}" = "on" ]; then
      OPTIONS+=(l 'LNBits' ${letsencryptLNBits})
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
      letsencryptBTCPay="on"
    fi

    # LNBits
    check=$(echo "${CHOICES}" | grep -c "l")
    if [ ${check} -eq 1 ]; then
      letsencryptLNBits="on";
    fi

    # get domain names
    sudo touch /var/cache/raspiblitz/.tmp
    sudo chmod 777 /var/cache/raspiblitz/.tmp
    whiptail --title "Enter Domain" --inputbox "Enter the first domain name that you wish to secure (example: btcpay.mydomain.com)" 11 80 2>/var/cache/raspiblitz/.tmp
    letsencryptDomain1=$(cat /var/cache/raspiblitz/.tmp)
    # check first domain name
    if [ "${letsencryptDomain1}" = "" ]; then
      whiptail --title "Invalid Domain" --inputbox "Domain cannot be blank. 
Re-Enter the first domain name that you wish to secure (example: btcpay.mydomain.com)" 12 80 2>/var/cache/raspiblitz/.tmp
      letsencryptDomain1=$(cat /var/cache/raspiblitz/.tmp)
      if [ "${letsencryptDomain1}" = "" ]; then
        echo "ERROR: Invalid domain. Domain cannot be blank. Please try again later"
        echo "LetsEncrypt install canceled"
        exit 1
      fi
    fi
    domain1host=$(host ${letsencryptDomain1} | grep -v IPv6 | cut -d " " -f4)
    if [ ! "${domain1host}" = "${vpnIP}" ]; then
      whiptail --title "Invalid Domain" \
      --yes-button "Check Again" \
      --no-button "Re-Enter Domain" \
      --yesno "
ERROR: ${letsencryptDomain1} resolves to host IP of '${domain1host}'. Are you sure you entered it correctly?
Have you added '${vpnIP}' to the A record to point the domain at your VPS? If you entered your 
domain name incorrectly chose <Re-Enter Domain> below. If you fixed your A record and want to check 
the host of ${letsencryptDomain1} again, chose <Check Again> below.
" 20 100
      if [ $? -eq 0 ]; then
        whiptail --title "Enter Domain" --inputbox "Enter the first domain name that you wish to secure (example: btcpay.mydomain.com)" 11 80 2>/var/cache/raspiblitz/.tmp
        letsencryptDomain1=$(cat /var/cache/raspiblitz/.tmp)
        domain1host=$(host ${letsencryptDomain1} | grep -v IPv6 | cut -d " " -f4)
      else
        echo "LetsEncrypt install canceled"
        exit 1
      fi
      if [ ! "${domain1host}" = "${vpnIP}" ]; then
        echo "ERROR: ${letsencryptDomain1} points to ${domain1host}, should point to ${vpnIP}."
        echo "LetsEncrypt install canceled"
        sleep 10
        exit 1
      fi
    fi
    if [ "${letsencryptBTCPay}" = "on" ] && [ "${letsencryptLNBits}" = "on" ]; then
      whiptail --title "Enter Domain" --inputbox "Enter the second domain name that you wish to secure (example: lnbits.mydomain.com)" 11 80 2>/var/cache/raspiblitz/.tmp
      letsencryptDomain2=$(cat /var/cache/raspiblitz/.tmp)
    else
      letsencryptDomain2=""
    fi
    # check second domain name
    if [ ! "${letsencryptDomain2}" = "" ]; then
      domain2host=$(host ${letsencryptDomain2} | grep -v IPv6 | cut -d " " -f4)
      if [ ! "${domain2host}" = "${vpnIP}" ]; then
        whiptail --title "Invalid Domain" \
        --yes-button "Check Again" \
        --no-button "Re-Enter Domain" \
        --yesno "
ERROR: ${letsencryptDomain2} resolves to host IP of '${domain2host}'. Are you sure you entered it correctly?
Have you added '${vpnIP}' to the A record to point the domain at your VPS? If you entered your 
domain name incorrectly chose <Re-Enter Domain> below. If you fixed your A record and want to check 
the host of ${letsencryptDomain1} again, chose <Check Again> below.
" 20 120
        if [ $? -eq 0 ]; then
          whiptail --title "Enter Domain" --inputbox "Enter the second domain name that you wish to secure (example: btcpay.mydomain.com)" 11 80 2>/var/cache/raspiblitz/.tmp
          letsencryptDomain1=$(cat /var/cache/raspiblitz/.tmp)
          domain1host=$(host ${letsencryptDomain1} | grep -v IPv6 | cut -d " " -f4)
        else
          echo "LetsEncrypt install canceled"
          exit 1
        fi
        if [ ! "${domain2host}" = "${vpnIP}" ]; then
          echo "ERROR: ${letsencryptDomain2} points to ${domain2host}, should point to ${vpnIP}."
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
    sudo chmod -R 755 /etc/letsencrypt
    sudo ln -s /etc/letsencrypt/live/"${letsencryptDomain1}"/fullchain.pem /mnt/hdd/app-data/pleb-vpn/letsencrypt/tls.cert
    sudo ln -s /etc/letsencrypt/live/"${letsencryptDomain1}"/privkey.pem /mnt/hdd/app-data/pleb-vpn/letsencrypt/tls.key

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
    if [ ! $? -eq 0 ]; then
      echo "ERROR: nginx config error. Uninstall letsencrypt service to restore nginx config"
      exit 1
    fi
    sudo systemctl reload nginx

    # save acme authenticaton
    sudo cp -p /etc/letsencrypt/acmedns.json /mnt/hdd/app-data/pleb-vpn/letsencrypt/

  else
    # use existing DNS authenticaton

    # copy acme-dns-auth.py and acmedns.json
    sudo cp /mnt/hdd/app-data/pleb-vpn/letsencrypt/acme-dns-auth.py /etc/letsencrypt/
    sudo cp /mnt/hdd/app-data/pleb-vpn/letsencrypt/acmedns.json /etc/letsencrypt/
    sudo chmod -R 755 /etc/letsencrypt

    # check for domain name(s) in pleb-vpn.conf and if not present, get them from acmedns.json
    if [ "${letsencryptDomain1}" = "" ]; then
      domains=$(sudo cat /mnt/hdd/app-data/pleb-vpn/letsencrypt/acmedns.json | jq . | grep ": {" | cut -d ":" -f1)
      domainCount=$(sudo cat /mnt/hdd/app-data/pleb-vpn/letsencrypt/acmedns.json | jq . | grep -c ": {")
      letsencryptDomain1=$(echo "${domains}" | sed -n "1p" | sed 's/ //g' | sed 's/\"//g')
      if [ ${domainCount} -gt 1 ]; then
        letsencryptDomain2=$(echo "${domains}" | sed -n "2p" | sed 's/ //g' | sed 's/\"//g')
      fi
    fi
    if [ ! "${isRestore}" = "1" ]; then

      # get service(s) to enable letsencrypt for
      if [ ${#letsencryptBTCPay} -eq 0 ]; then letsencryptBTCPay="off"; fi
      if [ ${#letsencryptLNBits} -eq 0 ]; then letsencryptLNBits="off"; fi
      OPTIONS=()
      if [ "${BTCPayServer}" = "on" ]; then
        OPTIONS+=(b 'BTCPayServer' ${letsencryptBTCPay})
      fi
      if [ "${BTCPayServer}" = "on" ]; then
        OPTIONS+=(l 'LNBits' ${letsencryptLNBits})
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
        letsencryptBTCPay="on"
      fi

      # LNBits
      check=$(echo "${CHOICES}" | grep -c "l")
      if [ ${check} -eq 1 ]; then
        letsencryptLNBits="on";
      fi

      whiptail --title "LetsEncrypt re-create cert" \
      --yes-button "Yes" \
      --no-button "No" \
      --yesno "
CertBot is about to re-install your LetsEncrypt cert using the following information:

Domain 1: ${letsencryptDomain1}
Domain 2: ${letsencryptDomain2}
BTCPayServer LetsEncrypt: ${letsencryptBTCPay}
LNBits LetsEncrypt: ${letsencryptLNBits}

If the above information is incorrect, re-run this script and create a new DNS Authentication.

Is the information correct?
" 19 100
      if [ $? -eq 1 ]; then
        echo "user canceled"
        exit 0
      fi
    fi

    # get certs
    if [ ! "${letsencryptDomain2}" = "" ]; then
      sudo certbot certonly --noninteractive --agree-tos --manual --manual-auth-hook /etc/letsencrypt/acme-dns-auth.py --preferred-challenges dns --register-unsafely-without-email -d ${letsencryptDomain1} -d ${letsencryptDomain2}
    else
      sudo certbot certonly --noninteractive --agree-tos --manual --manual-auth-hook /etc/letsencrypt/acme-dns-auth.py --preferred-challenges dns --register-unsafely-without-email -d ${letsencryptDomain1}
    fi

    # link certs to /mnt/hdd/app-data/pleb-vpn/letsencrypt
    sudo chmod -R 755 /etc/letsencrypt
    sudo rm /mnt/hdd/app-data/pleb-vpn/letsencrypt/tls.cert &> /dev/null
    sudo rm /mnt/hdd/app-data/pleb-vpn/letsencrypt/tls.key &> /dev/null
    sudo ln -s /etc/letsencrypt/live/"${letsencryptDomain1}"/fullchain.pem /mnt/hdd/app-data/pleb-vpn/letsencrypt/tls.cert
    sudo ln -s /etc/letsencrypt/live/"${letsencryptDomain1}"/privkey.pem /mnt/hdd/app-data/pleb-vpn/letsencrypt/tls.key

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
    if [ ! $? -eq 0 ]; then
      echo "ERROR: nginx config error. Uninstall letsencrypt service to restore nginx config"
      exit 1
    fi
    sudo systemctl reload nginx

  fi
  # update pleb-vpn.conf
  if [ ! "${letsencryptDomain2}" = "" ]; then
    setting ${plebVPNConf} "2" "letsencryptDomain2" "'${letsencryptDomain2}'"
  fi
  setting ${plebVPNConf} "2" "letsencryptDomain1" "'${letsencryptDomain1}'"
  setting ${plebVPNConf} "2" "letsencryptBTCPay" "${letsencryptBTCPay}"
  setting ${plebVPNConf} "2" "letsencryptLNBits" "${letsencryptLNBits}"
  setting ${plebVPNConf} "2" "letsencrypt_ssl" "on"
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
  if [ ! $? -eq 0 ]; then
    echo "ERROR: nginx config error"
    exit 1
  fi
  sudo systemctl reload nginx

  # update pleb-vpn.conf
  setting ${plebVPNConf} "2" "letsencryptDomain2" ""
  setting ${plebVPNConf} "2" "letsencryptDomain1" ""
  setting ${plebVPNConf} "2" "letsencryptBTCPay" "off"
  setting ${plebVPNConf} "2" "letsencryptLNBits" "off"
  setting ${plebVPNConf} "2" "letsencrypt_ssl" "off"
  exit 0
}

case "${1}" in
  on) on "${2}" "${3}";;
  off) off ;;
esac