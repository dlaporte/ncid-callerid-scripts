#!/bin/sh

# ncid_wrapper.sh
# v1.4

# David LaPorte
# 01/11/12

# v1.4 - Growl 1.3 support and multiple additional fixes (Steve Major)
# v1.3 - added outbound call support
# v1.2 - better installation text, removed .profile example
# v1.1 - corrected .profile example

# Hack to cobble together:
#   NCID     http://ncid.sourceforge.net
#   Contacts http://gnufoo.org/contacts
#   Growl    http://growl.info
#
# This script should be moved to $HOME/bin along with growl_wrapper.sh
#
# If you want to always have it launch at user login, move the ncid_wrapper.plist
# file to $HOME/Library/LaunchAgents.
#
# To start everything up, be sure growl is running as well as ncidd (locally or on a
# remote server - set host and port below).  Run this script, which will launch "ncid"
# with the correct arguments to run the growl wrapper everytime an inbound call is received.
#

# Location of the "ncid" utility.  This location assumes you installed via macports
NCID=/opt/local/bin/ncid

# Remote NCID server
HOST=192.168.12.162

# Remote NCID port
PORT=3333

# Location of the growl wrapper
GROWL_WRAPPER=$HOME/bin/growl_wrapper.sh

$NCID --no-gui --program $GROWL_WRAPPER $HOST $PORT
