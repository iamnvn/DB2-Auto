#!/bin/bash
# Script Name: patchdb2.sh
# Description: This script will install db2 and update db2 instance on server on same installation path of before patch.
# Arguments: NA (Run as root/sudo)
# Date: Apr 13, 2022
# Written by: Naveen Chintada

SCRIPTNAME=patchdb2.sh

## Calling comman functions and variables.
    . /tmp/include_db2

INSTALLSTATE=NOTCOMPLETE
log_roll ${LOGFILE}

log "START - ${SCRIPTNAME} execution started at $(date)"

function patchdb2 {

    DB2VPATH=$(db2level  | grep 'installed'  | awk '{print $5'} | sed "s/..$//g" | sed "s/^.//g" | head -1)

    if [[ ! -d "${PATCHDIR}" ]]; then
		    log "ERROR: Patching directory - ${PATCHDIR} doesn't exist. Exiting !"
        exit 1
    fi

    if [[ "${INSTALLSTATE}" == "NOTCOMPLETE" ]]; then
      log "Patching directory is - ${PATCHDIR}"
      log "Installing db2 on - ${DB2VPATH}"

      log "Running - ${PATCHDIR}/${SWTYPE}/installFixPack -b ${DB2VPATH} -n -y -l ${LOGDIR}/${PVERSION}_installfp.log"
      ${PATCHDIR}/${SWTYPE}/installFixPack -b ${DB2VPATH} -n -y -l ${LOGDIR}/${PVERSION}_installfp.log > ${LOGDIR}/${PVERSION}_installfp_STDERR.log 2>&1
      RCD=$?
      log "Return Code: ${RCD}"
      chmod -f 777 "${LOGDIR}/${PVERSION}_install_*.log"

      if [[ ${RCD} -eq 0 ]]; then
        log "Fixpack Installation Completed Successfully."
        INSTALLSTATE=COMPLETE
        log "Removing - ${PATCHDIR}/${SWTYPE} directory"
        rm -rf ${PATCHDIR}/${SWTYPE}
      #elif [[ ${RCD} -eq 67 ]]; then
      #  log "WARNING: Seems like we are trying to install same Fixpack level as before. Please check!"
      #  INSTALLSTATE=COMPLETE
      else
        log "ERROR: Fixpack Installation failed.! Please check log files: ${LOGDIR}/${PVERSION}_installfp.log"
        exit ${RCD};
      fi
    fi

## Running db2 instance update for each instance
  log "Running the db2iupdt for ${DB2INST}"
	#Running db2stop if instance gets started by any chance
  db2stop force >> ${LOGFILE}
  ${INSTHOME}/sqllib/bin/ipclean -a

  log "Running db2iupdate for ${DB2INST}"
  log "Running - ${DB2VPATH}/instance/db2iupdt ${DB2INST} > ${LOGDIR}/${PVERSION}_${DB2INST}_db2iupdate.log"
    if [[ "${HVERSION}" == "Linux" ]]; then
      export LD_LIBRARY_PATH=
    elif [[ "${HVERSION}" == "AIX" ]]; then
      export LIBPATH=
      mv ${INSTHOME}/.profile ${INSTHOME}/.profile_bkp
    fi
    ${DB2VPATH}/instance/db2iupdt ${DB2INST} > ${LOGDIR}/${PVERSION}_${DB2INST}_db2iupdate.log 2>&1
    RCD=$?
    mv ${INSTHOME}/.profile_bkp ${INSTHOME}/.profile
    log "db2iupdt Completed on ${DB2INST} with RC: ${RCD}"
    chmod 777 ${LOGDIR}/${PVERSION}_${DB2INST}_db2iupdate.log

    if [[ "${RCD}" -eq 0 ]]; then
      log "Instance: ${DB2INST} updated successfully"
    else
      RC=${RCD}
      log "ERROR: Failed to update Instance: ${DB2INST} , Check log: ${LOGDIR}/${PVERSION}_${DB2INST}_db2iupdate.log"
    fi
}

while read DB2INST
do
  ## Get Instance home directory
  get_inst_home
  #Source db2profile
      if [ -f ${INSTHOME}/sqllib/db2profile ]; then
          . ${INSTHOME}/sqllib/db2profile
      fi
  patchdb2
done < /tmp/${HNAME}.inst.lst

log "END - ${SCRIPTNAME} execution ended at $(date)"