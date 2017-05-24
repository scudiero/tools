#!/bin/bash
# XO NOT AUTOVERSION
#==================================================================================================
version=3.4.140 # -- dscudiero -- Wed 05/24/2017 @  8:26:33.99
#==================================================================================================
TrapSigs 'on'
Import ParseArgs ParseArgsStd Hello Init Goodbye
originalArgStr="$*"
scriptDescription="Cleanup private dev sites"

#==================================================================================================
## Clean up private dev sites
#==================================================================================================
# Copyright ©2015 David Scudiero -- all rights reserved.
# 08-30-13 -- 	dgs - Initial coding
# 07-17-15 --	dgs - Migrated to framework 5
#==================================================================================================
#==================================================================================================
# local functions
#==================================================================================================
	#==================================================================================================
	# parse script specific arguments
	#==================================================================================================
	function parseArgs-cleanDev {
		# argList+=(argFlag,minLen,type,scriptVariable,extraToken/exCmd,helpSet,helpText)  #type in {switch,switch#,option,help}
		argList+=(-mark,1,switch,mark,,'script',"Mark the site for deletion")
		argList+=(-delete,3,switch,delete,,'script',"Delete the site")
		argList+=(-unMark,1,switch,unMark,,'script',"Unmark the site")
	}
	function Goodbye-cleanDev  { # or Goodbye-local
		SetFileExpansion 'on' ; rm -rf $tmpRoot/${myName}* >& /dev/null ; SetFileExpansion
		return 0
	}

	#==================================================================================================
	# Get sites
	#==================================================================================================
	function GetSites {
		local searchStr="$1"
		local file tempStr printedSep sepLen sep i siteId loop
		local maxLen=0

		until [[ $loop == false ]]; do
			## Get the list of files
			unset validSiteIds workFiles filesList1 filesList2 filesList3 fileList4
			filesList1="$(ProtectedCall "ls /mnt/$share/web" | ProtectedCall "grep -v .BeingDeleted" | ProtectedCall "grep $searchStr" | ProtectedCall "grep -v .AutoDelete")"
			filesList2="$(ProtectedCall "ls /mnt/$share/web" | ProtectedCall "grep -v .BeingDeleted" | ProtectedCall "grep $searchStr" | ProtectedCall "grep .AutoDeleteWithSave")"
			filesList3="$(ProtectedCall "ls /mnt/$share/web" | ProtectedCall "grep -v .BeingDeleted" | ProtectedCall "grep $searchStr" | ProtectedCall "grep .AutoDeleteNoSave")"
			filesList4="$(ProtectedCall "ls /mnt/$share/web" | ProtectedCall "grep $searchStr" | ProtectedCall "grep .BeingDeleted")"
			workFiles=($filesList1 $filesList2 $filesList3 $fileList4)

			## Build menu list
			if [[ ${#workFiles[@]} -gt 0 ]]; then
				[[ ${#workFiles[@]} -eq 1 ]] && sites=("${workFiles[0]}") && return 0
				[[ $batchMode != true && $noClear != true && $TERM != 'dumb' ]] && clear
				Msg2; Msg2; Msg2 "The following private dev sites were found for you on this host:"
				for file in "${workFiles[@]}"; do
					[[ ${#file} -gt $maxLen ]] && maxLen=${#file}
				done
				let maxLen=$maxLen+3
				dots=$(PadChar '.' $maxLen)
				let sepLen=maxLen+22
				sep="\t   $(PadChar '-' $sepLen)\n"
				printedSep1=false; printedSep2=false; printedSep3=false;
				for ((i = 0 ; i < ${#workFiles[@]} ; i++)); do
					timeStamp='Unknown'
					for env in dev test next curr qa; do
						file=/mnt/$share/web/${workFiles[$i]}/.clonedFrom-$env
						#dump env file
						[[ -f $file ]] && timeStamp=$(stat -c %z $file | awk 'BEGIN {FS=" "}{printf "%s", $1}' | awk 'BEGIN {FS="-"}{printf "%s-%s-%s", $2,$3,$1}') && break
					done
					tempStr=${workFiles[$i]}$dots; tempStr=${tempStr:0:$maxLen}
					[[ $(Contains "$tempStr" 'AutoDeleteWithSave') == true && $printedSep1 == false ]] && printf "$sep" && printedSep1=true
					[[ $(Contains "$tempStr" 'AutoDeleteNoSave') == true && $printedSep2 == false ]] && printf "$sep" && printedSep2=true
					[[ $(Contains "$tempStr" 'BeingDeleted') == true && $printedSep3 == false ]] && printf "$sep" && printedSep3=true
				  	printf "\t%2s %s (Created: %s) \n" "$i" "$tempStr" "$timeStamp"
				  	[[ "$validSiteIds" = '' ]] && validSiteIds="$i" || validSiteIds="$validSiteIds $i"
				done
				unset siteId
				#validSiteIds="$validSiteIds All Refresh"
				Prompt siteId "\nPlease enter the ordinal number(s) of the site you wish to Process, \nor 'X' to quit" "$validSiteIds All Refresh"
				[[ $(Lower $siteId) == 'r' ]] && loop=true || loop=false
			fi ## [[ ${#workFiles[@]} -gt 0 ]]
		done

		## Build the sites array
		unset sites
		[[ $siteId == 'All' ]] && siteId="$(tr ' ' ',' <<< $validSiteIds)"
		for i in $(tr ',' ' ' <<< $siteId); do
			sites+=("${workFiles[$i]}")
		done
		return 0
	} #GetSites

	#==================================================================================================
	# Process request
	#==================================================================================================
	function ProcessRequest {
		local type="$1"
		local file="/mnt/$share/web/$2"
		local processClient=$(cut -d'-' -f1 <<< $2)
		dump -1 -p processClient requestType file

		case "$requestType" in
			m*)
				echo; Msg2 "Marking '$file' for automatic deletion in $deleteLimitDays days..."
				$DOIT mv "$file" "$file".AutoDeleteNoSave
				$DOIT touch "$file".AutoDeleteNoSave/.AutoDeleteNoSave
				;;
			s*)
				echo; Msg2 "Holding '$file' as '$file'.save..."
				$DOIT mv "$file" "$file".save
				;;
			u*)
				echo; Msg2 "UnMarking '$file'..."
				newFileName=$(sed 's|.AutoDeleteNoSave||g' <<< ${workFiles[$siteId]})
				$DOIT mv "$file" /mnt/$share/web/$newFileName
				$DOIT rm /mnt/$share/web/$newFileName/.AutoDeleteNoSave
				;;
			r*)
				echo; Msg2 "Reseting 'marked' date for '$file'..."
				$DOIT touch "$file"/.clonedFrom*
				;;
			y*)
				if [[ $userName = 'dscudiero' ]]; then
					unset ans
					Prompt ans "^Do you wish to save the workflow files" 'Yes No' 'Yes' ; ans=$(Lower "${ans:0:1}")
					[[ $ans == 'y' ]] && Msg2 "Saving workflow..." && Call saveWorkflow $processClient -p -all -suffix "beforeDelete-$backupSuffix" -nop #-quiet
				fi
				echo; Msg2 "Removing '$file' offline..."
				if [[ $DOIT == '' ]]; then
					mv -f "$file" "$file".BeingDeletedBy$(TitleCase "$myName")
					(nohup rm -rf "$file".BeingDeletedBy$(TitleCase "$myName") &> /dev/null) &
				else
					Msg2 "*** DOIT flag is off, skipping delete ***"
				fi
				;;
			w*)
				mv -f "$file" "$file--AutoDeleteWithSave"
		esac
		return 0
	} #ProcessRequest

#==================================================================================================
# Declare variables and constants, bring in includes file with subs
#==================================================================================================
idx=1
short=1
unset action
deleteLimitDays=7

## Get the deleteLimitDays from db -- lookup from checkForPrivateDevSites script data
sqlStmt="select scriptData1 from $scriptsTable where name=\"checkForPrivateDevSites\""
RunSql2 $sqlStmt
[[ ${#resultSet[@]} -ne 0 ]] && deleteLimitDays=${resultSet[0]}

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
ParseArgsStd
dump -1 mark delete unMark client
Hello

## Get the workflow files
GetDefaultsData 'copyWorkflow'
## Get the workflow files to check from the database
	unset requiredInstanceFiles optionalInstanceFiles requiredGlobalFiles optionalGlobalFiles ifThenDelete
	[[ $scriptData1 == '' ]] && Msg2 $T "'scriptData1 (requiredInstanceFiles)' is null, please check script configuration data"
	requiredInstanceFiles="$(cut -d':' -f2- <<< $scriptData1)"

	[[ $scriptData2 == '' ]] && Msg2 $T "'scriptData2 (optionalInstanceFiles)' is null, please check script configuration data"
	optionalInstanceFiles="$(cut -d':' -f2- <<< $scriptData2)"

	[[ $scriptData3 == '' ]] && Msg2 $T "'scriptData3 (requiredGlobalFiles)' is null, please check script configuration data"
	requiredGlobalFiles="$(cut -d':' -f2- <<< $scriptData3)"

	[[ $scriptData4 == '' ]] && Msg2 $T "'scriptData4 (optionalGlobalFiles)' is null, please check script configuration data"
	optionalGlobalFiles="$(cut -d':' -f2- <<< $scriptData4)"

	if [[ $scriptData5 ]]; then
		ifThenDelete="$(cut -d':' -f2- <<< $scriptData5)"
		deleteThenIf=$(tr ',' ';' <<< $deleteThenIf)
		deleteThenIf=$(tr ' ' ',' <<< $deleteThenIf)
		deleteThenIf=$(tr ';' ' ' <<< $deleteThenIf)
	fi

	dump -2 requiredInstanceFiles requiredGlobalFiles optionalInstanceFiles optionalGlobalFiles

#==================================================================================================
# Main
#==================================================================================================
## Get a list of directories
if [[ "$hostName" = 'build5' ]]; then share=dev9
elif [[ "$hostName" = 'build7' ]]; then share=dev7
elif [[ "$hostName" = 'mojave' ]]; then share=dev6
fi
validActions='Yes No Mark Unmark ResetDate Save'
[[ $userName == 'dscudiero' ]] && validActions="$validActions Workflow"
searchStr="$userName"
## if client was passed in then just delete that site, otherwise if it is 'daemon' then process autodeletes
if [[ -n $client ]]; then
	if [[ $client == 'daemon' ]]; then
		Msg2 "Starting $myName in daemon mode..."
		filePrefix="/mnt/dev*/web/*-$searchStr"
		fileList="$(ProtectedCall "ls /mnt/dev*/web/*-$searchStr* | grep 'AutoDelete'")"
		for file in $fileList; do
			file=$(tr -d ':' <<< "$file")
			if [[ $(Contains "$file" 'WithSave') == true ]]; then
				Msg2 "^Deleting '$(basename $file)' with workflow save"
				Call saveWorkflow -daemon -siteFile "$file" -all -suffix "beforeDelete-$backupSuffix -quiet -nop"
			else
				Msg2 "^Deleting '$(basename $file)'"
			fi
			mv -f "$file" "$file.BeingDeletedBy$(TitleCase "$myName")"
			(nohup rm -rf "$file.BeingDeletedBy$(TitleCase "$myName")" &> /dev/null) &
		done
		Msg2 "Ending $myName in daemon mode..."
		Goodbye 0
	else
		searchStr="$client-$searchStr"
	fi
fi

while [ true == true ]; do
	unset site requestType
	GetSites "$searchStr"
	[[ ${#sites[@]} -eq 0 ]] && break
	for site in ${sites[@]}; do
		[[ $site == '' ]] && Msg2 "No sites found or all sites have been processed" && Goodbye 0
		echo; Msg2  "You are asking to process site: '$site', are you sure?"
		unset ans; Prompt ans " " "$validActions"; requestType=$(Lower ${ans:0:2})
		ProcessRequest "$requestType" "$site"
	done
done

#==================================================================================================
## Bye-bye
Goodbye 0
# 12-10-2015 -- dscudiero -- refactor and processed passed in client name (3.2)
# 12-18-2015 -- dscudiero -- refactore emailing (3.4.0)
## Thu Apr 21 14:24:22 CDT 2016 - dscudiero - nonup on the forked tasks so they keep running
## Thu Apr 21 14:27:14 CDT 2016 - dscudiero - nonup on the forked tasks so they keep running
## Wed Apr 27 16:16:14 CDT 2016 - dscudiero - Switch to use RunSql
## Thu Jul 14 17:03:01 CDT 2016 - dscudiero - Save off workflow files before deleteion
## Tue Jul 19 16:38:29 CDT 2016 - dscudiero - Added fx option to skip the workflow save step
## Thu Jul 28 09:27:03 CDT 2016 - dscudiero - Add a FN action code
## Thu Jul 28 09:29:30 CDT 2016 - dscudiero - Add a FN action code
## Thu Jul 28 15:57:20 CDT 2016 - dscudiero - General syncing of dev to prod
## Thu Sep  8 09:59:03 CDT 2016 - dscudiero - Fork off the saveworkflow step
## Tue Sep 13 08:23:53 CDT 2016 - dscudiero - General syncing of dev to prod
## Thu Oct  6 08:49:44 CDT 2016 - dscudiero - Allow selection of multiples
## Mon Oct 10 14:04:27 CDT 2016 - dscudiero - Fix looping problem
## Fri Oct 14 13:05:30 CDT 2016 - dscudiero - Fix problem with not returning after first delete
## Mon Oct 24 10:15:01 CDT 2016 - dscudiero - Fix message text
## Thu Jan 12 10:44:24 CST 2017 - dscudiero - Prompt to see if we should save workfow
## 04-26-2017 @ 13.46.55 - (3.4.73)    - dscudiero - General syncing of dev to prod
## 05-04-2017 @ 14.17.07 - (3.4.114)   - dscudiero - Add daemon mode to support automatic cleanup
## 05-04-2017 @ 14.20.26 - (3.4.115)   - dscudiero - Add quiet flag on saveWorkflow call
## 05-10-2017 @ 14.36.11 - (3.4.137)   - dscudiero - Refactor the daemon code
## 05-15-2017 @ 07.11.45 - (3.4.138)   - dscudiero - Activate code for daemon
## 05-18-2017 @ 06.58.05 - (3.4.138)   - dscudiero - Fix the end of the case statement
## 05-19-2017 @ 08.51.46 - (3.4.139)   - dscudiero - Removed dead code
## 05-24-2017 @ 08.31.28 - (3.4.140)   - dscudiero - Add Goodbye-cleanDev function
