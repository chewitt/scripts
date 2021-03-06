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
#   Content: A simple script for updating the zimbraMtaMyNetworks config on a
#   Zimbra mail server when the trusted host relaying through it resides on a 
#   dynamic IP address that changes frequently.
#
#################################################################################

ZMSERVER="mail.relayserver.org.uk"  # the static ip host we will relay through
ZMSUBNET="192.168.1.0/24"           # the static ip host local trusted network(s)
MAILHOST="mail.myserver.me.uk"      # the dynamic ip host

do_getuser(){
  USER=$(whoami)
  if [ "$USER" != "root" ]; then
    exit 1
  fi
}

do_getcurrent(){
  CURRENT=$(dig $MAILHOST a | grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}" | grep -v -e ^192.168 -e ^172.16 -e ^10.10)
}

do_getconfigured(){
  cd /opt/zimbra/bin
  # this assumes the value we want to compare against is the last entry in the trusted networks list
  CONFIGURED=$(./zmprov gs $ZMSERVER zimbraMtaMyNetworks | grep zimbraMtaMyNetworks | awk '{print $NF}')
}

do_compare(){
  if [ "$CURRENT" != "$CONFIGURED" ]; then
    cd /opt/zimbra/bin
    ./zmprov ms "$ZMSERVER" zimbraMtaMyNetworks "127.0.0.0/8 $ZMSUBNET $CURRENT"
    cd /opt/zimbra/postfix/sbin
    ./postfix reload
  fi
}

main(){
  do_getuser
  do_getcurrent
  do_getconfigured
  do_compare
}
  
main
exit 0
