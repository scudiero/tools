#!/bin/bash
# XO NOT AUTOVERSION
#==================================================================================================
version=3.4.61 # -- dscudiero -- 12/16/2016 @ 15:21:53.78
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

	#==================================================================================================
	# Get site 
	#==================================================================================================
	function GetSite {
		local searchStr="$1"
		local file tempStr printedSep sepLen sep i siteId loop
		local maxLen=0

		until [[ $loop == false ]]; do
			## Get the list of files
			unset validSiteIds workFiles filesStr1 filesStr2
			filesStr1="$(ProtectedCall "ls /mnt/$share/web" | ProtectedCall "grep -v .BeingDeleted" | ProtectedCall "grep $searchStr" | ProtectedCall "grep -v .AutoDelete")"
			filesStr2="$(ProtectedCall "ls /mnt/$share/web" | ProtectedCall "grep -v .BeingDeleted" | ProtectedCall "grep $searchStr" | ProtectedCall "grep .AutoDelete")"
			filesStr3="$(ProtectedCall "ls /mnt/$share/web" | ProtectedCall "grep $searchStr" | ProtectedCall "grep .BeingDeleted")"
			workFiles=($filesStr1 $filesStr2 $filesStr3)

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
				printedSep1=false
				printedSep2=false
				for ((i = 0 ; i < ${#workFiles[@]} ; i++)); do
					timeStamp='Unknown'
					for env in dev test next curr qa; do
						file=/mnt/$share/web/${workFiles[$i]}/.clonedFrom-$env
						#dump env file
						[[ -f $file ]] && timeStamp=$(stat -c %z $file | awk 'BEGIN {FS=" "}{printf "%s", $1}' | awk 'BEGIN {FS="-"}{printf "%s-%s-%s", $2,$3,$1}') && break
					done
					tempStr=${workFiles[$i]}$dots; tempStr=${tempStr:0:$maxLen}
					[[ $(Contains "$tempStr" ".AutoDelete") == true && $printedSep1 == false ]] && printf "$sep" && printedSep1=true
					[[ $(Contains "$tempStr" ".BeingDeleted") == true && $printedSep2 == false ]] && printf "$sep" && printedSep2=true
				  	printf "\t%2s %s (Created: %s) \n" "$i" "$tempStr" "$timeStamp"
				  	[[ "$validSiteIds" = '' ]] &&validSiteIds="$i" || validSiteIds="$validSiteIds $i"
				done
				unset siteId
				Prompt siteId "\nPlease enter the ordinal number(s) of the site you wish to Process, \nor 'X' to quit" #"$validSiteIds"
				[[ $(Lower $siteId) == 'r' ]] && loop=true || loop=false
			fi ## [[ ${#workFiles[@]} -gt 0 ]]
		done


		## Build the sites array
		unset sites
		for i in $(tr ',' ' ' <<< $siteId); do
			sites+=("${workFiles[$i]}")
		done
		return 0
	} #GetSite

	#==================================================================================================
	# Process request
	#==================================================================================================
	function CheckChanged {

		dump -2 requiredInstanceFiles requiredGlobalFiles optionalInstanceFiles optionalGlobalFiles

	} #CheckChanged

	#==================================================================================================
	# Process request
	#==================================================================================================
	function ProcessRequest {
		local type="$1"
		local file="/mnt/$share/web/$2"
		local client=$(cut -d'-' -f1 <<< $2)
		dump -1 -p client requestType file

		case "$requestType" in
			m*)
				Msg2; Msg2 "Marking '$file' for automatic deletion in $deleteLimitDays days..."
				$DOIT mv "$file" "$file".AutoDelete
				$DOIT touch "$file".AutoDelete/.AutoDelete
				;;
			s*)
				Msg2; Msg2 "Holding '$file' as '$file'.save..."
				$DOIT mv "$file" "$file".save
				;;
			u*)
				Msg2; Msg2 "UnMarking '$file'..."
				newFileName=$(sed 's|.AutoDelete||g' <<< ${workFiles[$siteId]})
				$DOIT mv "$file" /mnt/$share/web/$newFileName
				$DOIT rm  /mnt/$share/web/$newFileName/.AutoDelete
				;;
			r*)
				Msg2; Msg2 "Reseting 'marked' date for '$file'..."
				$DOIT touch "$file"/.clonedFrom*
				;;
			y*)
				Msg2;
				if [[ $userName = 'dscudiero' ]]; then
					## Get the time date for the site
# 					createTimeStamp=$(stat -c %Y $file/.clonedFrom*)
# dump createTimeStamp
					## Check to see if workflow files have changed
# 					for wfFile in "$requiredInstanceFiles $optionalInstanceFiles"; do
# 						wfFileTimeStamp=$(stat -c %Y $file/.clonedFrom*)
# 					done
# Quit
				 	Msg2 "Saving workflow..."
				 	Call saveWorkflow $client -p -all -suffix "beforeDelete-$fileSuffix" -nop -quiet
				fi
				Msg2 "Removing '$file' offline..."
				if [[ $DOIT == '' ]]; then
					mv -f "$file" "$file".BeingDeletedBy$(TitleCase "$myName")
					(nohup rm -rf "$file".BeingDeletedBy$(TitleCase "$myName") &> /dev/null) &
				else
					Msg2 "*** DOIT flag is off, skipping delete ***"
				fi
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
RunSql 'mysql' $sqlStmt
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
searchStr="$userName"
[[ $client != '' ]] && searchStr="$client-$searchStr"
while [ true == true ]; do
	unset site requestType
	GetSite "$searchStr"
	[[ ${#sites[@]} -eq 0 ]] && break
	for site in ${sites[@]}; do
		[[ $site == '' ]] && Msg2 "No sites found or all sites have been processed" && Goodbye 0
		Msg2; Msg2  "You are asking to remove site: '$site', are you sure?"
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
