#!/bin/bash
##O NOT AUTOVERSION
#==================================================================================================
version=1.0.23 # -- dscudiero -- 12/28/2016 @ 11:35:07.00
#==================================================================================================
TrapSigs 'on'
imports='GetDefaultsData ParseArgs ParseArgsStd Hello Init Goodbye'
imports="$imports SetupInterpreterExecutionEnv"
Import "$imports"
originalArgStr="$*"
scriptDescription=""

#= Description +===================================================================================
#
#
#==================================================================================================
#==================================================================================================
# Standard call back functions
#==================================================================================================
function parseArgs-backupData  { # or parseArgs-local
	#argList+=(-optionArg,1,option,scriptVar,,script,'Help text')
	#argList+=(-flagArg,2,switch,scriptVar,,script,'Help text')
	argList+=(-file,4,option,file,,script,'The file name relative to the root site directory')
	return 0
}
function Goodbye-backupData  { # or Goodbye-local
	rm -rf $tmpRoot > /dev/null 2>&1
	return 0
}
function testMode-backupData  { # or testMode-local
	[[ $userName != 'dscudiero' ]] && Msg "T You do not have sufficient permissions to run this script in 'testMode'"
	return 0
}

#==================================================================================================
# local functions
#==================================================================================================
#===================================================================================================
# local functions
#===================================================================================================
#====================================================================================================
# Backup files to the google drive
# BackupToGoogleDrive <name> <location> <filesToTar>
# 	name = The root name of the tarFile, tarFile name is '/Backups/DURO/$name/$name.$(date +"%a").tar.gz'
#	tarFileName = 'today', 'yesterday', or the tar file name to use
# 	location = The location where the files to backup are located
# 	filesToTar = The list of files/directories to backup, may also contain tar directives
# Files are tared up and copied to the google drive, it is assumed that google drive permissions have
# been initialized (drive init) at the users $HOME directory.
#====================================================================================================
# 03-22-16 - dgs - initial
#====================================================================================================
function BackupExternal {
	Msg2 $V2 "*** $FUNCNAME -- Starting ***"
	local target=$(Lower "$1"); shift
	local name=$1; shift
	local tarFileName=$1; shift
		[[ $tarFileName = '' ]] && tarFileName='today'
	local location=$1; shift
		[[ $location = '' ]] && location=$(pwd)
	local filesToTar=$1; shift
		[[ $filesToTar = '' ]] && filesToTar='*'
	local tarOptions="$*"
		[[ $tarOptions == '' ]] && tarOptions=''
	local tarArgs='-cf'
	local localTarFile remoteTarFile cwd
	dump -2 -n name tarFileName location filesToTar tarOptions tarArgs

	## Build tarfile name
		if [[ $(Lower $tarFileName) == 'today' ]]; then
			tarFileName="$name-$(date +"%a").tar.gz"
		elif [[  $(Lower $tarFileName) == 'yesterday' ]]; then
			tarFileName="$name-$(date --date="1 day ago" +"%a").tar.gz"
		else
			tarFileName="$name-$(date +"%a-%m.%d.%y@%H.%M.%S").tar.gz"
		fi
		dump -3 tarFileName
		cwd=$(pwd)

	## Tar up the data
		SetFileExpansion 'on'
		Msg2 "^^$name: Generating tar file ($tarFileName)..."
		localTarFile="$HOME/Backups/$tarFileName"
		[[ ! -d $(dirname $localTarFile) ]] && mkdir -p $(dirname $localTarFile)
		rm -f $(dirname $localTarFile)/$name-*
		cd "$location"
		tar $tarArgs $localTarFile $filesToTar $tarOptions
		SetFileExpansion

	## Save the data off to stable storage
		Msg2 "^^$name: Copying tar file to remote location ($target)..."
		cd $HOME
		pathSave="$PATH"
		if [[ ${target:0:1} == 'g' ]]; then
			## Setup the environment
			SetupInterpreterExecutionEnv 'Go'
			export PATH=$GOPATH/bin:$GOROOT/bin:$PATH
			## Remove remote file if it exists, then copy the new file
			remoteTarFile="./Backups/DURO/$name/$tarFileName"
			drive trash -quiet $remoteTarFile > /dev/null
			drive push -no-prompt -quiet $remoteTarFile > /dev/null
		elif [[ ${target:0:1} == 'a' ]]; then
			## Setup the environment
			SetupInterpreterExecutionEnv
			export PATH="$PYDIR/bin:$PATH"
			remoteDir="/Backups/DURO/$name"
			acdcli sync > /dev/null
			acdcli mkdir -p $remoteDir > /dev/null
			acdcli upload --overwrite --force $localTarFile $remoteDir | \tee "$tmpFile"
			grepStr=$(ProtectedCall "grep '[CRITICAL]' $tmpFile")
			if [[ $grepStr != '' ]]; then
				Msg2 $E "Write of file $localTarFile to Amazon Cloud Drive"
				cat $tmpFile
				Goodbye -1
			fi
		fi
		export PATH="$pathSave"
		cd $cwd

	Msg2 $V2 "*** $FUNCNAME -- Completed ***"
	return 0
} #BackupExternal


