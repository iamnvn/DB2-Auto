#!/bin/bash
# Script Name: hadr_roles.sh
# Description: This script will print hadr status for each instance.
# Arguments: DB2INST (Run as Instance)
# Date: Feb 14, 2022
# Written by: Naveen Chintada

SCRIPTNAME=hadr_roles.sh

## Calling comman functions and variables.
    . /tmp/include_db2

DB2INST=$1
LOGFILE=${LOGDIR}/${DB2INST}_${SCRIPTNAME}.log

## Get Instance home directory
    get_inst_home

#Source db2profile
    if [[ -f ${INSTHOME}/sqllib/db2profile ]]; then
        . ${INSTHOME}/sqllib/db2profile
    fi

#List out databases in DB2 Instance
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

		echo -e "${DBNAME} ${DBROLE} ${DBHADRSTATE} ${DBHADRCONNSTATUS} ${DBSTDBYHOST} ${DBPRIMARYHOST} ${DBSTDBYHOST2} ${DBSTDBYHOST3}" > /tmp/HADR_roles_${DB2INST}.lst
	done < /tmp/${DB2INST}.db.lst

  #echo "DBNAME = $(cat ${SCRIPTSDIR}/HADRroles_db2.txt | awk '{print $1}' | tail -1)"
  #echo "DBROLE = ${DBROLE}"
  #echo "DBHADRSTATE = ${DBHADRSTATE}"
  #echo "DBHADRCONNSTATUS = ${DBHADRCONNSTATUS}"
  #echo "DBSTDBYHOST = ${DBSTDBYHOST}"
  #echo "DBPRIMARYHOST = ${DBPRIMARYHOST}"
  #echo "DBSTDBYHOST2 = ${DBSTDBYHOST2}"
  #echo "DBSTDBYHOST3 = ${DBSTDBYHOST3}"