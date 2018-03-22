## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.31" # -- dscudiero -- Thu 03/22/2018 @ 13:16:07.25
#===================================================================================================
# Insert a new line into the courseleaf console file
# EditCourseleafConsole <action> <targetFile> <string>
# <action> in {'insert','delete'}
# <string> is a full navlinks record or is the name of the console action, i.e. navlinks:...|<name>|...
#
# if action == 'delete' then the line will be commented out
# returns 'true' for success, anything else is an error message
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function EditCourseleafConsole {
	local action="$1"
	local tgtFile="$2"
	local string="$3"

	Import 'BackupCourseleafFile InsertLineInFile CopyFileWithCheck StringFunctions'

	[[ $action == '' ]] && echo "($FUNCNAME) Required argument 'action' not passed to function" && return 0
	[[ $tgtFile == '' || ! -w $tgtFile ]] && echo "($FUNCNAME) Could not read/write tgtFile: '$tgtFile'" && return 0
	[[ $string == '' ]] && echo "($FUNCNAME) Required argument 'string' not passed to function" && return 0
	local skelFile=$skeletonRoot/release/web/courseleaf/index.tcf
	local grepStr insertRec name navlinkName

	if [[ $(Contains "$string" 'navlinks:') == true ]]; then
		insertRec="$(Trim "$string")"
		name=$(echo $string | cut -d'|' -f2)
	else
		name="$string"
		grepStr="$(ProtectedCall "grep \"|$name|\" $skelFile")"
		if [[ $grepStr != '' ]]; then
			insertRec="$(Trim "$grepStr")"
			[[ ${insertRec:0:2} == '//' ]] && insertRec=${insertRec:2}
		else
			echo "($FUNCNAME) Could not locate a navlinks record with 'name' of '|$name|' in the skeleton"
			return 0
		fi
	fi
	dump -3 -l name insertRec
	BackupCourseleafFile $editFile

	## See if line is there already, if found & insert then quit, if found & delete then comment out
		grepStr="$(ProtectedCall "grep \"^$insertRec\" $editFile")"
		if [[ $grepStr != '' ]]; then
			[[ $(Lower ${action:0:1}) == 'd' ]] && sed -i s"#^$insertRec#//$insertRec#"g $editFile
			echo true
			return 0
		fi
		[[ $(Lower ${action:0:1}) == 'd' ]] && echo true && return 0

	## See if line is there but commented out
		grepStr="$(ProtectedCall "grep \"^//$insertRec\" $editFile")"
		if [[ $grepStr != '' ]]; then
			sed -i s"#^//$insertRec#$insertRec#"g $editFile
			Msg "^Uncommented line: $toStr..."
			changesMade=true
			echo true
			return 0
		fi

	## Scan skeleton looking for line:
		unset foundLine afterLine insertMsg
		while read -r line; do
			line=$(Trim "$line")
			[[ "$line" == "$insertRec" || "$line" == "//$insertRec" ]] && foundLine=true && break
			afterLine="$line"
		done < "$skelFile"
		dump -3 -l -t foundLine afterLine

	## Insert the line
		editFile="$tgtFile"
		if [[ $foundLine == true ]]; then
			local verboseLevelSave=$verboseLevel
			verboseLevel=0; insertMsg="$(InsertLineInFile "$insertRec" "$editFile" "$afterLine")"; verboseLevel=$verboseLevelSave
			dump -3 -l -t insertMsg
			[[ $insertMsg == true ]] && echo true || echo "$insertMsg"
			return 0
		fi
		## OK, we need to insert the line but cannot find the after record, so just add to the end of the group
			navlinkName=$(echo $insertRec | cut -d'|' -f1)
			afterLine="$(ProtectedCall "grep \"^$navlinkName\" $editFile | tail -1")"
			if [[ -z $afterLine ]]; then
				insertMsg="($FUNCNAME) Could not insert line:\n\t$insertRec\nCould not locate suitable insert location"
			else
				verboseLevel=0; insertMsg=$(InsertLineInFile "$insertRec" "$editFile" "$afterLine"); verboseLevel=$verboseLevelSave
				#[[ $insertMsg != true ]] && echo "($FUNCNAME) Could not insert line:\n\t$insertRec\nMessages are:\n\t$insertMsg" || echo true
			fi
			echo $insertMsg

	return 0
} #EditCourseleafConsole
export -f EditCourseleafConsole

#===================================================================================================
# Checkin Log
#===================================================================================================

## Wed Jan  4 13:53:21 CST 2017 - dscudiero - General syncing of dev to prod
## Tue Mar 14 09:31:40 CDT 2017 - dscudiero - Also look for commented lines in the skeleton
## 03-22-2018 @ 13:16:30 - 2.0.31 - dscudiero - Updated for Msg3/Msg, RunSql2/RunSql, ParseArgStd/ParseArgStd2
