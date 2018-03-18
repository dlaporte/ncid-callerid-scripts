#!/bin/sh

# growl_wrapper.sh
# v1.8

# David LaPorte
# 01/11/12

# 1.8   - dropped the deprecated "--all-calls" option
# 1.7   - added outbound call support, added Growl sticky notifications option, time notification,
#         fix for growl notify with new line (related to "echo" fix in 1.5).
# 1.6   - misc updates to get regexes working again
# 1.5   - added whocalled.us support, issue with "echo" and Leopard
# 1.4.4 - multiple line support
# 1.4.3 - added hack to ignore mangled callerID strings from Vonage
# 1.4.2 - fixed cidlog bug, added better installation text
# 1.4.1 - now uses the "--all" option to ncid, fixed "Unknown" issue
# 1.4   - display "class" of incoming number
# v1.3  - misc cleanup, CID logging, fixed issue with whitespace in CID name
# v1.2  - wasn't using name from CID if Address Book entry didn't exist
# v1.1  - Address Book image lookup

# Hack to cobble together:
#   NCID     http://ncid.sourceforge.net
#   Contacts http://gnufoo.org/contacts
#   Growl    http://growl.info

# Note that NCID provides an OSX client with pop-up functionality (NCIDpop), although
# it lacks name lookup capability.
#
# This script should be moved to $HOME/bin along with ncid_wrapper.sh
#
# If you want to always have it launch at user login, edit the file to include the correct
# home directory (there are two instances in the file!) and move the ncid_wrapper.plist
# file to $HOME/Library/LaunchAgents.
#
# We use the "ncid" utility to call this wrapper script.  The phone number is
# stripped out, normalized, and then we search the Address Book via the "contacts"
# utility (if installed) for a name.  The name/number is then output via a Growl
# notification pop-up.

# If you'd like to enable integration with whocalled.us for telemarketer detection, visit
# http://whocalled.us/join and create an account.  Set WHOCALLED_USER and WHOCALLED_PASS
# values below appropriately and you're good to go!
WHOCALLED_USER=""
WHOCALLED_PASS=""

# Location of growlnotify - download from http://growl.info/extras.php#growlnotify
GROWLNOTIFY=/usr/local/bin/growlnotify

# Location of contacts binary - install via macports
CONTACTS=/opt/local/bin/contacts

# Location of wget binary (necessary only if using whocalled.us) - install via macports
WGET=/opt/local/bin/wget

# Where to log CID info
CIDLOG="$HOME/cidlog"

# Make your Growl notifications sticky (you have to click them to dismiss). Comment these lines
# out if you do not want them to stick.

# Make Growl sticky known callers - those found with the optional Contacts Address Book lookup.
STICKYKNOWN="-s "
# Make Growl sticky caller ID information for all calls not in Contacts Address Book lookup.
STICKYUNKNOWN="-s "

# Default icon to display if an Address Book image does not exist
# I like the mobile phone icon from http://http://findicons.com/icon/44779/mobile_telephone
# Change any of the type icons below to customize what is displayed when a particular "class"
# of number is incoming.

ICON="$HOME/Documents/Icons/mobile-telephone.png"

HOME_ICON=$ICON
MOBILE_ICON=$ICON
WORK_ICON=$ICON
MAIN_ICON=$ICON
FAX_ICON=$ICON
OTHER_ICON=$ICON
PAGER_ICON=$ICON

# read in raw CID and break it up
read DATE
read TIME
read NUMBER
read NAME
read LINE
read DIRECTION

echo $DIRECTION >> ~dlaporte/direction

# Formatted time strings for notifications
#NEWTIME=`date +%l:%M%p | tr "[:upper:]" "[:lower:]"`
#NEWDATE=`date +%A", "%B" "%e" "`
NEWTIME=`date +"%H:%M"`
NEWDATE=`date +"%d %B %Y"`

# This Toggles Outbound vs Inbound strings if your device supports reporting outbound calls. You
# will also need to edit the file ncid_wrapper.sh to enable the -C option to report outbound
# calls (see the file for more information.)

INOUT="Incoming"
FROMTO="from"

if [ "$DIRECTION" = "OUT" ]; then
  INOUT="Outgoing"
  FROMTO="to"
fi

# Title text to display in Growl notification window
# If a CIDLINE is sent by ncid, then we'll display it.
# If you're using a VoIP line (eg. Vonage), a line is
# always sent.  If you don't need to see the line, add
# an alias to ncidd.alias similar to:
#
# alias <4-digit line> = -
#
if [ -z "$LINE" -o "$LINE" = "-" ]
then
  TEXT="$INOUT call $FROMTO..."
else
  TEXT="$INOUT call on $LINE $FROMTO..."
fi

# Change case of unknown and private numbers
if [ "$NAME" = "OUT-OF-AREA" ] || [ "$NAME" = "NO NAME" ] || [ -z "$NAME" ] || [ -n "$MANGLED_NAME" ]; then
  NAME="Unknown"
elif [ "$NAME" = "PRIVATE" ]; then
  NAME="Private"
fi

