#!/bin/bash

#################################################################################
#
#  Copyright (C) 2015 Christian Hewitt (github@chrishewitt.net)
#
#  This script is free software: you can redistribute it and/or modify it under
#  the terms of the GNU General Public License as published by the Free Software
#  Foundation, either version 2 of the License, or (at your option) any later
#  version.
#
#  This script is distributed in the hope that it will be useful, but WITHOUT 
#  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
#  FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
#  Please refer to the GNU General Public License <http://www.gnu.org/licenses/>
#
#################################################################################
#
#   Content: A simple script for building and populating a local mirror of the 
#   RSA Security Analytics 'smcupdate' repo from a CentOS minimal server image.
#
#################################################################################

check_root(){
  if [ "$(id -u)" != "0" ]; then
    clear
    echo "ERROR: This script must be run as root!"
    echo ""
    exit 1
  fi
}

check_distro(){
  if [ -f /etc/centos-release ] && [ "$(uname -m)" = "x86_64" ]; then
    VERSION=$(grep -o '[0-9]\+' /etc/centos-release | head -n 1)
  else
    clear
    echo "ERROR: This script must be run on a CentOS v6/7 x86_64 release!"
    echo ""
    exit 1
  fi
}

check_credentials(){
  if [ -f /root/.rsalive ]; then
    . /root/.rsalive
  else
    clear
    echo "Please enter your RSA Live! credentials"
    echo ""
    echo -n "Username: "
    read -r LIVE_USER
    echo -n "Password: "
    read -r LIVE_PASS
    echo ""
    while true; do
      read -rp "You entered $LIVE_USER and $LIVE_PASS; correct? [y/n]" answer
      case $answer in
        [Yy]* ) break;;
        [Nn]* ) check_credentials;;
        * ) echo "Please answer [Y]es or [N]o.";;
      esac
    done
    echo "LIVE_USER=$LIVE_USER" > ~/.rsalive
    echo "LIVE_PASS=$LIVE_PASS" >> ~/.rsalive
    echo ""
  fi
}

check_dependencies(){
  YUM_CERT=$(rpm -qa gpg-pubkey*)
  if [ -z "$YUM_CERT" ]; then
    echo "Installing GPG certs"
    if [ "$VERSION" = "7" ]; then
      rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
    else
      rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-6
    fi
  fi

  YUM_REPOSYNC=$(rpm -qa | grep yum-utils)
  if [ -z "$YUM_REPOSYNC" ]; then
    echo "Installing yum-utils"
    yum -q -y install yum-utils
  fi

  YUM_CREATEREPO=$(rpm -qa | grep createrepo)
  if [ -z "$YUM_CREATEREPO" ]; then
    echo "Installing createrepo"
    yum -q -y install createrepo
  fi

  YUM_HTTPD=$(rpm -qa | grep httpd)
  LVHOME=$(fdisk -l | grep lv_home | awk '{print $5}')
  LVROOT=$(fdisk -l | grep lv_root | awk '{print $5}')
  if [ -z "$YUM_HTTPD" ]; then
    echo "Installing and configuring httpd"
    yum -q -y install httpd
    if [ "$LVHOME" -gt "$LVROOT" ]; then
      echo "Moving /var/www to /home/www"
      mv /var/www /home/
      ln -sf /home/www /var/www
      ln -sf /home/www /root/www
    else
      ln -sf /var/www /root/www
    fi
    if [ "$VERSION" = "7" ]; then
      systemctl enable httpd.service
      HOSTNAME=$(cat /etc/hostname)
      sed -i "s/#ServerName www.example.com:80/ServerName $HOSTNAME/g" /etc/httpd/conf/httpd.conf
      systemctl start httpd.service
    else
      chkconfig --levels 235 httpd on
      HOSTNAME=$(grep HOSTNAME /etc/sysconfig/network | sed 's/HOSTNAME=//g')
      sed -i "s/#ServerName www.example.com:80/ServerName $HOSTNAME/g" /etc/httpd/conf/httpd.conf
      service httpd start
    fi
  fi

  echo "Configuring firewall"
  if [ "$VERSION" = "7" ]; then
    PORT80=$(firewall-cmd --zone=public --list-ports | grep 80/tcp)
    if [ -z "$PORT80" ]; then
      firewall-cmd --zone=public --add-port=80/tcp --permanent
      firewall-cmd --reload
    fi
  else
    PORT80=$(grep 80 /etc/sysconfig/iptables)
    if [ -z "$PORT80" ]; then
      service iptables stop
      LINE=$(sed -n "/22/{=;}" /etc/sysconfig/iptables)
      LINE=$(( LINE + 1 ))
      RULE="-A INPUT -m state --state NEW -m tcp -p tcp --dport 80 -j ACCEPT"
      sed -i "$LINE"i"$RULE" /etc/sysconfig/iptables
      service iptables start
    fi
  fi

  REPOFILE="/etc/yum.repos.d/smcupdate.repo"
  if [ ! -f /etc/yum.repos.d/smcupdate.repo ]; then
    echo "Configuring smcupdate.repo"
    echo "[smcupdate]" > "$REPOFILE"
    echo "name=Security Analytics Yum Repo" >> "$REPOFILE"
    echo "baseurl = https://$LIVE_USER:$LIVE_PASS@smcupdate.emc.com/nw10/rpm" >> "$REPOFILE"
    #echo "baseurl = http://repo.rsalab.net/smcupdate" >> "$REPOFILE"
    echo "enabled = 0" >> "$REPOFILE"
  fi

  if [ ! -d /var/www/html/smcupdate ]; then
    echo "Configuring webserver folders"
    mkdir -p /var/www/html/smcupdate
  fi

  CRONTAB=$(crontab -l | grep reposync.sh)
  if [ -z "$CRONTAB" ]; then
    echo "Configuring crontab entries"
    (crontab -l ; echo "30 0 * * * /bin/bash /root/reposync.sh >> /root/reposync.log 2>&1")| crontab -
    (crontab -l ; echo "30 12 * * * /bin/bash /root/reposync.sh >> /root/reposync.log 2>&1")| crontab -
    touch /root/reposync.log
  fi
}

do_cleanzeros(){
  find /var/www/html/smcupdate -size 0 -exec rm -f {} +
}

do_reposync(){
  /usr/bin/python -tt /usr/bin/reposync -r smcupdate -p /var/www/html
}

do_createrepo(){
  createrepo /var/www/html/smcupdate
}

do_selinux(){
  if [ -h /var/www ]; then
    chcon -R -t httpd_user_content_t /home/www
  else
    restorecon -rv /var/www/html
  fi
}

main(){
  check_root
  check_distro
  check_credentials
  check_dependencies
  do_cleanzeros
  do_reposync
  do_createrepo
  do_selinux
}

main
exit 0