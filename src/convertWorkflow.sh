#!/bin/bash
#====================================================================================================
version=1.0.7 # -- dscudiero -- 12/14/2016 @ 11:23:06.50
#====================================================================================================
TrapSigs 'on'
imports='GetDefaultsData ParseArgs ParseArgsStd Hello Init Goodbye' #imports="$imports "
Import "$imports"
originalArgStr="$*"
scriptDescription="Convert old workflow structure to the new scructure"

#====================================================================================================
# Convert old workflow structure to the new scructure
#====================================================================================================
# Copyright ©2015 David Scudiero -- all rights reserved.
# 09-03-14 -- dgs - Initial coding
# 07-17-15 -- dgs - Migrated to framework 5
# 01-06=15 -- dgs - change '*optional*' to 'optional' if target env is next
#====================================================================================================

#====================================================================================================
# Declare local variables and constants
#====================================================================================================
unset filesUpdated
checkFileNew=workflow.cfg

#==================================================================================================
# Local Subs
#==================================================================================================
#==============================================================================================
# Edit cimconfig.cfg
#==============================================================================================
function EditCimconfigCfg {
	Msg "V2 *** Starting $FUNCNAME ***"
	editFile="$1"
	BackupCourseleafFile $editFile

	fromStr='wfrules:'
	toStr='// Moved to ./workflow.cfg -- wfrules:'
	sed -i s"_^${fromStr}_${toStr}_" $editFile
	fromStr='wforder:'
	toStr='// Moved to ./workflow.cfg -- wforder:'
	sed -i s"_^${fromStr}_${toStr}_" $editFile
	searchStr='%import %pagebasedir%/workflow.cfg'
	unset grepStr; grepStr=$(grep "^$searchStr" $editFile)
	if [[ $grepStr == '' ]]; then
		unset grepStr; grepStr=$(grep "//$searchStr" $editFile)
		if [[ $grepStr == '' ]]; then
			echo >> $editFile
			echo '//=================================================================================================' >> $editFile
			echo '//Worfklow configuraton in ./workflow.cfg' >> $editFile
			echo "//Added by $userName via $myName on $(date)" >> $editFile
			echo $searchStr >> $editFile
			echo '//=================================================================================================' >> $editFile
			echo >> $editFile
		else
			fromStr="//$searchStr"
			toStr="$searchStr"
			sed -i s"_^${fromStr}_${toStr}_" $editFile
		fi
	fi
	return 0
} #EditCimconfig.cfg

#==============================================================================================
# Edit cusom.atj
#==============================================================================================
function EditCustomAtj {
	Msg "V2 *** Starting $FUNCNAME ***"
	editFile="$1"
	BackupCourseleafFile $editFile
	local cim=$(dirname $editFile)
	cim=$(basename $cim)
	searchStr="%import /$cim/workflowFunctions.atj:atj%"
	unset grepStr; grepStr=$(grep "^$searchStr" $editFile)
	if [[ $grepStr == '' ]]; then
		unset grepStr; grepStr=$(grep "//$searchStr" $editFile)
		if [[ $grepStr == '' ]]; then
			echo >> $editFile
			echo '//=================================================================================================' >> $editFile
			echo "//Added by $userName via $myName on $(date)" >> $editFile
			echo '// Import workflow functions' >> $editFile
			echo $searchStr >> $editFile
			echo '//=================================================================================================' >> $editFile
			echo >> $editFile
		else
			fromStr="//$searchStr"
			toStr="$searchStr"
			sed -i s"_^${fromStr}_${toStr}_" $editFile
		fi
	fi
	return 0
} #Editcustom.atj

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
GetDefaultsData $myName
ParseArgsStd
[[ $verbose == true ]] && verboseArg='-v' || unset verboseArg
[[ $env != '' ]] && srcEnv=$env
Hello
Msg2
Init 'getClient getEnv getDirs checkEnvs getCims'
VerifyContinue "You are asking to convert workflow files for client: $client\n\tCIMs: $cimStr\n\tsrcDir: $srcDir\n"

#====================================================================================================
## Main
#====================================================================================================
## Save off the source and target workflow files
	fileSuffix="$(date +%s)"
	Msg2 "Saving source ($env) workflow files ..."
	saveWorkflow $USELOCAL $client -$env -cims "$(echo $cimStr | tr -d ' ')" -suffix "before$(TitleCase $myName)-$fileSuffix" -nop -quiet $verboseArg

## CIMs
	Msg2
 	Msg2 "Processing CIM insances ..."
	for cim in $(echo $cimStr | tr ',' ' '); do
		Msg2 "^$cim:"
		##  Check to make sure the CIM instance has not already been converted
			[[ -f $srcDir/web/$cim/$checkFileNew ]] && Warning 0 3 "The source file structure is already NEW, skipping" && continue

		## cimconfig.cfg
			EditCimconfigCfg "$srcDir/web/$cim/cimconfig.cfg"
			[[ -f $HOME/js/$cim/workflow.cfg ]] && cp -fp $HOME/js/$cim/workflow.cfg $srcDir/web/$cim || \
				Warning 0 3 "Could not locate local workflow.cfg file: \n\t'$HOME/js/$cim/workflow.cfg'"
			Msg2 "^^Converted cimconfig.cfg"
			filesUpdated+=(/web/$cim/cimconfig.cfg)

		## custom.atj
			EditCustomAtj "$srcDir/web/$cim/custom.atj"
			[[ -f $HOME/js/$cim/workflowFunctions.atj ]] && cp -fp $HOME/js/$cim/workflowFunctions.atj $srcDir/web/$cim || \
				Warning 0 3 "Could not locate local workflowFunctions.atj file: \n\t'$HOME/js/$cim/workflowFunctions.atj'"
			[[ -f $HOME/js/$cim/workflowHelperFunctions.atj ]] && cp -fp $HOME/js/$cim/workflowHelperFunctions.atj $srcDir/web/$cim || \
				Warning 0 3 "Could not locate local workflowHelperFunctions.atj file: \n\t'$HOME/js/$cim/workflowHelperFunctions.atj'"
			Msg2 "^^Converted custom.atj"
			filesUpdated+=(/web/$cim/custom.atj)
	done #Cims

## Write out change log entries
	if [[ ${#filesUpdated} -gt 0 ]]; then
		Msg2 "\n$userName\t$(date)" >> $srcDir/changelog.txt
		Msg2 "^$myName converted workflow files to new structure:" >> $srcDir/changelog.txt
		for file in "${filesUpdated[@]}"; do
			Msg2 "^^$file" >> $srcDir/changelog.txt
		done
	fi

#====================================================================================================
## Bye-bye
Goodbye 0
## Fri Apr  1 13:29:46 CDT 2016 - dscudiero - Swithch --useLocal to $useLocal
## Wed Apr  6 16:08:45 CDT 2016 - dscudiero - switch for
