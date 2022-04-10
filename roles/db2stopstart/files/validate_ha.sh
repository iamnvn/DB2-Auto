#!/bin/bash
# Script Name: validate_ha.sh
# Description: This script will print hadr status for each instance.
# Arguments: DB2INST (Run as Instance)
# Date: Feb 14, 2022
# Written by: Naveen Chintada

SCRIPTNAME=validate_ha.sh
DB2INST=$1

## Calling comman functions and variables.
    . /tmp/include_db2

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

		echo -e "${DBNAME} ${DBROLE} ${DBHADRSTATE} ${DBHADRCONNSTATUS} ${DBSTDBYHOST} ${DBPRIMARYHOST} ${DBSTDBYHOST2} ${DBSTDBYHOST3}" > /tmp/HADR_roles_${DB2INST}.txt

        chmod 777 /tmp/HADR_roles_${DB2INST}.txt

	done < /tmp/${DB2INST}.db.lst
}

function validate_ha {
    DB2INST=$1
    HADRROLES=/tmp/HADR_roles_${DB2INST}.txt

    if [[ "$(grep -c ' ' ${HADRROLES})" == "$(grep -c 'STANDARD' ${HADRROLES})" ]]; then
      if [[ "$(grep -c 'STANDARD' ${HADRROLES})" -ne 0 ]]; then
        echo "STANDARD" > /tmp/db2-role.txt
        echo "NA" > /tmp/db2-hadrstate.txt
        echo "NA" > /tmp/db2-primary.txt
        echo "NA" > /tmp/db2-standby.txt
        log "${DB2INST} - ${HNAME} - This Server role is $(cat /tmp/db2-role.txt)"
      fi
    else
        log "HADR Server node - ${HNAME}"
        if [[ "$(grep -c ' ' ${HADRROLES})" == "$(grep -c 'CONNECTED' ${HADRROLES})" ]]; then
            log "All databases are CONNECTED"
        else
            log "ERROR: One or more dbs are not HADR CONNECTED State, Please check!"
            exit 11
        fi
        cat ${HADRROLES} | awk '{print $1}' > /tmp/db2-databases.txt
        cat ${HADRROLES} | grep 'PRIMARY' | awk '{print $1}' > /tmp/db2-databases-primary.txt
        cat ${HADRROLES} | grep 'STANDBY' | awk '{print $1}' > /tmp/db2-databases-standby.txt

        if [[ "$(cat /tmp/db2-databases-standby.txt)" == "$(cat /tmp/db2-databases.txt)" ]]; then
            echo "STANDBY" > /tmp/db2-role.txt
            cat ${HADRROLES} | awk '{print $5}' | awk -F. '{print $1}' | head -1 > /tmp/db2-standby.txt
            cat ${HADRROLES} | awk '{print $6}' | awk -F. '{print $1}' | head -1 > /tmp/db2-primary.txt
            cat ${HADRROLES} | awk '{print $3}' | awk -F. '{print $1}' | head -1 > /tmp/db2-hadrstate.txt
            log "${DB2INST} - ${HNAME} - Primary Server is $(cat /tmp/db2-primary.txt) and HADR state is $(cat /tmp/db2-role.txt)"            
        elif [[ "$(cat /tmp/db2-databases-primary.txt)" == "$(cat /tmp/db2-databases.txt)" ]]; then
            echo "PRIMARY" > /tmp/db2-role.txt
            cat ${HADRROLES} | awk '{print $5}' | awk -F. '{print $1}' | head -1 > /tmp/db2-standby.txt
            cat ${HADRROLES} | awk '{print $3}' | awk -F. '{print $1}' | head -1 > /tmp/db2-hadrstate.txt
            cat ${HADRROLES} | awk '{print $6}' | awk -F. '{print $1}' | head -1 > /tmp/db2-primary.txt
            log "${DB2INST} - ${HNAME} - P.Standby Server is $(cat /tmp/db2-standby.txt) and and HADR state is $(cat /tmp/db2-role.txt)"
        else
            log "ERROR: Looks like HADR roles(primary/standby) not same for all dbs on ${DB2INST} - ${HNAME}, Please check!"
            cat ${HADRROLES} >> ${LOGFILE}
            exit 12
        fi
        log "${DB2INST} - ${HNAME} Role is $(cat /tmp/db2-role.txt) and HADR state is $(cat /tmp/db2-hadrstate.txt)"
        rm -f /tmp/db2-databases-primary.txt /tmp/db2-databases.txt /tmp/db2-databases-standby.txt
    fi
  chmod -f 744 *.txt
  cat /tmp/db2-role.txt > /tmp/db2-role_${DB2INST}.txt
  cat /tmp/db2-hadrstate.txt > /tmp/db2-hadrstate_${DB2INST}.txt
  cat /tmp/db2-primary.txt | head -1 > /tmp/db2-primary_${DB2INST}.txt 
  cat /tmp/db2-standby.txt | head -1 > /tmp/db2-standby_${DB2INST}.txt

  rm -f /tmp/db2-hadrstate.txt /tmp/db2-standby.txt /tmp/db2-primary.txt /tmp/db2-role.txt /tmp/HADR_roles_${DB2INST}.txt
}

#while read DB2INST
#do
    hadr_roles ${DB2INST}
    validate_ha ${DB2INST}
#done < /tmp/db2ilist.lst