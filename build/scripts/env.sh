#!/bin/sh

versionFile=$HOME/.versions

sfDir=$HOME/serverfiles
sfCfg=$sfDir/serverconfig.xml

saveGameDir=${SDTD_CFG_SaveGameFolder:-$HOME/.local/share/7DaysToDie/Saves}
adminCfg=$saveGameDir/${SDTD_CFG_AdminFileName:-serveradmin.xml}
