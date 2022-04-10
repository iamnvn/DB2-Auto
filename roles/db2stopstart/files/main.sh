#!/bin/bash
# Script Name: runasdb2.sh
# Description: This script will run script as instance user from root user.
# Arguments: Script to run
# Date: Feb 15, 2022
# Written by: Naveen Chintada

SCRIPTNAME=runasdb2.sh

## Call commanly used functions and variables
. /tmp/include_db2

log_roll ${LOGFILE}
log_roll ${MAINLOG}

SCRIPTTORUN=$1

##Get the list of available Db2 LUW instances, List only once for whole fixlet
    if [[ ! -f /tmp/${HNAME}.inst.lst ]]; then
      $(/usr/local/bin/db2ls | tail  -1 |awk '{print $1"/instance/db2ilist"}') > /tmp/db2ilist.lst
      chmod -f 666 /tmp/${HNAME}.inst.lst
    fi

#Run the script passed in $1 for every available instance in a while loop
while read DBINST
do
  #log "Running ${SCRIPTTORUN} script as ${DBINST} id"
  su ${DBINST} -c "${SCRIPTSDIR}/${SCRIPTTORUN} ${DBINST}"
  ##${SCRIPTSDIR}/${SCRIPTTORUN}" ${DBINST}
	##"${SCRIPTTORUN}" ${DBINST}
  RCD=$?

  if [ ${RCD} -ne 0 ]; then
    log "${SCRIPTTORUN} did not run using ${DBINST}, Please check !!"
    exit ${RC}
  fi
done < /tmp/db2ilist.lst

if [[ -f /tmp/${HNAME}.inst.lst ]]; then
	rm -rf /tmp/${HNAME}.inst.lst
fi
if [[ -f ${MAINLOG} ]]; then chmod -f 777 ${MAINLOG}; fi
