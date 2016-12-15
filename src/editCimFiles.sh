#!/bin/bash
#==================================================================================================
version=1.2.18 # -- dscudiero -- 12/14/2016 @ 11:26:26.34
#==================================================================================================
TrapSigs 'on'
imports='GetDefaultsData ParseArgs ParseArgsStd Hello Init Goodbye' #imports="$imports "
Import "$imports"
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
	function parseArgs-editCimFiles  {
		argList+=(-fromStr,2,option,fromStr,,script,'The "from string" text')
		argList+=(-toStr,2,option,toStr,,script,'The "to string" text')
		argList+=(-fileType,2,option,fileType,,script,'The type (ext) of files to process')
	}

	#==============================================================================================
	# Goodbye call back
	#==============================================================================================
	function Goodbye-editCimFiles  {
		[[ -f $tmpFile ]] && rm -rf $tmpFile
	}

	#==============================================================================================
	# TestMode overrides
	#==============================================================================================
	function testMode-editCimFiles  {
		:
	}


#==================================================================================================
# Declare local variables and constants
#==================================================================================================

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
helpSet='script,client,env'
GetDefaultsData $myName
ParseArgsStd

Hello
Msg2
Init 'getClient getEnv getDirs checkEnvs getCims'

Msg2
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
Msg2
for cim in ${cims[@]}; do
	Msg2 "Processing: $cim"
	cd $srcDir/web/$cim

	Msg2 "^Scanning $cim directory..."
	ProtectedCall "find -name index.$fileType | xargs grep \"$fromStr\"" > $tmpFile
	Info 0 1 "Found $(wc -l $tmpFile | cut -d' ' -f1) matching files"
	while read -r line; do
		editFile=$(echo $line | cut -d ':' -f1)
		Msg2 "\t\tEditing File: $editFile"
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
