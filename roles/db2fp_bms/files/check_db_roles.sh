#!/bin/bash
# Script Name: check_db_roles.sh
# Description: This script will print hadr status for each instance.
# Arguments: DB2INST (Run as Instance)
# Written by: Jay Thangavelu

SCRIPTNAME=check_db_roles.sh
DB2INST=$1

## Calling comman functions and variables.
    . /tmp/include_db2

if [[ -z ${DB2INST} ]]; then
    DB2INST=$(whoami)
fi

LOGFILE=${LOGDIR}/${DB2INST}_${SCRIPTNAME}.log
log_roll ${LOGFILE}
function hadr_roles {
    DB2INST=$1

    ## Get Instance home directory
    get_inst_home

    ## Source db2profile
    if [[ -f ${INSTHOME}/sqllib/db2profile ]]; then
        . ${INSTHOME}/sqllib/db2profile
    fi

    ##List out databases in DB2 Instance
    list_dbs

	while read DBNAME
    do
		db_hadr
		if [[ -z "${DBROLE}" ]]; then
			DBROLE=STANDARD
			DBHADRSTATE=NA
			DBHADRCONNSTATUS=NA
			DBSTDBYHOST=NA
			DBPRIMARYHOST=NA
		fi

		if [[ -z "${DBSTDBYHOST2}" ]]; then
			DBSTDBYHOST2=NOAX1
		fi

		if [[ -z "${DBSTDBYHOST3}" ]]; then
			DBSTDBYHOST3=NOAX2
		fi

		echo -e "${DBNAME} ${DBROLE} ${DBHADRSTATE} ${DBHADRCONNSTATUS} ${DBSTDBYHOST} ${DBPRIMARYHOST} ${DBSTDBYHOST2} ${DBSTDBYHOST3}"

	done < /tmp/${DB2INST}.db.lst
}

function validate_ha {
    DB2INST=$1
    HADRROLES=/tmp/HADR_roles.txt

    if [[ "$(grep -c ' ' ${HADRROLES})" == "$(grep -c 'STANDARD' ${HADRROLES})" ]]; then
      if [[ "$(grep -c 'STANDARD' ${HADRROLES})" -ne 0 ]]; then
        echo "STANDARD" > /tmp/db2-role_${DB2INST}.txt
        echo "NA" > /tmp/db2-standby_${DB2INST}.txt
        log "${DB2INST} - ${HNAME} - This Server role is $(cat /tmp/db2-role_${DB2INST}.txt)"
      fi
    else
        log "HADR Server node - ${HNAME}"
        if [[ "$(grep -c ' ' ${HADRROLES})" == "$(grep -c 'CONNECTED' ${HADRROLES})" ]]; then
            log "All databases are CONNECTED"
        else
            log "ERROR: One or more dbs are not HADR CONNECTED State, Please check!"
            exit 11
        fi

        if [[ $(cat ${HADRROLES} | grep 'PRIMARY' | wc -l) -gt 0 ]]; then
            echo "PRIMARY" > /tmp/db2-role_${DB2INST}.txt
            cat ${HADRROLES} | grep 'PRIMARY' | awk '{print $5}' | awk -F. '{print $1}' | head -1 > /tmp/db2-standby_${DB2INST}.txt
            log "${DB2INST} - ${HNAME} - One or more Databases are Primary on this node attempt takeover on $(cat /tmp/db2-standby_${DB2INST}.txt)"
        else
            echo "STANDBY" > /tmp/db2-role_${DB2INST}.txt
            cat ${HADRROLES} | grep 'STANDBY' | awk '{print $6}' | awk -F. '{print $1}' | head -1 > /tmp/db2-standby_${DB2INST}.txt
            log "${DB2INST} - ${HNAME} - All Databases are Standby."
        fi
    fi
  chmod -f 744 *.txt
  echo "$(cat /tmp/db2-role_${DB2INST}.txt) $(cat /tmp/db2-standby_${DB2INST}.txt)" >> /tmp/db2-role.txt
  chmod -f 777 /tmp/db2-role.txt
  
  rm -f /tmp/db2-role_${DB2INST}.txt /tmp/db2-standby_${DB2INST}.txt /tmp/HADR_roles.txt
}

#while read DB2INST
#do
    hadr_roles ${DB2INST} >> /tmp/HADR_roles.txt
    chmod -f 777 /tmp/HADR_roles.txt
    validate_ha ${DB2INST}
#done < /tmp/db2ilist.lst