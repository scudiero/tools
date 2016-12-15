## XO NOT AUTOVERSION
#===================================================================================================
version="2.0.0" # -- dscudiero -- 11/07/2016 @ 14:41:22.65
#===================================================================================================
# Write log messages to the end of a file
# args: "logFileName" <prefix> <logline>
# If logline is not passed then a preformatted string will be written out:
# 	$beginCommentChar $(date) by $userName, client: '$client', Env: '$env'$endCommentChar
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function LogInFile {
	[[ $DOIT != '' || $listOnly == true || $informationOnlyMode == true ]] && return 0
	local file=$1; shift
	local beginCommentChar='##'
	[[ $1 != '' ]] && local beginCommentChar="$1" && shift
	[[ $* != '' ]] && logString="$*" || unset logString
	local endCommentChar
	[[ $beginCommentChar == '/*' ]] && endCommentChar=' */' || unset endCommentChar
	#echo '$file = >'$file'<'; echo '$beginCommentChar == >'$beginCommentChar'<'; echo '$logString == >'$logString'<'

	## Do we already have a comment block at end if file, if not add
		unset grepStr
		grepStr=$(ProtectedCall "grep \"$beginCommentChar Change/Commit/Patch History\" $file")
		if [[ $grepStr == '' ]]; then
			echo >> $file
			echo "${beginCommentChar}$(head -c 100 < /dev/zero | tr '\0' "=")${endCommentChar}" >> $file
			echo "${beginCommentChar} Change/Commit/Patch History$endCommentChar" >> $file
			echo "${beginCommentChar}$(head -c 100 < /dev/zero | tr '\0' "=")${endCommentChar}" >> $file
		fi
	## Add log record or passed string
		if [[ $logString == '' ]]; then
			echo "${beginCommentChar} $(date) updated by $userName via ${myName}${endCommentChar}" >> $file
		else
			echo -e "${beginCommentChar}\t\t$logString" >> $file
		fi

	return 0
} #LogInFile
export -f LogInFile

#===================================================================================================
# Check-in Log
#===================================================================================================
