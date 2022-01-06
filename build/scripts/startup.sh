#!/bin/bash

set -e

[[ -n "$DEBUG" ]] && set -x

exit_handler()
{
    echo "Shutdown signal received.."

    # Execute the telnet shutdown commands
    do_send_cmd "shutdown"

    sleep 5

    echo "Exiting.."
    exit
}

# Trap specific signals and forward to the exit handler
trap 'exit_handler' SIGINT SIGTERM


cd $HOME

scriptDir=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")

source $scriptDir/env.sh
source $scriptDir/functions.sh

######################
#### Server Setup ####
######################

if is_sdtd_install_required; then do_install_sdtd; fi
apply_sdtd_config

if is_sdtd_instance_initialized; then
  apply_admin_config
else
  echo "WARNING: Admin-Config not applicable yet. Please restart server after first run!"
fi

if is_illy_install_required; then do_install_illy; fi

# apply backup config
apply_backup_config

# Run the server
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${sfDir}/7DaysToDieServer_Data/Plugins/x86_64
$sfDir/7DaysToDieServer.x86_64 ${SDTD_STARTUP_ARGUMENTS} -configfile=${sfCfg} &

child=$!
wait "$child"
