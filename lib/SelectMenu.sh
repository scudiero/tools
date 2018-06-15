## XO NOT AUTOVERSION
#===================================================================================================
version="1.0.4" # -- dscudiero -- Fri 06/15/2018 @ 09:13:30
#===================================================================================================
# Display a selection menu
# Usage: [options] selectMeue menuItemsArrayName returnVariableName [promptText]
#	menuItemsArrayName 	= The name of the array containing the menu items 
#	returnVariableName 	= The name of the variable to return the data in
#	promptText			= The text to use when prompting the user to select an item
# Options:
#	-fast 				= Fast option, data contains the column widths (see below)
#	-Multiple 			= Allow multiple selections (e.g. 1,3,4,8)
#	-Range 				= Allow range selections (e.g. 1-5)
#	-OrdinalInData 		= The menu items passed in contains the ordinal data in column 1
# Menu Items Array	
#	'fast'		- First element is the delimiter (e.g. |)
#				- Second element is the header record (columns separated by the delimiter above)
#				- All other items are the menu items data  (columns separated by the delimiter above)
#
#	not 'fast'	- First element is the header record (columns separated by the delimiter above), the first character is the delimiter
#				- All other items are the menu items data  (columns separated by the delimiter above), the first character is the delimiter
#===================================================================================================
# Copyright 2018 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================
function SelectMenu {
	local menuListArrayName returnVarName menuPrompt allowMultiples=false allowRange=false screenWidth=80
	local i printStr tmpStr length validVals numCols=0 ordinalInData=false
    ## Parse arguments
        until [[ -z "$*" ]]; do
            case ${1:0:2} in
                -m ) allowMultiples=true ;;
                -r ) allowRange=true ;;
                -f ) fast=true ;;
                -o ) ordinalInData=true ;;
                *  )
                    [[ -z $menuListArrayName ]] && { menuListArrayName=$1[@]; menuListArray=("${!menuListArrayName}"); shift || true; continue; }
                    [[ -z $returnVarName ]] && { returnVarName="$1"; shift || true; continue; }
                    menuPrompt="$menuPrompt $1"
                    ;;
            esac
            shift || true
        done
        [[ -z $menuPrompt ]] && menuPrompt="\n${tabStr}Please enter the ordinal number $(ColorM "(Ordinal)") for an item above (or 'X' to quit) > "
		dump 2 menuListArrayName returnVarName menuPrompt allowMultiples allowRange

	[[ $TERM != '' && $TERM != 'dumb' ]] && { screenWidth=$(stty size </dev/tty); screenWidth="${screenWidth#* }"; }

	local validVals maxWidths=() i
	if [[ $fast == true ]]; then
		local delim="${menuListArray[0]}" validVals maxWidths=() i
		local widths="${menuListArray[1]}"
		local tmpStr="${widths//[^$delim]}" numCols
		let numCols=${#tmpStr}+1
		for ((i=0; i<$numCols; i++)); do
			local width="${widths%%|*}"; widths="${widths#*|}"
			let width=$width+2
			maxWidths+=($width)
		done
		local header="${menuListArray[2]}"
		startAt=2
	else
		local header="${menuListArray[0]}"
		local delim=${header:0:1}; header="${header:1}"
		local tmpStr="${header//[^$delim]}" numCols
		let numCols=${#tmpStr}+1
		[[ ${header%%${delim}*} == 'ord' || ${header%%${delim}*} == 'key' ]] && { ordinalInData=true; tmpStr="${header%%${delim}*}";} || tmpStr='Ord'
		[[ $menuPrompt == '' ]] && menuPrompt="\n${tabStr}Please enter the ordinal number $(ColorM "($tmpStr)") for an item above (or 'X' to quit) > "
		dump -3 header delim numCols ordinalInData menuPrompt
		## Loop through data and get the max widths of each column
		maxWidths=()
		for record in "${menuListArray[@]}"; do
			record="${record:1}"
			for (( i=1; i<=$numCols; i++ )); do
				local tmpStr="$(echo "$record" | cut -d$delim -f$i)"
				local maxWidth=${maxWidths[$i-1]}
				[[ ${#tmpStr} -gt $maxWidth ]] && let maxWidths[$i-1]=${#tmpStr}+2
			done
		done
		startAt=0
	fi

	## Display the menue
		declare -A menuItems
		local j local menuItem token ordinal tmpStr tmpStr2
		for ((i=$startAt; i<${#menuListArray[@]}; i++)); do
			tmpStr="${menuListArray[$i]}"
			[[ ${tmpStr:0:1} == $delim ]] && tmpStr="${tmpStr:1}"
			unset menuItem
			ordinal="${tmpStr%%|*}"; tmpStr="${tmpStr#*|}"
			validVals="${validVals},${ordinal}"
			if [[ $i -eq $startAt ]]; then ## i.e. the header record
				key="${ordinal}"
				ordinal="${ordinal}$(PadChar "$delim" ${maxWidths[0]})"
				menuItem="${ordinal:0:${maxWidths[0]}}"
				menuItem="$(ColorU "${menuItem:0:${#menuItem}-2}")  "
				menuItem="$(ColorB "$menuItem")"
			else
				key="${ordinal}"
				ordinal="(${ordinal})"
				ordinal="${ordinal}$(PadChar "$delim" ${maxWidths[0]})"
				menuItem="$(ColorM "${ordinal:0:${maxWidths[0]}}")"
			fi

			for ((j=1; j<$numCols; j++)); do
				menuItems["$key"]="${menuItems["$key"]}${tmpStr}"
				token="${tmpStr%%|*}"; tmpStr="${tmpStr#*|}"
				token="${token}$(PadChar "$delim" ${maxWidths[$j]})"
				tmpStr2="${token:0:${maxWidths[$j]}}"
				[[ $i -eq $startAt ]] && { tmpStr2="$(ColorU "${tmpStr2:0:${#tmpStr2}-2}")  "; tmpStr2="$(ColorB "$tmpStr2")"; }
				menuItem="${menuItem}${tmpStr2}"; 
				menuItem="${menuItem//$delim/ }"
			done
			Msg "^^$menuItem"
		done
		Msg 'P' "$menuPrompt"

	## Loop on response
		unset ans retVal
		while [[ $ans == '' ]]; do
			foundAll=false
			read ans; ans=$(Lower $ans)
			[[ ${ans:0:1} == 'x' || ${ans:0:1} == 'q' ]] && eval "$returnVarName=''" && return 0
			[[ ${ans:0:1} == 'r' ]] && eval $returnVarName='REFRESHLIST' && return 0
			if [[ -n $ans ]]; then
				## If ans contains a '-' and allow range is set then expand the range
				if [[ $(Contains "$ans" '-' ) == true && $allowRange == true ]]; then
					local front=${ans%%-*}; lowerIdx=${front: -1}
					local back=${ans##*-}; upperIdx=${back:0:1}
					for ((iix=$lowerIdx+1; iix<$upperIdx; iix++)); do
						front="$front,$iix"
					done
					ans="$front,$back"
				fi
				## Check responses
				foundAll=true
				for token in ${ans//,/ }; do
					if [[ ${menuItems["$token"]+abc} ]]; then
						token="${menuItems[$token]}"; token=${token%%$delim*} 
						[[ -z $retVal ]] && retVal="$token" || retVal="${retVal}${delim}${token}"
					else
						foundAll=false
					fi
				done
			fi

			if [[ $foundAll != true ]]; then
				[[ $ordinalInData == true ]] && Msg 'P' "${tabStr}$(ColorE *Error*) -- Invalid selection, '$ans', please try again > " || \
								Msg 'P' "${tabStr}$(ColorE *Error*) -- Invalid selection, '$ans', valid value in $validVals, please try again > "
				unset ans
			else
				## Return the data in the named variable
				eval $returnVarName=\"$(Trim $retVal)\"
				return 0
			fi
		done

} ## SelectMenu

export -f SelectMenu

#===================================================================================================
# Check-in Log
#===================================================================================================
## 05-31-2018 @ 09:22:22 - 1.0.0 - dscudiero - Re-factored to allow for faster menu draws
## 06-15-2018 @ 13:37:03 - 1.0.4 - dscudiero - Fix problem not setting the key if processing the banner record
