#!/bin/bash
#==================================================================================================
version=1.0.14 # -- dscudiero -- Thu 09/14/2017 @ 15:40:55.77
#==================================================================================================
TrapSigs 'on'
includes='Msg2 Dump GetDefaultsData ParseArgsStd Hello DbLog Init Goodbye'
Import "$includes"
originalArgStr="$*"
scriptDescription="Check the roles to ensure that all role members are in user provsioning"

#==================================================================================================
# Interogate the roles file and verify that all the users listed in roles are in provsioning
# (in the clusers database)
#==================================================================================================
#==================================================================================================
# Copyright ©2014 David Scudiero -- all rights reserved.
# 06-17-15 -- 	dgs - Initial coding
# 07-17-15 -- dgs - Migrated to framework 5
#==================================================================================================

#==================================================================================================
# local functions
#==================================================================================================
	#==================================================================================================
	# parse script specific arguments
	#==================================================================================================
	function parseArgs-checkRoleMembers {
		# argList+=(argFlag,minLen,type,scriptVariable,exCmd,helpSet,helpText)  #type in {switch,switch#,option,help}
		#argList+=(-listOnly,1,switch,listOnly,,script,"Do not do copy, only list out files that would be copied")
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
Init 'getClient getEnv getDirs checkEnvs'

## Set outfile -- look for std locations
outFileName=$client-$env-$myName.txt
if [[ -d $localClientWorkFolder ]]; then
	if [[ ! -d $localClientWorkFolder/$client ]]; then mkdir $localClientWorkFolder/$client; fi
	outFile=$localClientWorkFolder/$client/$outFileName
else
	outFile=/home/$userName/$outFileName
fi

verifyArgs+=("Client:$client")
verifyArgs+=("Env:$(TitleCase $env)")
verifyArgs+=("Output File:$outFile")
verifyContinueDefault='Yes'
VerifyContinue "You are asking to check role data for client:$client\n\tEnv: $env\n"
Msg2

#==================================================================================================
## Main
#==================================================================================================
## check outfile
	if [[ -f $outFile ]]; then
		Warning "Output file already exists, renaming to\n\t$outFile.$backupSuffix\n"
		mv $outFile $outFile.$backupSuffix
	fi

## Get members roles file
	unset numFound
	unset users
	Msg2 "Processing Roles file..."
	while IFS='' read -r line || [[ -n $line ]]; do
		#role:AABS Approver|JB_Ashorn|all
		if [[ ${line:0:5} == 'role:' ]]; then
	    	role=$(echo $(echo $line | cut -d ':' -f 2) | cut -d '|' -f 1)
	    	members=$(echo $(echo $line | cut -d '|' -f 2) | tr ',' ' ')
	      	#Verbose 1 1 "Role: $role\n^Members: >$members<"
	      	IFSsave=$IFS; IFS=' '
		    for user in $members; do
		    	#Verbose 1 2 "user = >$user<"
				users+=($user)
		    done
		    IFS=$IFSsave
		fi
	done < "$srcDir/web/courseleaf/roles.tcf"

## Sort the list, through away duplicates
	usersSorted=($(for user in "${users[@]}"; do echo "$user"; done | sort))
	unset users
	unset prevUser
	for user in "${usersSorted[@]}"; do
		if [[ $user != $prevUser ]]; then
			users+=($user)
			(( numFound +=1 ))
		fi
		prevUser=$user
	done
	Msg2 "^Found $numFound unique userids"

## Process the user list
	printedHeader=false
	unset numFound
	Msg2 "Processing User list..."
	for user in "${users[@]}"; do
		sqlStmt="select count(*) from users where userid=\"$user\";"
		results=$(sqlite3 /$srcDir/db/clusers.sqlite "$sqlStmt")
		#Verbose "\nUser: '$user'\n\t\tsqlStmt = >$sqlStmt<\n\t\tresults=>$results<"
		if [[ $results -eq 0 ]]; then
			grep -q "user\:$user\|" "$srcDir/courseleaf.cfg"; rc=$?
			if [[ $rc -ne 0 ]]; then
				[[ $printedHeader == false ]] && Msg2 "The following users were not found in User Provisioning:"
				printedHeader=true
				Msg2 "^$user" | tee -a $outFile
				(( numFound +=1 ))
			fi
		fi
	done
## Print summary
	echo
	if [[ $numFound -eq 0 ]]; then
		Msg2 "^All role members are provisioned or listed on a courseleaf.cfg user record"
		rm -f "$outFile" >& /dev/null
	else
		Msg2 "^Found $numFound users in roles that are not known"
		Msg2 "\nOutput file: $outFile"
	fi

#==================================================================================================
## Done
#==================================================================================================
Goodbye 0 #'alert'## Fri Oct 14 13:37:34 CDT 2016 - dscudiero - Fix spelling problem
## 06-19-2017 @ 07.07.26 - (1.0.12)    - dscudiero - Update to check courseleaf.cfg user records also
