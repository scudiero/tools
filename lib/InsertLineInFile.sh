## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.14" # -- dscudiero -- Thu 03/22/2018 @ 13:12:35.83
#===================================================================================================
# Insert a line onto a file, inserts BELOW the serachLine
# InsertLineInFile lineToInsert fileName searchLine
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function InsertLineInFile {
	[[ $DOIT != '' || $listOnly == true || $informationOnlyMode == true ]] && echo true && return 0
	local insertLine=$1; shift || true
	local editFile=$1; shift || true
	local searchLine=$1
	local lengthOfSearchLine=${#searchLine}
	#Here I1 > $stdout; echo 'insertLine  =>'$insertLine'<' >> $stdout; echo 'searchLine  =>'$searchLine'<' >> $stdout; echo >> $stdout
	dump -3 -l -t insertLine editFile searchLine lengthOfSearchLine

	# Read in file, scan for searchLine, once we find the searchLine in the file then we insert
	# the insertLine the below the search line
	local tmpFile=$(mkTmpFile $FUNCNAME)
	local line found=false
	while read -r line; do
		if [[ $found != true ]]; then
			if [[ ${line:0:$lengthOfSearchLine} == $searchLine ]]; then
				echo "${line}" >> $tmpFile
				echo "${insertLine}" >> $tmpFile
				found=true
				continue
			fi
		fi
		echo "${line}" >> $tmpFile
	done < "$editFile"

	if [[ $found == true ]]; then
		result=$(CopyFileWithCheck "$tmpFile" "$editFile" 'courseleaf')
		[[ $result == true || $result == 'same' ]] && echo true  || Msg "($FUNCNAME) $result"
	else
		Msg "($FUNCNAME) Could not locate the 'after' string/line \n\t'$searchLine'"
		#echo '*** NOT FOUND ***' >> $stdout
	fi

	[[ -f "$tmpFile" ]] && rm "$tmpFile"
	return 0
} #InsertLineInFile
export -f InsertLineInFile

#===================================================================================================
# Check-in Log
#===================================================================================================

## Wed Jan  4 13:53:52 CST 2017 - dscudiero - General syncing of dev to prod
## Thu Feb  9 08:06:30 CST 2017 - dscudiero - make sure we are using our own tmpFile
## Tue Mar 14 09:31:19 CDT 2017 - dscudiero - Tweak messaging
## 03-22-2018 @ 13:16:40 - 2.0.14 - dscudiero - Updated for Msg3/Msg, RunSql2/RunSql, ParseArgStd/ParseArgStd2
