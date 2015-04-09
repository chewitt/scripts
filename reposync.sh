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
    echo "ERROR: This script must be run as root!"
    exit 1
  fi
}

check_arch(){
  if [ "$(uname -m)" = "i686" ]; then
    echo "ERROR: This script must be run on CentOS 64-bit!"
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
    read LIVE_USER
    echo -n "Password: "
    read LIVE_PASS
    echo ""
    while true; do
      read -p "You entered $LIVE_USER and $LIVE_PASS; correct? [y/n]" answer
      case $answer in
        [Yy]* ) break;;
        [Nn]* ) check_credentials;;
        * ) echo "Please answer [Y]es or [N]o.";;
      esac
    done
    echo "LIVE_USER=$LIVE_USER" > ~/.rsalive
    echo "LIVE_PASS=$LIVE_PASS" >> ~/.rsalive
  fi
}

check_dependencies(){
  PKG_REPOSYNC=$(which reposync)
  if [ -z "$PKG_REPOSYNC" ]; then
    yum -q -y install yum-utils
  fi

  PKG_CREATEREPO=$(which createrepo)
  if [ -z "$PKG_CREATEREPO" ]; then
    yum -q -y install createrepo
  fi

  PKG_HTTPD=$(which httpd)
  if [ -z "$PKG_HTTPD" ]; then
    yum -q -y install httpd
    chkconfig --levels 235 httpd on
    HOSTNAME=$(grep HOSTNAME /etc/sysconfig/network | sed 's/HOSTNAME=//g')
    sed -i "s/#ServerName www.example.com:80/ServerName $HOSTNAME/g" /etc/httpd/conf/httpd.conf
    service httpd start
  fi

  PORT80=$(grep 80 /etc/sysconfig/iptables)
  if [ -z "$PORT80" ]; then
    service iptables stop
    LINE=$(sed -n "/22/{=;}" /etc/sysconfig/iptables)
    LINE=$(( $LINE + 1 ))
    RULE="-A INPUT -m state --state NEW -m tcp -p tcp --dport 80 -j ACCEPT"
    sed -i "$LINE"i"$RULE" /etc/sysconfig/iptables
    service iptables start
  fi

  REPOFILE="/etc/yum.repos.d/smcupdate.repo"
  if [ ! -f /etc/yum.repos.d/smcupdate.repo ]; then
    echo "[smcupdate]" > "$REPOFILE"
    echo "name=Security Analytics Yum Repo" >> "$REPOFILE"
    echo "baseurl = https://$LIVE_USER:$LIVE_PASS@smcupdate.emc.com/nw10/rpm" >> "$REPOFILE"
	#echo "baseurl = http://repo.rsalab.net/smcupdate" >> "$REPOFILE"
    echo "enabled = 0" >> "$REPOFILE"
  fi

  if [ ! -d /var/www/html/smcupdate ]; then
    mkdir -p /var/www/html/smcupdate
  fi

  CRONTAB=$(crontab -l | grep reposync.sh)
  if [ -z "$CRONTAB" ]; then
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
  restorecon -rv /var/www/html
}

main(){
  check_root
  check_arch
  check_credentials
  check_dependencies
  do_cleanzeros
  do_reposync
  do_createrepo
  do_selinux
}

main
exit 0