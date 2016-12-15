## XO NOT AUTOVERSION
#===================================================================================================
version="2.0.5" # -- dscudiero -- 11/29/2016 @ 12:47:55.86
#===================================================================================================
# Display a selection menue of files in a directory that match a filter
# SelectFile <dir> <returnVariableName> <filter> <Prompt text>
# Files are displayed newest to oldest
# Sets the value of <returnVariableName> to the file selected
#===================================================================================================
# 03-8-16 - dgs - initial
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================
Import SelectMenuNew
function SelectFile {
	local dir=$1; shift
	local returnVarName=$1; shift
	local fileFilter="$1"; shift
	local menuPrompt="$*"
	[[ $menuPrompt == '' ]] && menuPrompt="\nPlease enter the (ordinal) number for an item above (or 'X' to quit) > "
	[[ ! -d $dir ]] && eval $returnVarName='' && return 0

	## Get a list of files, if none found return
		SetFileExpansion 'on'
		tmpDataFile="/tmp/$userName.$myName.$BASHPID.data"
		cd "$dir"
		ProtectedCall "ls -t $fileFilter 2> /dev/null | grep -v '~' > "$tmpDataFile""
		numLines=$(ProtectedCall "wc -l "$tmpDataFile"")
		numLines=$(echo $(ProtectedCall "wc -l "$tmpDataFile"") | cut -d' ' -f1)
	## If only one file found then just return it
		[[ $numLines -eq 0 ]] && rm -f "$tmpDataFile" && eval $returnVarName='' && SetFileExpansion && return 0
		if [[ $numLines -eq 1 ]]; then
			read -r selectResp < "$tmpDataFile"
			rm -f "$tmpDataFile"
			eval "$returnVarName=\"$selectResp\""
			SetFileExpansion
			return 0
		fi
	##Build menuList
		local menuList
		menuList+=("|File Name|File last mod date")
		while IFS=$'\n' read -r line; do
			file=$line
			#cdate=$(stat -c %y "$file" | cut -d'.' -f1 | awk 'BEGIN {FS=" "}{printf "%s at %s", $1,$2}')
			menuList+=("|$file|$(stat -c %y "$file" | cut -d'.' -f1 | awk 'BEGIN {FS=" "}{printf "%s at %s", $1,$2}')")
		done < "$tmpDataFile"
		[[ -f "$tmpDataFile" ]] && rm -f "$tmpDataFile"

	##Display menu
		local selectResp
		printf "$menuPrompt"
		SelectMenuNew 'menuList' 'selectResp' "\nEnter the $(ColorK '(ordinal)') number of the file you wish to use (or 'X' to quit) > "
		[[ $selectResp == '' ]] && SetFileExpansion && Goodbye 0 || selectResp=$(cut -d'|' -f1 <<< $selectResp)
		eval $returnVarName=\"$(echo "$selectResp" | cut -d"|" -f2)\"

	SetFileExpansion
	return 0
} # SelectFile
export -f SelectFile

#===================================================================================================
# Check-in Log
#===================================================================================================

