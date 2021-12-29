#!/bin/bash

startupDir=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
source $startupDir/env.sh
source $startupDir/functions.sh

backupDir=${BACKUP_DIR:-$HOME/backups}

newBackup=$backupDir/`date "+%Y-%m-%d_%H-%M"`

# tell server to save world
do_send_cmd "saveworld"

if [ -d $backupDir ]; then
  #  prime new backup by hard-linking latest backup
  unset -v latestBackup
  for backup in $(find "$backupDir" -mindepth 1 -maxdepth 1 -type d); do
    if [ "$backup" -nt "$latestBackup" ]; then
      latestBackup=$backup
    fi
  done
  if [ -n "$latestBackup" ]; then
    cp -al "$latestBackup" "$newBackup"
  fi
else
  mkdir $backupDir
fi

rsync -a --delete --numeric-ids --delete-excluded $saveGameDir $newBackup
touch $newBackup

## Compress if enabled
case ${BACKUP_COMPRESS:-none} in
  all)
    dfname=$(basename $newBackup)
    (
      cd $backupDir
      tar -cjf $dfname.tar.bz2 $dfname
      touch -r $dfname $dfname.tar.bz2
      rm -Rf $dfname
    )
    ;;
  old)
    if [ -d $latestBackup ]; then
      dfname=$(basename $latestBackup)
      (
        cd $backupDir
        tar -czf $dfname.tar.gz $dfname
        touch -r $dfname $dfname.tar.gz
        rm -Rf $dfname
      )
    fi
    ;;
  none)
    ;;
esac

## Purge old/too many backups
if [ -n "$BACKUP_MAXNUMBER" ]; then
  declare -i maxBackups=$BACKUP_MAXNUMBER
  num=0
  for f in $(ls -t1 $backupDir); do
    (( num++ ))
    [ $num -gt $maxBackups ] && rm -Rf $backupDir/$f
  done
fi