if [ "$NUMBER" = "OUT-OF-AREA" ] || [ -z "$NUMBER" ]; then
  NUMBER="Unknown"
elif [ "$NUMBER" = "PRIVATE" ]; then
  NUMBER="Private"
fi

if [ -e "$CONTACTS" ] && [ -x "$CONTACTS" ]; then
  # pass each contacts line through a regex to normalize all sorts of messed up phone formats
  # check each class of number individually so we can determine the icon and text to display
  for NUMBER_TYPE in HOME MOBILE WORK MAIN FAX OTHER PAGER
  do
    case $NUMBER_TYPE in
      "HOME" )
        FORMAT="hp" ;;
      "MOBILE" )
        FORMAT="mp" ;;
      "WORK" )
        FORMAT="wp" ;;
      "MAIN" )
        FORMAT="Mp" ;;
      "FAX" )
        FORMAT="fp" ;;
      "OTHER" )
        FORMAT="op" ;;
      "PAGER" )
        FORMAT="pp" ;;
    esac

    PERSON=`$CONTACTS -S -H -f "%u|%fn %ln|%${FORMAT}" | perl -pe 's/\s*\({0,1}\s*(\d{3})\s*[\)-.]{0,1}\s*(\d{3})\s*[\-\.]{0,1}\s*(\d{4})/$1$2$3|$1-$2-$3/g' | grep "$NUMBER" | head -1`

    if [ -n "$PERSON" ]; then
      PID=`echo "$PERSON" | cut -d"|" -f1 | cut -d ":" -f1`
      NAME=`echo "$PERSON" | cut -d "|" -f2 | tr "\n" " " && echo "($NUMBER_TYPE)" | tr [:upper:] [:lower:]`
      NUMBER=`echo "$PERSON" | cut -d"|" -f4`
      ICON=`eval echo \\$${NUMBER_TYPE}_ICON`
      break
    fi
  done
fi

if [ -z "$PERSON" ] && [ -n "$WHOCALLED_USER" ] && [ -n "$WHOCALLED_PASS" ]
then
  WHOCALLED_NUMBER=`echo $NUMBER | sed -e "s/[^0-9]//g"`
  WHOCALLED_URL="http://whocalled.us/do?action=getScore&name=$WHOCALLED_USER&pass=$WHOCALLED_PASS&phoneNumber=$WHOCALLED_NUMBER"
  WHOCALLED_RESULT=`$WGET --output-document=- $WHOCALLED_URL`
  WHOCALLED_SUCCESS=`echo $WHOCALLED_RESULT | cut -f1 -d\& | cut -f2 -d\=`
  if [ -z "$WHOCALLED_SUCCESS" ]; then
    WHOCALLED_SUCCESS=0
  fi
  if [ $WHOCALLED_SUCCESS -eq 1 ]
  then
    WHOCALLED_SCORE=`echo $WHOCALLED_RESULT | cut -f2 -d\& | cut -f2 -d\=`
    if [ -z "$WHOCALLED_SCORE" ]; then
      WHOCALLED_SCORE=0
    fi
    if [ $WHOCALLED_SCORE -gt 2 ] 
    then
      NAME="Telemarketer"
      WHOCALLED_URL="http://whocalled.us/do?action=getWho&name=$WHOCALLED_USER&pass=$WHOCALLED_PASS&phoneNumber=$WHOCALLED_NUMBER"
      WHOCALLED_RESULT=`$WGET --output-document=- $WHOCALLED_URL`
      WHOCALLED_SUCCESS=`echo $WHOCALLED_RESULT | cut -f1 -d\& | cut -f2 -d\=`
      WHOCALLED_NAME=`echo $WHOCALLED_RESULT | cut -f2 -d\& | cut -f2 -d\=`
      if [ $WHOCALLED_NAME != "unknown" ] && [ $WHOCALLED_NAME != "UNKNOWN" ] && [ $WHOCALLED_NAME != "Unknown" ]
      then
        NAME="$NAME: $WHOCALLED_NAME"
      fi
    fi
  fi
fi

echo "$DATE|$TIME|$NUMBER|$NAME" >> $CIDLOG

#if [ -e "$HOME/Library/Application Support/AddressBook/Images" ]; then
#  IMAGE_PATH="$HOME/Library/Application Support/AddressBook/Images"
#else
#  IMAGE_PATH="$HOME/Library/Application Support/AddressBook/Sources/*/Images"
#fi

IMAGE=`find $HOME/Library/Application\ Support/AddressBook -name $PID | head -1`
if [ -n "$PERSON" ] && [ -n "$IMAGE" ]; then
  #IMAGE="$HOME/Library/Application Support/AddressBook/Images/$PID"
  echo "$NAME"$'\n'"$NUMBER"$'\n'"$NEWDATE $NEWTIME" | $GROWLNOTIFY -n "CallerID" $STICKYKNOWN --image "$IMAGE" -t "$TEXT"
else
  echo "$NAME"$'\n'"$NUMBER"$'\n'"$NEWDATE $NEWTIME" | $GROWLNOTIFY -n "CallerID" $STICKYUNKNOWN --image "$ICON" -t "$TEXT"
fi
