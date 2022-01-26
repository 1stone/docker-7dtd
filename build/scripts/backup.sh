#!/bin/bash

startupDir=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
source $startupDir/env.sh
source $startupDir/functions.sh

backupDir=${BACKUP_DIR:-$HOME/backups}
archiveDir=${ARCHIVE_DIR:-$HOME/archives}

newBackup=$backupDir/`date "+%Y-%m-%d_%H-%M"`

if [ "$1" == "-a" ]; then
  archiveName=$2
  archiveFile=${archiveDir}/${archiveName}.tar.bz2
  if [ -z "$archiveName" ]; then
    echo "Error: missing archive name!"
    exit 1
  elif [ -f "$archiveFile" ]; then
    echo "Error: archive file already exists: " + $archiveFile
    exit 2
  fi
fi

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
    newBackupArchive=$(compress_dir $newBackup && rm -Rf $newBackup)
    ;;
  old)
    if [ -d $latestBackup ]; then
      compress_dir $latestBackup && rm -Rf $latestBackup
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

## Archive backup if requested
if [ -n "$archiveFile" ]; then
  if [ -n "$newBackupArchive" ]; then
    ln $newBackupArchive $archiveFile
  else
    newBackupArchive=$(compress_dir $newBackup)
    mv $newBackupArchive $archiveFile
  fi
fi
