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
#   Content: A simple script for removing McAfee software from company laptops
#
#################################################################################

if [ "$(id -u)" != "0" ]; then
  clear
  echo "ERROR: This script must be run as root!"
  echo ""
  exit 1
fi

rm -f /Library/LaunchAgents/com.mcafee.menulet.plist
rm -f /Library/LaunchAgents/com.mcafee.reporter.plist
rm -f /Library/LaunchDaemons/com.mcafee.ssm.Eupdate.plist
rm -f /Library/LaunchDaemons/com.mcafee.ssm.ScanFactory.plist
rm -f /Library/LaunchDaemons/com.mcafee.ssm.ScanManager.plist
rm -f /Library/LaunchDaemons/com.mcafee.virusscan.fmpd.plist
rm -rf /Library/Documentation/Help/McAfeeSecurity_*
rm -rf /Library/Application\ Support/McAfee
rm -rf /Library/McAfee
rm -rf /usr/local/McAfee
rm -rf /Quarantine
rm -rf /Applications/McAfee\ Endpoint\ Protection\ for\ Mac.app
