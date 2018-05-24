## XO NOT AUTOVERSION
#===================================================================================================
# version="2.1.2" # -- dscudiero -- Thu 05/24/2018 @  9:24:51.78
#===================================================================================================
# Display a selection menu
# SelectMenuNew <MenueItemsArrayName> <returnVariableName> <Prompt text>
# First line of the array is the header, first char of the header is the data delimiter
#
# If first 2 chars of the returnVariableName is 'ID' then will return the ordinal number of the
# response, otherwise the input line responding to the ordinal selected will be returned
#===================================================================================================
# 03-8-16 - dgs - initial
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================
function SelectMenuNew {
	local menuListArrayName returnVarName menuPrompt allowMultiples=false allowRange=false screenWidth=80
	local i printStr tmpStr length validVals numCols=0 ordinalInData=false
    ## Parse arguments
        until [[ -z "$*" ]]; do
            case ${1:0:2} in
                -m ) allowMultiples=true ;;
                -r ) allowRange=true ;;
                *  )
                    [[ -z $menuListArrayName ]] && { menuListArrayName=$1[@]; menuListArray=("${!menuListArrayName}"); shift || true; continue; }
                    [[ -z $returnVarName ]] && { returnVarName="$1"; shift || true; continue; }
                    menuPrompt="$menuPrompt $1"
                    ;;
            esac
            shift || true
        done
		dump 2 menuListArrayName returnVarName menuPrompt allowMultiples allowRange

	[[ $TERM != '' && $TERM != 'dumb' ]] && { screenWidth=$(stty size </dev/tty); screenWidth="${screenWidth#* }"; }

	## Parse header
		local header="${menuListArray[0]}"
		local delim=${header:0:1}
		for (( i=0; i<=${#header}; i++ )); do
			[[ ${header:$i:1} == $delim ]] && let numCols=numCols+1;
		done
		tmpStr="$(Lower "$(cut -d"$delim" -f2 <<< "$header")")"
		[[ ${tmpStr:0:3} == 'ord' || ${tmpStr:0:3} == 'key' ]] && ordinalInData=true && tmpStr="$(cut -d"$delim" -f2 <<< "$header")" || tmpStr='Ord'
		[[ $menuPrompt == '' ]] && menuPrompt="\n${tabStr}Please enter the ordinal number $(ColorM "($tmpStr)") for an item above (or 'X' to quit) > "
		dump -3 header delim numCols ordinalInData menuPrompt

	## Loop through data and get the max widths of each column
		maxWidths=()
		for record in "${menuListArray[@]}"; do
			record="${record:1}"
			for (( i=1; i<=$numCols; i++ )); do
				local tmpStr="$(echo "$record" | cut -d$delim -f$i)"
				maxWidth=${maxWidths[$i]}
				[[ ${#tmpStr} -gt $maxWidth ]] && maxWidths[$i]=${#tmpStr}
			done
		done
		if [[ $verboseLevel -ge 3 ]]; then for (( i=1; i<= $numCols; i++ )); do echo '${maxWidths[$i]} = >'${maxWidths[$i]}'<'; done fi

	## Loop through data and build menu lines
		declare -A menuItems
		local key menuItemsCntr=-1 menuItemsKeys=()
		for record in "${menuListArray[@]}"; do
			record="${record:1}"
			unset menuItem
			for (( i=1; i<=$numCols; i++ )); do
				local tmpStr="$(echo "$record" | cut -d$delim -f$i)"$(PadChar ' ' $screenWidth)
				maxWidth=${maxWidths[$i]}
				menuItem=$menuItem${tmpStr:0:$maxWidth+1}
			done

			if [[ $ordinalInData == true ]]; then
				key="$(cut -d' ' -f1 <<< $menuItem)"
				menuItem="$(Trim "$(cut -d' ' -f2- <<< "$menuItem")")"
			else
				((menuItemsCntr++)) || true
				key=$menuItemsCntr
			fi
			menuItems[$key]="$menuItem"
			menuItemsKeys+=($key)
			[[ $(IsNumeric "$key") == true ]] && validVals="$validVals,$key"
		done
		# for i in ${menuItemsKeys[@]}; do
		# 	echo -e "\tkey: '$i', value: '${menuItems[$i]}'";
		# done
		# Pause

	## Display menu
		tmpStr=${#menuItemsKeys[@]}
		maxIdxWidth=${#tmpStr}
		## Print header
			unset printStr
			if [[ $ordinalInData == false ]]; then
				printStr="Ord$(PadChar ' ' 10)"
				let length=$maxIdxWidth+2
				printStr=${printStr:0:$length+1}
			else
				[[ ${maxWidths[1]} -lt $maxIdxWidth+2 ]] && let length=$maxIdxWidth+2 || let length=${maxWidths[1]}
			fi
			key="${menuItemsKeys[0]}"
			printStr="${printStr}${menuItems[$key]}"
			[[ $ordinalInData == true ]] && printStr="${key} ${printStr:0:$screenWidth}" || printStr="${printStr:0:$screenWidth}"
			echo -e "\t$(ColorM "$printStr")"

		## Print 'data' rows
			menuItemsKeys=("${menuItemsKeys[@]:1}") ## pop off the first row which contains the header
			for i in ${menuItemsKeys[@]}; do
				menuItem="${menuItems[$i]}"
				tmpStr="(${i})$(PadChar ' ' 10)"
				printStr="$(ColorM "${tmpStr:0:$length}") $menuItem"
				printStr="${printStr:0:$screenWidth}"
				echo -e "\t$printStr"
			done;

		## Print prompt
		echo -ne "$menuPrompt"
		[[ $ordinalInData != true ]] && validVals="{1-$i}" || unset validVals

	## Loop on response
		unset ans retVal invalidVals
		while [[ $ans == '' ]]; do
			read ans; ans=$(Lower $ans)
			[[ ${ans:0:1} == 'x' || ${ans:0:1} == 'q' ]] && eval $returnVarName='' && return 0
			[[ ${ans:0:1} == 'r' ]] && eval $returnVarName='REFRESHLIST' && return 0

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
					token="$(Trim "${menuItems[$token]}")"; 
					retVal="$retVal|$token"
				else
					foundAll=false
				fi
			done

			if [[ $foundAll != true ]]; then
				printf "${tabStr}$(ColorE *Error*) -- Invalid selection, '$ans', valid value in $validVals, please try again > "
				unset ans invalidVals
			fi
		done
		## Return the data in the named variable
		[[ ${retVal:0:1} == '|' ]] && retVal="${retVal:1}"
		eval $returnVarName=\"$(Trim $retVal)\"
} #SelectMenuNew

#===================================================================================================
# Check-in Log
#===================================================================================================

## Wed Jan  4 13:54:23 CST 2017 - dscudiero - General syncing of dev to prod
## Thu Feb 16 06:59:22 CST 2017 - dscudiero - Added an option to pull the ordinals from the input data
## 04-17-2017 @ 10.31.12 - ("2.0.15")  - dscudiero - fix issue when returning data for xxxxId variables
## 04-25-2017 @ 14.40.09 - ("2.0.16")  - dscudiero - Remove debug stuff
## 04-26-2018 @ 08:33:54 - 2.0.28 - dscudiero - Remove debug statement
## 05-14-2018 @ 08:29:56 - 2.1.1 - dscudiero - Add ability to specify ranges
## 05-24-2018 @ 09:26:44 - 2.1.2 - dscudiero - Fix spelling
