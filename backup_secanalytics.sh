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
#   Content: A backup script for RSA Security Analytics v10.4+ appliances
#
#################################################################################

do_checkroot(){
  if [ "$(id -u)" != "0" ]; then
    echo "ERROR: This script must be run as root!"
    echo ""
    exit 1
  fi
}

do_recipe(){

  recipe[0]="backup_etc"
  recipe[1]="backup_puppetssl"

  if [ -f /usr/bin/mongodump ]; then
    recipe=("${recipe[@]}" "backup_mongodb")
  fi
  
  if [ -d /var/lib/netwitness/uax ]; then
    recipe=("${recipe[@]}" "backup_jetty")
  fi

  if [ -d /home/rsasoc/rsa/soc/reporting-engine ]; then
    recipe=("${recipe[@]}" "backup_reportingengine")
  fi

  if [ -d /etc/netwitness/ng ]; then
    recipe=("${recipe[@]}" "backup_coreappliance")
  fi

  if [ -d /var/lib/netwitness/rsamalware ]; then
    recipe=("${recipe[@]}" "backup_malware")
  fi
  
  if [ -d /opt/rsa/esa ]; then
    recipe=("${recipe[@]}" "backup_esa")
  fi
  
  if [ -d /var/netwitness/logcollector ]; then
    recipe=("${recipe[@]}" "backup_logcollector")
  fi

  if [ -d /var/netwitness/warehouseconnector ]; then
    recipe=("${recipe[@]}" "backup_wconnector")
  fi
}

do_backup(){
  tempdir=$(mktemp -d)
  backupname="backup_$(hostname)_$(date +%Y%m%d%H%M%S)"
  backupfile="$backupname.tar.bz2"
  mkdir -p "$tempdir/$backupname"
  cd "$tempdir/$backupname"
  for i in "${recipe[@]}"
  do
    $i
  done
}

do_tarball(){
  echo ""
  echo "INFO: Creating $backupfile"
  cd "$tempdir"
  tar jcf "$backupfile" "$backupname"
}

do_offbox(){
  echo ""
  echo "INFO: Copying backup file to off-box location"
  mkdir /mnt/tmpmnt
  mount -t cifs //corp.rsalab.net/BACKUPS /mnt/tmpmnt -o username=backups,password=secret
  cp "$tempdir/$backupfile" /mnt/tmpmnt
  umount /mnt/tmpmnt
}

do_localcopy(){
  echo ""
  echo "INFO: Moving backup file to /root"
  mv "$tempdir/$backupfile" ~/
}

do_cleanup(){
  rm -rf "$tempdir"
}

backup_etc(){
  echo ""
  echo "INFO: Backing up /etc"
  tar -C / --atime-preserve --recursion -cphjf etc.tar.bz2 --exclude=etc/netwitness --exclude=etc/alternatives etc
}

backup_puppetssl(){
  echo ""
  echo "INFO: Backing up Puppet SSL Certs"
  tar -C / --atime-preserve --recursion -cphjf puppetssl.tar.bz2 var/lib/puppet/ssl
}

backup_mongodb(){
  echo ""
  echo "INFO: Backing up MongoDB"
  mongodump
}

backup_jetty(){
  echo ""
  echo "INFO: Backing up Jetty"
  JETTYSRV=$(status jettysrv | awk '{print $2}')
  if [ "$JETTYSRV" = "start/running," ]; then JETTYSRV="RESTART" && stop jettysrv; fi
  if [ ! -f ~/h2-1.3.172.jar ]; then
    wget http://repo1.maven.org/maven2/com/h2database/h2/1.3.172/h2-1.3.172.jar -O ~/h2-1.3.172.jar
  fi
  tar -C / --atime-preserve --recursion -cphjf jettyuax.tar.bz2 var/lib/netwitness/uax/nodeSecret.* var/lib/netwitness/uax/conf var/lib/netwitness/uax/lib var/lib/netwitness/uax/logs var/lib/netwitness/uax/plugins var/lib/netwitness/uax/scheduler var/lib/netwitness/uax/security-policy
  if [ "$JETTYSRV" = "RESTART" ]; then start jettysrv; fi
}

backup_reportingengine(){
  echo ""
  echo "INFO: Backing up Reporting Engine"
  REPORTINGENGINE=$(status rsasoc_re | awk '{print $2}')
  if [ "$REPORTINGENGINE" = "start/running," ]; then REPORTINGENGINE="RESTART" && stop rsasoc_re; fi
  tar -C / --atime-preserve --recursion -cphjf reportingengine.tar.bz2 --exclude='home/rsasoc/rsa/soc/reporting-engine/temp' home/rsasoc
  tar -C / --atime-preserve --recursion -cphjf reportingenginefiles.tar.bz2 --exclude='home/rsasoc/rsa/soc/reporting-engine/resultstore' --exclude='home/rsasoc/rsa/soc/reporting-engine/livecharts' --exclude='home/rsasoc/rsa/soc/reporting-engine/statusdb' --exclude='home/rsasoc/rsa/soc/reporting-engine/logs' --exclude='home/rsasoc/rsa/soc/reporting-engine/temp' --exclude='home/rsasoc/rsa/soc/reporting-engine/formattedReports' exclude='home/rsasoc/rsa/soc/reporting-engine/subreports' home/rsasoc/rsa/soc/reporting-engine
  if [ "$REPORTINGENGINE" = "RESTART" ]; then start rsasoc_re; fi
}

