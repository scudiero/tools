## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.11" # -- dscudiero -- 01/04/2017 @ 13:41:28.94
#===================================================================================================
# Edit a tcf value
# EditTcfValue <varName> <varValue> <editFile>
# 1) If already there, return true
# 2) If found commented out, uncomment & return
# 3) If found varible but value is different, edit & return
# 4) If not found in target
#	2) If found in skeleton then insert target line after the line found in the skeleton
#	1) Scan file in skeleton to find the line immediaterly above the target line in the skel file
#	3) If not found in the skeleton of the 'afterline' returned in 1) above is not found, insert at top
#
# returns 'true' for success, anything else is an error message
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function EditTcfValue {
	[[ $DOIT != '' ]] && echo true && return 0
	local varName=$1
	local varVal=$2
	local editFile=$3
	local skelDir=$skeletonRoot/release
	local findStr grepStr fromStr

	[[ $var == '' ]] && echo "($FUNCNAME) Required argument 'var' not passed to function" && return 0
	[[ $varVal == '' ]] && echo "($FUNCNAME) Required argument 'var' not passed to function" && return 0
	[[ $editFile == '' || ! -w $editFile ]] && echo "($FUNCNAME) Could not read/write editFile: '$editFile'" && return 0
	local toStr="${varName}:${varVal}"
	dump -3 -r
	dump -3 -l varName varVal editFile toStr

	## Check to see if string is already there
		findStr="${varName}"':'"${varVal}"
		dump -3 -l -t findStr
		grepStr="$(ProtectedCall "grep \"^$findStr\" $editFile")"
		[[ $grepStr != '' ]] && echo true && return 0

	BackupCourseleafFile $editFile
	## Look for a commented variable, if found uncomment and edit
		findStr="//$varName:"
		dump -3 -l -t findStr
		grepStr="$(ProtectedCall "grep \"^$findStr\" $editFile")"
		if [[ $grepStr != '' ]]; then
			fromStr="$grepStr"
			sed -i s"#^${fromStr}#${toStr}#" $editFile
			echo true
			return 0
		fi

	## Look for a existing variable, if found edit
		findStr="$varName:"
		dump -3 -l -t findStr
		grepStr="$(ProtectedCall "grep \"^$findStr\" $editFile")"
		if [[ $grepStr != '' ]]; then
			fromStr="$grepStr"
			sed -i s"#^${fromStr}#${toStr}#" $editFile
			echo true
			return 0
		fi

	## OK, variable is not found in target file, find location in skeleton and add,
	## if not found in skeleton then add to top of file
		local siteDir=$(ParseCourseleafFile $editFile | cut -d' ' -f2)
		local fileEnd=$(ParseCourseleafFile $editFile | cut -d' ' -f4)
		dump -3 -l -t siteDir fileEnd
		## Scan skeleton looking for line:
			unset foundLine afterLine insertMsg;
			while read -r line; do
				[[ "${line:0:${#varName}+1}" == "$varName:" || "${line:0:${#varName}+3}" == "//$varName:" ]] && foundLine=true && break
				afterLine="$line"
			done < "${skelDir}${fileEnd}"
			dump -3 -l -t foundLine afterLine
		## If we found the line then insert the new line after the line previous line in the skeleton file
			if [[ $foundLine == true ]]; then
				local verboseLevelSave=$verboseLevel
				verboseLevel=0; insertMsg=$(InsertLineInFile "$toStr" "$editFile" "$afterLine"); verboseLevel=$verboseLevelSave
				dump -3 -l -t insertMsg
				if [[ $insertMsg != true ]]; then
					## If insert could not find the insert after line then add to the top of the target file
					[[ $(Contains "$insertMsg" 'Could not locate target string/line' ) == true ]] && insertMsg=$(sed -i "1i$toStr" $editFile)
				fi
			else
				## If we did not fine the line in the skeletion then just insert at the top of the target file
				insertMsg=$(sed -i "1i$toStr" $editFile)
			fi
		## Error?
			[[ $insertMsg != '' && $insertMsg != true ]] && echo $insertMsg || echo true

	return 0
} #EditTcfValue
export -f  EditTcfValue

#===================================================================================================
# Checkin Log
#===================================================================================================

## Wed Jan  4 13:53:23 CST 2017 - dscudiero - General syncing of dev to prod
