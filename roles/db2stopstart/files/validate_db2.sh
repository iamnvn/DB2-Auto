#!/bin/bash
# Script Name: validate.sh
# Description: This script will force all applications and stops db2 instance.
# Arguments: DB2INST (Run as Instance)
# Date: Feb 15, 2022
# Written by: Naveen Chintada

SCRIPTNAME=validate.sh

## Call commanly used functions and variables
    . /tmp/include_db2

DB2INST=$1

## Get Instance home directory
    get_inst_home

#Source db2profile
    if [[ -f ${INSTHOME}/sqllib/db2profile ]]; then
        . ${INSTHOME}/sqllib/db2profile
    fi

echo "Instance Status-"
db2pd -

echo ""
echo "Databases Status"
db2pd - -alldbs