backup_coreappliance(){
  echo ""
  echo "INFO: Backing up Core Appliances"

  if [ -f /usr/sbin/NwConcentrator ]; then
    CONCENTRATOR=$(pidof NwConcentrator)
    if [ -n "$CONCENTRATOR" ]; then
      CONCENTRATOR="RESTART"
      stop nwconcentrator
    fi 
  fi

  if [ -f /usr/sbin/NwArchiver ]; then
    ARCHIVER=$(pidof NwArchiver)
    if [ -n "$ARCHIVER" ]; then
      ARCHIVER="RESTART"
      stop nwarchiver
    fi
  fi

  if [ -f /usr/sbin/NwDecoder ]; then
    DECODER=$(pidof NwDecoder)
    if [ -n "$DECODER" ]; then
      DECODER="RESTART"
      stop nwdecoder
    fi
  fi

  if [ -f /usr/sbin/NwBroker ]; then
    BROKER=$(pidof NwBroker)
    if [ -n "$BROKER" ]; then
      BROKER="RESTART"
      stop nwbroker
    fi
  fi

  if [ -f /usr/sbin/NwLogCollector ]; then
    LOGCOLLECTOR=$(pidof NwLogCollector)
    if [ -n "$LOGCOLLECTOR" ]; then
      LOGCOLLECTOR="RESTART"
      stop nwlogcollector
    fi
  fi

  if [ -f /usr/sbin/NwLogDecoder ]; then
    LOGDECODER=$(pidof NwLogDecoder)
    if [ -n "$LOGDECODER" ]; then
      LOGDECODER="RESTART"
      stop nwlogdecoder
    fi
  fi

  tar -C / --atime-preserve --recursion -cphjf coreappliance.tar.bz2 --exclude=Geo*.dat etc/netwitness/ng

  if [ "$CONCENTRATOR" = "RESTART" ]; then start nwconcentrator; fi
  if [ "$ARCHIVER" = "RESTART" ]; then start nwarchiver; fi
  if [ "$DECODER" = "RESTART" ]; then start nwdecoder; fi
  if [ "$BROKER" = "RESTART" ]; then start nwbroker; fi
  if [ "$LOGCOLLECTOR" = "RESTART" ]; then start nwlogcollector; fi
  if [ "$LOGDECODER" = "RESTART" ]; then start nwlogdecoder; fi
}

backup_esa(){
  echo ""
  echo "INFO: Backing up ESA"
  RSAESA=$(service rsa-esa status | awk '{print $7}')
  if [ "$RSAESA" = "running" ]; then
    RSAESA="RESTART"
    service rsa-esa stop
  fi
  tar -C / --atime-preserve --recursion -cphjf esa.tar.bz2 --exclude=opt/rsa/esa/logs --exclude=opt/rsa/esa/db --exclude=opt/rsa/esa/bin --exclude=opt/rsa/esa/lib opt/rsa/esa
  if [ "$RSAESA" = "RESTART" ]; then service rsa-esa start; fi
}

backup_logcollector(){
  echo ""
  echo "INFO: Backing up Log Collector"
  LOGCOLLECTOR=$(pidof NwLogCollector)
  if [ -n "$LOGCOLLECTOR" ]; then
    LOGCOLLECTOR="RESTART"
    stop nwlogcollector
  fi
  tar -C / --atime-preserve --recursion -cphjf logcollector.tar.bz2 var/netwitness/logcollector
  if [ "$LOGCOLLECTOR" = "RESTART" ]; then start nwlogcollector; fi
}

backup_malware(){
  echo ""
  echo "INFO: Backing up Malware"
  MALWARE=$(status rsaMalwareDevice | awk '{print $2}')
  if [ "$MALWARE" = "start/running," ]; then
    MALWARE="RESTART"
    stop rsaMalwareDevice
  fi
  tar -C / --atime-preserve --recursion -cphjf malware.tar.bz2 var/lib/netwitness/rsamalware --exclude='root.war' etc/init/rsaMalwareDevice.conf
  if [ "$MALWARE" = "RESTART" ]; then start rsaMalwareDevice; fi
}

backup_wconnector(){
  echo ""
  echo "INFO: Backing up Warehouse Connector"
  WCONNECTOR=$(status nwwarehouseconnector | awk '{print $2}')
  if [ "$WCONNECTOR" = "start/running," ]; then
    WCONNECTOR="RESTART"
    stop nwwarehouseconnector
  fi
  tar -C / --atime-preserve --recursion -cphjf lockbox.tar.bz2 etc/netwitness/ng/lockbox
  tar -C / --atime-preserve --recursion -cphjf wcfiles.tar.bz2 etc/netwitness/ng/NwWarehouseconnector.cfg etc/netwitness/ng/multivalue-bootstrap.xml etc/netwitness/ng/multivalue-users.xml
  tar -C / --atime-preserve --recursion -cphjf wconnector.tar.bz2 var/netwitness/warehouseconnector
  if [ "$WCONNECTOR" = "RESTART" ]; then start nwwarehouseconnector; fi
}

main(){
  do_checkroot
  do_recipe
  do_backup
  do_tarball
# do_offbox
  do_localcopy
  do_cleanup
}

clear
main
echo ""
exit 0