#==================================================================================================
# Declare local variables and constants
#==================================================================================================
tmpFile=$(mkTmpFile)
trueVars=''
falseVars=''
for var in $trueVars; do eval $var=true; done
for var in $falseVars; do eval $var=false; done

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
GetDefaultsData $myName
ParseArgsStd
Hello

#===================================================================================================
# Main
#===================================================================================================
#==================================================================================================

mySqlUser='dscudiero';
mySqlPw='m1chaels-';

if [[ -z $client || $(Contains "$client" 'Db') == true ]]; then
	Msg2; Msg2 "Exporting databases..."
	## Dump the production data warehouse database
		mysqldump -h $sqlHostIP -u $mySqlUser -p$mySqlPw $warehouseProd > /tmp/warehouse.sql;
	## Dump the production contacts database
		sqlStmt=".dump";
		sqlite3 "$contactsSqliteFile" "$sqlStmt" > /tmp/contacts.sql;
fi

## Backup data
	Msg2; Msg2 "Backing up directories/files/dbs to External resource...";
	## Loop through the backup rules
		forkCntr=1
		fields="name,location,tarFileName,filesToTar,tarOptions,type"
		sqlStmt="Select $fields from $backupRulesTable where active=\"Yes\""
		[[ -n $client ]] && sqlStmt="$sqlStmt and lower(name) = \"$client\""
		RunSql 'mysql' "$sqlStmt"
		for result in "${resultSet[@]}"; do
		 	resultString=$result; resultString=$(echo "$resultString" | tr "\t" "|" )
			dump -2 -n resultString
			fieldCntr=1
			for field in $(echo $fields | tr ',' ' '); do
				eval $field=\"$(echo "$resultString" | cut -d '|' -f $fieldCntr)\"
				[[ ${!field} == 'NULL' ]] && eval $field=''
				Msg2 $V1 "^^$field = >${!field}<"
				(( fieldCntr += 1 ))
			done
			dump -2 -t $(echo $fields | tr ',' ' ')
			SetFileExpansion 'off'
			Msg2 "^Processing backup rule: $name"
			eval "BackupExternal \"$type\" \"$name\" \"$tarFileName\" \"$location\" \"$filesToTar\" \"$tarOptions\" $forkStr"
			SetFileExpansion
			[[ $fork == true && $((forkCntr%$maxForkedProcesses)) -eq 0 ]] && echo "...Waiting on forked tasks..." && wait
			(( forkCntr+=1 ))
			Msg2 "^^$name completed"
		done

	[[ $fork == true ]] && echo "...Waiting on forked tasks..." && wait
	Msg2 "^...done"

## Cleanup
	[[ -f /tmp/warehouse.sql ]] && rm -f /tmp/warehouse.sql
	[[ -f /tmp/contacts.sql ]] && rm -f /tmp/contacts.sql

#===================================================================================================
## Done
#===================================================================================================
Goodbye 0 #'alert'

#===================================================================================================
## Check-in log
#===================================================================================================
