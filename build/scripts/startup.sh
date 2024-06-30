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



echo "
=======================================================================
USER INFO:

$(/bin/id)

=======================================================================
"

# Prepare home and permissions
echo "Preparing $HOME"
sudo chown -R sdtd:sdtd "$HOME"
[ -d $HOME/.steam ] || mkdir $HOME/.steam

# Load functions
scriptDir=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
source $scriptDir/functions.sh

# Install SDTD
if is_sdtd_install_required; then 
  echo "Installing new 7DTD version..."
  do_install_sdtd
fi

# Apply config
echo "Applying 7DTD configs..."
apply_sdtd_config

if is_sdtd_instance_initialized; then
  echo "Applying Admin configs..."
  apply_admin_config
else
  echo "WARNING: Admin-Config not applicable yet. Please restart server after first run!"
fi

# Install Alloc's Mod
if is_illy_install_required; then 
  echo "Installing AllocMod extensions"
  do_install_illy
fi

# Apply backup config
echo "Applying Backup config..."
apply_backup_config

# Start cron
echo "Starting cron..."
sudo /etc/init.d/cron start

# Run the server
echo "Starting server..."
cd $SDTD_APP_DIR
export LD_LIBRARY_PATH=.
./7DaysToDieServer.x86_64 ${SDTD_STARTUP_ARGUMENTS} -configfile=${sfCfg} &

child=$!
wait "$child"
