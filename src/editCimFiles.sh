#!/bin/bash
#==================================================================================================
version=1.2.20 # -- dscudiero -- Fri 03/23/2018 @ 14:33:26.44
#==================================================================================================
TrapSigs 'on'
myIncludes=""
Import "$standardInteractiveIncludes $myIncludes"

originalArgStr="$*"
scriptDescription=""

#==================================================================================================
# Edit tso files
#==================================================================================================
#==================================================================================================
# Copyright ©2014 David Scudiero -- all rights reserved.
# xx-xx-15 -- dgs - Initial coding
#==================================================================================================
#
#==================================================================================================
# local functions
#==================================================================================================
	#==============================================================================================
	# parse script specific arguments
	#==============================================================================================
	function editCimFiles-ParseArgsStd  {
		#myArgs+=("shortToken|longToken|type|scriptVariableName|<command to run>|help group|help textHelp")
		myArgs+=('fromStr|fromStr|option|fromStr||script|The "from string" text')
		myArgs+=('toStr|toStr|option|toStr||script|The "to string" text')
		myArgs+=('fileType|fileType|option|fileType||script|The type (ext) of files to process')
	}

	#==============================================================================================
	# Goodbye call back
	#==============================================================================================
	function Goodbye-editCimFiles  {
		SetFileExpansion 'on' ; rm -rf $tmpRoot/${myName}* >& /dev/null ; SetFileExpansion
		return 0
	}

#==================================================================================================
# Declare local variables and constants
#==================================================================================================

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
helpSet='script,client,env'
GetDefaultsData $myName
ParseArgsStd $originalArgStr

Hello
Msg
Init 'getClient getEnv getDirs checkEnvs getCims'

Msg
Prompt fileType "Do you want to edit '.tso' files or '.tcf' files" 'tso tcf' 'tso'; fileType=$(Lower $fileType)
Prompt fromStr "Please specify the 'From' string" '*any*';
Prompt toStr "Please specify the 'To' string" '*any*';

VerifyContinue "You are asking to edit tso files for\n\t$(ColorK 'Client:') '$client'\
				\n\t$(ColorK 'Env:') '$env'\
				\n\t$(ColorK 'CIMs:') '$cimStr'\
				\n\t$(ColorK 'Editing Files:') '$fileType'\
				\n\t$(ColorK 'From String:') '$fromStr'\
				\n\t$(ColorK 'To String:') '$toStr'"

#==================================================================================================
# Main
#==================================================================================================
Msg
for cim in ${cims[@]}; do
	Msg "Processing: $cim"
	cd $srcDir/web/$cim

	Msg "^Scanning $cim directory..."
	ProtectedCall "find -name index.$fileType | xargs grep \"$fromStr\"" > $tmpFile
	Info 0 1 "Found $(wc -l $tmpFile | cut -d' ' -f1) matching files"
	while read -r line; do
		editFile=$(echo $line | cut -d ':' -f1)
		Msg "\t\tEditing File: $editFile"
		[[ -f $editFile.bak ]] && rm $editFile.bak
		$DOIT cp $editFile $editFile.bak
		$DOIT sed -i s"_^${fromStr}_${toStr}_" $editFile
	done < $tmpFile
done

#==================================================================================================
## Done
#==================================================================================================
Goodbye 0 #'alert'

#==================================================================================================
## Check-in log
#==================================================================================================
# 10-22-2015 -- dscudiero -- Script to edit cim tso files (1.1)
# 10-23-2015 -- dscudiero -- use ProtectedCall (1.2)
## 03-22-2018 @ 12:36:11 - 1.2.19 - dscudiero - Updated for Msg3/Msg, RunSql2/RunSql, ParseArgStd/ParseArgStd2
## 03-23-2018 @ 15:34:29 - 1.2.20 - dscudiero - D
