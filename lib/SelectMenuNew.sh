## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.5" # -- dscudiero -- 01/04/2017 @ 13:48:08.24
#===================================================================================================
# Display a selection menue
# SelectMenuNew <MenueItemsArrayName> <returnVariableName> <Prompt text>
# First line of the array is the header, first char of the header is the data delimiter
#
# If lst 2 chars of the returnVariableName is 'ID' then will return the ordinal number of the
# response, otherwise the input line responding to the ordinal selected will be returned
#===================================================================================================
# 03-8-16 - dgs - initial
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function SelectMenuNew {
	local menuListArrayName=$1[@]
	local menuListArray=("${!menuListArrayName}"); shift
	local returnVarName=$1; shift
	local menuPrompt=$*
	[[ $menuPrompt == '' ]] && menuPrompt="\n${tabStr}Please enter the ordinal number $(ColorM "(ord)") for an item above (or 'X' to quit) > "
	local screenWidth=80
	[[ $TERM != '' && $TERM != 'dumb' ]] && screenWidth=$(stty size </dev/tty | cut -d' ' -f2)
	#let screenWidth=$screenWidth+12
	local printStr

	## Parse header
		local numCols=0
		local char1
		header="${menuListArray[0]}"
		delim=${header:0:1}
		for (( i=0; i<=${#header}; i++ )); do
			[[ ${header:$i:1} == $delim ]] && let numCols=numCols+1;
		done
		dump -3 header delim numCols

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
		menuItems=()
		for record in "${menuListArray[@]}"; do
			record="${record:1}"
			unset menuItem
			for (( i=1; i<=$numCols; i++ )); do
				local tmpStr="$(echo "$record" | cut -d$delim -f$i)"$(PadChar ' ' 200)
				maxWidth=${maxWidths[$i]}
				menuItem=$menuItem${tmpStr:0:$maxWidth+3}
			done
			dump -3 menuItem
			menuItems+=("$menuItem")
		done

	## Display menue
		numMenuItems=${#menuItems[@]}
		maxIdxWidth=${#numMenuItems}

		## Print header
			ord="ord$(PadChar ' ' 10)"
			ord=${ord:0:$maxIdxWidth+2}
			printStr="${tabStr}${ord} ${menuItems[0]}"
			printStr="${printStr:0:$screenWidth}"
			echo -e "$(ColorM "$printStr")"
		## Print 'data' rows
			for (( i=1; i<=$(( $numMenuItems-1 )); i++ )); do
				printi=$(printf "%$maxIdxWidth"s "$i")
				#printStr="    $(ColorM "($printi)") ${menuItems[i]}"
				printStr="${tabStr}$(ColorM "($printi)") ${menuItems[i]}"
				printStr="${printStr:0:$screenWidth}"
				echo -e "$printStr"
			done
		## Print prompt
		echo -ne "$menuPrompt"
		((i--))
		#let i=$i-1
		validVals="{1-$i}"

	## Loop on response
		unset ans
		while [[ $ans == '' ]]; do
			read ans; ans=$(Lower $ans)
			[[ ${ans:0:1} == 'x' || ${ans:0:1} == 'q' ]] && eval $returnVarName='' && return 0
			[[ ${ans:0:1} == 'r' ]] && eval $returnVarName='REFRESHLIST' && return 0
			if [[ $ans != '' && $ans -ge 0 && $ans -lt ${#menuItems[@]} && $(IsNumeric $ans) == true ]]; then
				eval $returnVarName=$(echo "${menuItems[$ans]}" | cut -d" " -f1)

				if [[ $(Lower ${returnVarName:(-2)}) == 'id' ]]; then
					eval $returnVarName=\"$ans\"
				else
					#echo '${menuListArray[$ans]} = >'${menuListArray[$ans]}'<'
					local tempStr=$(echo ${menuListArray[$ans]} | cut -d"$delim" -f2-)
					eval $returnVarName=\"$tempStr\"
				fi

				[[ $logFile != '' ]] && Msg2 "\n^$FUNCNAME: User selected '$ans', '${menuListArray[$ans]}'" >> $logFile
				return 0
			else
				printf "${tabStr}$(ColorE *Error*) -- Invalid selection, '$ans', valid value in $validVals, please try again > "
				unset ans
			fi
		done
} #SelectMenuNew
export -f SelectMenuNew

#===================================================================================================
# Check-in Log
#===================================================================================================

## Wed Jan  4 13:54:23 CST 2017 - dscudiero - General syncing of dev to prod
