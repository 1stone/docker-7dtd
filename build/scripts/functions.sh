#!/bin/bash

versionFile=$HOME/.versions
sfCfg=$SDTD_APP_DIR/serverconfig.xml
saveGameDir=${SDTD_CFG_SaveGameFolder:-$HOME/.local/share/7DaysToDie/Saves}
adminCfg=$saveGameDir/${SDTD_CFG_AdminFileName:-serveradmin.xml}

[ -f $versionFile ] || touch $versionFile
. $versionFile

#### FUNCTIONS ####

is_sdtd_install_required() {
  if [ "$v_sdtd" == "$VERSION_SDTD" \
    -a -d "$SDTD_APP_DIR" ]; then false
  else true
  fi
}

is_illy_install_required() {
  if [ "$v_illy" == "$VERSION_ILLY" \
    -o -z "$VERSION_ILLY" ]; then false
  else true
  fi
}

is_sdtd_instance_initialized() {
  if [ -f $adminCfg ]; then true
  else false
  fi
}

do_install_sdtd() {
  # cleanup
  #[ -d $SDTD_APP_DIR ] && rm -rf $SDTD_APP_DIR

  # install/update SDTD
  steamcmd \
    +force_install_dir $SDTD_APP_DIR \
    +login anonymous \
    +app_update 294420 $VERSION_SDTD validate \
    +quit \
  && (
    echo "v_sdtd=\"$VERSION_SDTD\"" >> $versionFile
    v_illy="reinstall"
  )
}

do_install_illy() {
  curl -# -SL http://illy.bz/fi/7dtd/server_fixes_$VERSION_ILLY.tar.gz | \
  		tar -xz -C $SDTD_APP_DIR && \
    echo "v_illy=\"$VERSION_ILLY\"" >> $versionFile
}


apply_sdtd_config() {

  # save original config
  [ -f ${sfCfg}.orig ] || cp ${sfCfg} ${sfCfg}.orig

  # remove any CRLF lineendings (to avoid sed trouble)
  sed -i -e 's/\r$//' $sfCfg

  # determine all commented properties, so we can uncomment them eventually
  commentedProps=( `sed -n 's/.*<!-- <property name="\([^"]*\)".*-->/\1/p' $sfCfg` )

  # determine all folder properties, so we can create them eventually
  folderProps=( `sed -n 's/.*<property name="\([^"]*Folder\)".*/\1/p' $sfCfg` )

  # process all SDTD_CFG_* variables
  upd=""
  for var in ${!SDTD_CFG_*}; do
    attr=${var##SDTD_CFG_}
    value=${!var}

    # do we need to uncomment property?
    [[ " ${commentedProps[@]} " =~ " $attr " ]] && \
      sed -i -e ":a;N;\$!ba; s|<\!-- \(<property name=\"$attr\"\s*value=\"[^\"]*\"\s*/>\) -->|\1|" $sfCfg

    # do we need to create a folder?
    [[ " ${folderProps[@]} " =~ " $attr " ]] && \
      [[ ! -d $value ]] && mkdir $value

    # append update instruction for xmlstarlet
    upd="$upd -u /ServerSettings/property[@name='$attr']/@value -v $value"
  done

  # finally patch serverconfig
  if [ -n "$upd" ]; then
    xmlstarlet ed --inplace -P $upd $sfCfg
  fi
}

apply_admin_config() {

  # process all SDTD_ADMIN_* variables
  for var in ${!SDTD_ADMIN_*}; do
    attr=${var##SDTD_ADMIN_}
    value=${!var}

    if [[ $attr =~ ^USER_ ]]; then
      id=${attr##USER_}
      readarray -d: -t rhs <<< "$value:"; unset rhs[-1]
      echo "applying user config: $id = $value"
      xmlstarlet edit --inplace \
           -d /adminTools/users/user[@userid=\'$id\'] \
           -s /adminTools/users -t elem -n newUser \
           -i //newUser -t attr -n platform -v Steam \
           -i //newUser -t attr -n userid -v $id \
           -i //newUser -t attr -n name -v "${rhs[0]}" \
           -i //newUser -t attr -n permission_level -v "${rhs[1]}" \
           -r //newUser -v user \
           $adminCfg
    fi

    if [[ $attr =~ ^GROUP_ ]]; then
      id=${attr##GROUP_}
      readarray -d: -t rhs <<< "$value:"; unset rhs[-1]
      echo "applying group config: $id = $value"
      xmlstarlet edit --inplace \
           -d /adminTools/users/group[@steamID=\'$id\'] \
           -s /adminTools/users -t elem -n newGroup \
           -i //newGroup -t attr -n steamID -v $id \
           -i //newGroup -t attr -n name -v "${rhs[0]}" \
           -i //newGroup -t attr -n permission_level_default -v "${rhs[1]}" \
           -i //newGroup -t attr -n permission_level_mod -v "${rhs[2]}" \
           -r //newGroup -v group \
           $adminCfg
    fi

    if [[ $attr =~ ^PERMISSION_ ]]; then
      cmd=${attr##PERMISSION_}
      echo "applying permission config: $cmd = $value"
      xmlstarlet edit --inplace \
           -d /adminTools/permissions/permission[@cmd=\'$cmd\'] \
           -s /adminTools/permissions -t elem -n newPerm \
           -i //newPerm -t attr -n cmd -v $cmd \
           -i //newPerm -t attr -n permission_level -v $value \
           -r //newPerm -v permission \
           $adminCfg
    fi

  done
}

apply_backup_config() {
  CRONFILE=/etc/cron.d/7dtd_backup

  if [ -n "$BACKUP_SCHEDULE" ]; then
    echo "Installing backup cron-job"
    cat <<EOF | crontab -
BACKUP_DIR=$BACKUP_DIR
BACKUP_COMPRESS=$BACKUP_COMPRESS
BACKUP_MAXNUMBER=$BACKUP_MAXNUMBER
SDTD_CFG_SaveGameFolder=$SDTD_CFG_SaveGameFolder

$BACKUP_SCHEDULE $scriptDir/backup.sh
EOF
  else
    [ -f $CRONFILE ] && rm $CRONFILE
  fi
}

do_send_cmd() {
  local cmd=$1

  # get telnet vars
  eval `xmlstarlet sel -T -t -m "/ServerSettings/property[starts-with(@name,'Telnet')]" -v "concat(@name,'=',@value)" -n $sfCfg`

  if [ "$TelnetEnabled" == "true" ]; then

    if [ -z "${TelnetPassword}" ]||[ "${TelnetPassword}" == "NOT SET" ]; then
      expect -c '
        proc abort {} {
          puts "Timeout or EOF\n"
          exit 1
        }
        spawn telnet localhost '${TelnetPort}'
        expect {
          "session."  { send "'$cmd'\r" }
          default     abort
        }
        send "exit\r"
        expect { eof }
      '
    else
      expect -c '
        proc abort {} {
          puts "Timeout or EOF\n"
          exit 1
        }
        spawn telnet localhost '${TelnetPort}'
        expect {
          "password:" { send "'${TelnetPassword}'\r" }
          default     abort
        }
        expect {
          "session."  { send "'$cmd'\r" }
          default     abort
        }
        send "exit\r"
        expect { eof }
      '
    fi
  fi
}

compress_dir() {
  local dir=$1
  local archive=$dir.tar.bz2
  tar -cj -C $dir -f $archive .
  touch -r $dir $archive

  echo "$archive"
}
