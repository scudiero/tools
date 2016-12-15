#!/bin/bash
version=1.1.1 # -- dscudiero -- 04/14/2016 @  8:52:27.06
originalArgStr="$*"
scriptDescription="Set Training mode"
TrapSigs 'on'

#===================================================================================================
# Take a site in/out of training mode
#===================================================================================================
# Copyright ©2015 David Scudiero -- all rights reserved.
# 03-19-13 -- 	dgs - Initial coding
# 03-06-15 -- 	dgs - Converted to bash
# 07-17-15 --	dgs - Migrated to framework 5
#===================================================================================================

#===================================================================================================
# Declare local variables and constants
#===================================================================================================
typeset -u upper

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
ParseArgsStd
Hello
env='next'
Init 'getClient getDirs checkEnvs'

#===================================================================================================
# Main
#===================================================================================================
## Look to see if the site is in training mode
	checkStr=$(grep ^'anyreadonly:Training Mode' $nextDir/courseleaf.cfg)
	if [[ "$checkStr" = "" ]]
	then
		unset ans; Prompt ans "$client is NOT currently in training mode, do you wish to turn it on?" "Yes No"; ans=$(Lower ${ans:0:1})
		[[ $ans == 'y' ]] && turnOn=1
	else
		unset ans; Prompt ans "$client is currently in training mode, do you wish to turn it off?" "Yes No"; ans=$(Lower ${ans:0:1})
		[[ $ans == 'y' ]] && turnOn=0
	fi

## Turn training mode on
if [[ $turnOn = 1 ]]
then
	## anyreadonly
		editFile=$nextDir/courseleaf.cfg
		Msg "Editing file: $editFile"
		checkStr=$(grep ^'//anyreadonly:Training Mode' $editFile)
		if [[ "$checkStr" = "" ]]
		then
			checkStr1=$(grep ^'//sitereadonly:' $editFile)
			checkStr2=$(grep ^'sitereadonly:' $editFile)
			fromStr=$checkStr1$checkStr2
			toStr='anyreadonly:Training Mode'
			sed -i s"_^${fromStr}_${fromStr}\n\n${toStr}_" $editFile
		else
			fromStr='//anyreadonly:Training Mode'
			toStr='anyreadonly:Training Mode'
			sed -i s"_^${fromStr}_${toStr}_" $editFile
		fi

	## training user account
		editFile=$nextDir/courseleaf.cfg
		checkStr1=$(grep ^'user:training|9999||admin' $editFile)
		checkStr2=$(grep ^'//user:training|9999||admin' $editFile)
		fromStr=$checkStr1$checkStr2
		toStr='user:training|9999||admin'
		if [[ "$fromStr" != "" ]] then
			sed -i s"_^${fromStr}_${toStr}_" $editFile
		else
			echo 'user:training|9999||admin' >> $editFile
		fi

	## training:true
		editFile=$nextDir/web/courseleaf/localsteps/default.tcf
		Msg "Editing file: $editFile"
		checkStr1=$(grep ^'training:true' $editFile)
		checkStr2=$(grep ^'//training:true' $editFile)
		fromStr=$checkStr1$checkStr2
		toStr='training:true'
		if [[ "$fromStr" != "" ]] then
			sed -i s"_^${fromStr}_${toStr}_" $editFile
		else
			checkStr1=$(grep ^'softsitereadonly:' $editFile)
			checkStr2=$(grep ^'//softsitereadonly:' $editFile)
			fromStr=$checkStr1$checkStr2
			sed -i s"_^${fromStr}_${fromStr}\n\n${toStr}_" $editFile
		fi
	Msg "\n$myName Completed, training mode is ON"

else
	## Turn training mode off
	## anyreadonly
		editFile=$nextDir/courseleaf.cfg
		Msg "Editing file: $editFile"
		fromStr='anyreadonly:Training Mode'
		toStr='//anyreadonly:Training Mode'
		sed -i s"_^${fromStr}_${toStr}_" $editFile

	## training user account
		editFile=$nextDir/courseleaf.cfg
		fromStr='user:training|9999||admin'
		toStr="//$fromStr"
		sed -i s"_^${fromStr}_${toStr}_" $editFile

	## training:true
		editFile=$nextDir/web/courseleaf/localsteps/default.tcf
		Msg "Editing file: $editFile"
		fromStr='training:true'
		toStr='//training:true'
		sed -i s"_^${fromStr}_${toStr}_" $editFile
	Msg "\n$myName Completed, training mode is OFF"
fi

#===================================================================================================
## Bye-bye
#===================================================================================================
Goodbye 0


