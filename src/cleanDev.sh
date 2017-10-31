#!/bin/bash
# XO NOT AUTOVERSION
#==================================================================================================
version=3.5.49 # -- dscudiero -- Tue 10/31/2017 @  8:47:41.71
#==================================================================================================
Here CD0; Dump verboseLevel
TrapSigs 'on'
myIncludes="ProtectedCall StringFunctions PushPop"
Import "$standardInteractiveIncludes $myIncludes"
Here CD1; Dump verboseLevel

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
# Standard call back functions
#==================================================================================================
	function ParseArgsStd-cleanDev {
		# argList+=(argFlag,minLen,type,scriptVariable,extraToken/exCmd,helpSet,helpText)  #type in {switch,switch#,option,help}
		argList+=(-mark,1,switch,mark,,'script',"Mark the site for deletion")
		argList+=(-delete,3,switch,delete,,'script',"Delete the site")
		argList+=(-unMark,1,switch,unMark,,'script',"Unmark the site")
		argList+=(-daemon,1,switch,daemonMode,,'script',"Run in daemon mode")
	}

	function Goodbye-cleanDev  { # or Goodbye-local
		SetFileExpansion 'on' ; rm -rf $tmpRoot/${myName}* >& /dev/null ; SetFileExpansion
		return 0
	}

	function Help-cleanDev  {
		helpSet='client,env' # can also include any of {env,cim,cat,clss}, 'script' and 'common' automatically addeed
		[[ $1 == 'setVarsOnly' ]] && return 0

		[[ -z $* ]] && return 0
		bullet=1
		echo -e "This script can be used to cleanup private (pvt) development sites i.e. sites of the form '<client>-$userName'."
		echo -e "\nThe actions performed are:"
		echo -e "\t$bullet) Selected sites are processed based on the requested action:"
		echo -e "\t\t- Marking a site for automatic deletion"
		echo -e "\t\t- Holding a site so automatic delete will not process it"
		echo -e "\t\t- Unmarking a site selected for automatic deletion"
		echo -e "\t\t- Resting the time date stamp used for automatic deletion"
		echo -e "\t\t- Removing the sit"
		(( bullet++ ))
		echo -e "\nTarget site data files potentially modified:"
		echo -e "\tAs above"
		return 0
	}

