#!/bin/sh

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
#   Content: A simple script for removing Casper software from company laptops
#
#################################################################################

# Remove MCX prefs from a profile/machine
dscl . -list Computers | grep -v "^localhost$" | while read computer_name ; do sudo dscl . -delete Computers/"$computer_name" ; done
user=`ls -la /dev/console | cut -d " " -f 4`
dscl . -delete /Users/$user MCXSettings
dscl . -delete /Users/$user MCXFlags
dscl . -delete /Users/$user cached_groups
dscl . -delete /Users/$user dsAttrTypeStandard:MCXSettings
rm -rf /private/var/db/dslocal/nodes/Default/computers/localhost.plist

# Remove Jamf Framework
/usr/sbin/jamf removeFramework

# Remove Self Service app
rm -rf "/Applications/Self\ Service.app"
rm /Users/$user/Library/Preferences/com.jamfsoftware.*