#==================================================================================================
# Localfunctions
#==================================================================================================
	#==================================================================================================
	# Get sites
	#==================================================================================================
	function GetSites {
		[[ $batchMode == true ]] && Terminate "Cannot runn '$FUNCNAME' in batch mode"
		local searchStr="$1"
		local file tempStr printedSep sepLen sep i siteId loop=true
		local maxLen=0

		unset sites
		until [[ $loop == false ]]; do
			## Get the list of files
			unset validSiteIds workFiles filesList1 filesList2 filesList3 fileList4
			filesList1="$(ProtectedCall "ls /mnt/$share/web" | ProtectedCall "grep -v .BeingDeleted" | ProtectedCall "grep $searchStr" | ProtectedCall "grep -v .AutoDelete" | ProtectedCall "grep -v lilypadu-dscudiero")"
			filesList2="$(ProtectedCall "ls /mnt/$share/web" | ProtectedCall "grep -v .BeingDeleted" | ProtectedCall "grep $searchStr" | ProtectedCall "grep .AutoDeleteWithSave")"
			filesList3="$(ProtectedCall "ls /mnt/$share/web" | ProtectedCall "grep -v .BeingDeleted" | ProtectedCall "grep $searchStr" | ProtectedCall "grep .AutoDeleteNoSave")"
			filesList4="$(ProtectedCall "ls /mnt/$share/web" | ProtectedCall "grep $searchStr" | ProtectedCall "grep .BeingDeleted")"
			workFiles=($filesList1 $filesList2 $filesList3 $fileList4)
			[[ ${#workFiles[@]} -eq 0 ]] && return 0

			## Build menu list
			if [[ ${#workFiles[@]} -gt 0 ]]; then
				[[ $batchMode != true && $noClear != true && $TERM != 'dumb' ]] && clear
				[[ ${#workFiles[@]} -eq 1 ]] && echo && Info "Only a single site was found (${workFiles[0]})" && sites=("${workFiles[0]}") && return 0
				Msg3; Msg3; Msg3 "The following private dev sites were found for you on this host:"
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
				unset siteIds
				Prompt siteIds "\nPlease enter the ordinal number(s) of the site you wish to Process.\nMay be comma seperated or n-m notation or any combination there of, \nor 'All', or 'X' to quit" "*any*"
				[[ $(Lower ${siteIds:0:1}) == 'r' ]] && loop=true && continue
				[[ $(Lower ${siteIds:0:1}) == 'a' ]] && siteIds="$(tr ' ' ',' <<< $validSiteIds)" && break
				if [[ $(Contains "$siteIds" '-') == true ]]; then
					front=${siteIds%%-*}; lowerIdx=${front: -1}
					back=${siteIds##*-}; upperIdx=${back:0:1}
					for ((iix=$lowerIdx+1; iix<$upperIdx; iix++)); do
						front="$front,$iix"
					done
					siteIds="$front,$back"
				fi
				## Vaidate response
				validSiteIdsCommas=",$(tr ' ' ',' <<< $validSiteIds),"
				for i in $(tr ',' ' ' <<< $siteIds); do
					if [[ $(Contains "$validSiteIdsCommas" ",$i,") != true ]]; then
						Error "Invalid id ($i) specified, please try again"
						Pause "Press enter to continue"
						loop=true
					else
						loop=false
					fi
				done
			fi ## [[ ${#workFiles[@]} -gt 0 ]]
		done

		## Build the sites array
		unset sites
		if [[ -n $siteIds ]]; then
			for i in $(tr ',' ' ' <<< $siteIds); do
				sites+=("${workFiles[$i]}")
			done
		fi

		return 0
	} #GetSites

	#==================================================================================================
	# Process request
	#==================================================================================================
	function ProcessRequest {
		local type="$1"
		local file="/mnt/$share/web/$2"
		local processClient=$(cut -d'-' -f1 <<< $2)
		dump 1 -p processClient requestType file

		case "$requestType" in
			m*)
				echo; Msg3 "Marking '$file' for automatic deletion in $deleteLimitDays days..."
				$DOIT mv "$file" "$file".AutoDeleteNoSave
				$DOIT touch "$file".AutoDeleteNoSave/.AutoDeleteNoSave
				;;
			s*)
				echo; Msg3 "Holding '$file' as '$file'.save..."
				$DOIT mv "$file" "$file".save
				;;
			u*)
				echo; Msg3 "UnMarking '$file'..."
				newFileName=$(sed 's|.AutoDeleteNoSave||g' <<< ${workFiles[$siteId]})
				$DOIT mv "$file" /mnt/$share/web/$newFileName
				$DOIT rm /mnt/$share/web/$newFileName/.AutoDeleteNoSave
				;;
			r*)
				echo; Msg3 "Reseting 'marked' date for '$file'..."
				$DOIT touch "$file"/.clonedFrom*
				;;
			y*)
				if [[ $userName = 'dscudiero' ]]; then
					unset ans; Prompt ans "^Do you wish to save the workflow files" 'Yes No' 'Yes' ; ans=$(Lower "${ans:0:1}")
					[[ $ans == 'y' ]] && Msg3 "Saving workflow..." && Call saveWorkflow $processClient -p -all -suffix "beforeDelete-$backupSuffix" -nop #-quiet
				fi
				echo; Msg3 "Removing '$file' offline..."
				if [[ $DOIT == '' ]]; then
					mv -f "$file" "$file".BeingDeletedBy$(TitleCase "$myName")
					(nohup rm -rf "$file".BeingDeletedBy$(TitleCase "$myName") &> /dev/null) &
				else
					Msg3 "*** DOIT flag is off, skipping delete ***"
				fi
				;;
			w*)
				mv -f "$file" "$file--AutoDeleteWithSave"
				;;
			*)
				:
				;;
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
Here CD2; Dump verboseLevel

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
Hello
Here CD3; Dump verboseLevel
ParseArgsStd
dump 1 verboseLevel mark delete unMark client daemonMode

## Get the workflow files
GetDefaultsData 'copyWorkflow'
## Get the workflow files to check from the database
	unset requiredInstanceFiles optionalInstanceFiles requiredGlobalFiles optionalGlobalFiles ifThenDelete
	[[ $scriptData1 == '' ]] && Msg3 $T "'scriptData1 (requiredInstanceFiles)' is null, please check script configuration data"
	requiredInstanceFiles="$(cut -d':' -f2- <<< $scriptData1)"

	[[ $scriptData2 == '' ]] && Msg3 $T "'scriptData2 (optionalInstanceFiles)' is null, please check script configuration data"
	optionalInstanceFiles="$(cut -d':' -f2- <<< $scriptData2)"

	[[ $scriptData3 == '' ]] && Msg3 $T "'scriptData3 (requiredGlobalFiles)' is null, please check script configuration data"
	requiredGlobalFiles="$(cut -d':' -f2- <<< $scriptData3)"

	[[ $scriptData4 == '' ]] && Msg3 $T "'scriptData4 (optionalGlobalFiles)' is null, please check script configuration data"
	optionalGlobalFiles="$(cut -d':' -f2- <<< $scriptData4)"

	if [[ $scriptData5 ]]; then
		ifThenDelete="$(cut -d':' -f2- <<< $scriptData5)"
		deleteThenIf=$(tr ',' ';' <<< $deleteThenIf)
		deleteThenIf=$(tr ' ' ',' <<< $deleteThenIf)
		deleteThenIf=$(tr ';' ' ' <<< $deleteThenIf)
	fi

	dump 2 requiredInstanceFiles requiredGlobalFiles optionalInstanceFiles optionalGlobalFiles

#==================================================================================================
# Main
#==================================================================================================
## Get a list of directories
if [[ "$hostName" = 'build5' ]]; then share=dev9
elif [[ "$hostName" = 'build7' ]]; then share=dev7
elif [[ "$hostName" = 'mojave' ]]; then share=dev6
fi
validActions='Yes No Mark Unmark ResetDate Save'
[[ $userName == 'dscudiero' ]] && validActions="$validActions WorkflowSave"
searchStr="$userName"

if [[ $daemonMode == true ]]; then
	Msg3 "Starting $myName in daemon mode..."
	SetFileExpansion 'on'
	fileList="$(ls -d /mnt/dev*/web/*-*--AutoDelete* 2> /dev/null || true)"
	SetFileExpansion
	for file in $fileList; do
		file=$(tr -d ':' <<< "$file")
		if [[ $(Contains "$file" 'WithSave') == true ]]; then
			Msg3 "^Deleting '$(basename $file)' with workflow save"
			quiet=true
			Call saveWorkflow -daemon -siteFile "$file" -all -suffix "beforeDelete-$backupSuffix -quiet -nop"
			quiet=false
			Msg3 "^^workflow saved"
		else
			Msg3 "^Deleting '$(basename $file)'"
		fi
		fileRm="$(sed s"/AutoDeleteWithSave/BeingDeletedBy$(TitleCase $myName)/g" <<< "$file")"
		mv -f "$file" "$fileRm"
		(nohup rm -rf "$fileRm" &> /dev/null) &
	done
	Msg3 "Ending $myName in daemon mode..."
	Goodbye 0
	exit 0
fi


## if client was passed in then just delete that site, otherwise if it is 'daemon' then process autodeletes
[[ -n $client ]] && searchStr="$client-$searchStr"
while [ true == true ]; do
	unset site requestType
	GetSites "$searchStr"
	[[ ${#sites[@]} -eq 0 ]] && echo && Info "No files found for user: '$userName'" && break
	for site in ${sites[@]}; do
		[[ $site == '' ]] && Msg3 "No sites found or all sites have been processed" && Goodbye 0
		echo; Msg3  "You are asking to process site: '$site', are you sure?"
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
## 06-06-2017 @ 09.49.23 - (3.5.0)     - dscudiero - Added n-m notation, fixed comma notation
## 08-18-2017 @ 08.00.12 - (3.5.1)     - dscudiero - Filter out lilypadu-dscudiero
## 08-28-2017 @ 07.32.11 - (3.5.2)     - dscudiero - tweak messaging
## 08-28-2017 @ 07.35.42 - (3.5.3)     - dscudiero - check to see if siteIds string is not null before setting sites array
## 08-29-2017 @ 08.13.34 - (3.5.4)     - dscudiero - Turn quiet on before we call saveworkflow
## Tue Aug 29 08:15:20 CDT 2017 - dscudiero - -m sync
## 08-29-2017 @ 08.19.43 - (3.5.5)     - dscudiero - Wrap the call to saveworkflow in quiet=true quiet=false
## 08-29-2017 @ 08.23.43 - (3.5.6)     - dscudiero - Add some debug messages
## 09-01-2017 @ 09.34.21 - (3.5.7)     - dscudiero - Change the way we find the delete sites for daemon calls
## 09-01-2017 @ 10.10.32 - (3.5.8)     - dscudiero - Fix syntax problem
## 09-05-2017 @ 07.09.49 - (3.5.9)     - dscudiero - more debug stuff
## 09-05-2017 @ 16.25.44 - (3.5.10)    - dscudiero - Delete all dev sites that match pattern
## 09-06-2017 @ 07.19.45 - (3.5.11)    - dscudiero - Add debug statements
## 09-11-2017 @ 07.08.30 - (3.5.18)    - dscudiero - Add debug statements
## 09-12-2017 @ 07.15.31 - (3.5.20)    - dscudiero - Change the way files are deleted
## 09-13-2017 @ 06.59.23 - (3.5.21)    - dscudiero - remove debug statements
## 09-21-2017 @ 14.47.11 - (3.5.23)    - dscudiero - put the save workflow action back in
## 10-12-2017 @ 15.09.49 - (3.5.24)    - dscudiero - Updated includes list
## 10-12-2017 @ 15.10.51 - (3.5.25)    - dscudiero - fix dump statements
## 10-18-2017 @ 15.40.57 - (3.5.26)    - dscudiero - Change the way we determin if we shold run in daemon mode, add -daemon as a flag
## 10-20-2017 @ 13.20.21 - (3.5.27)    - dscudiero - Add PushPop to the include list
## 10-20-2017 @ 13.26.50 - (3.5.28)    - dscudiero - Add a default selection for the site to delete
## 10-20-2017 @ 15.49.14 - (3.5.30)    - dscudiero - Misc cleanup
## 10-31-2017 @ 08.10.14 - (3.5.41)    - dscudiero - If running in daemon mode the exit
## 10-31-2017 @ 08.15.29 - (3.5.43)    - dscudiero - Put a check in to make sure we do not run the GetSites function in batch mode
