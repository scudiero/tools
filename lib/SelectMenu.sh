## XO NOT AUTOVERSION
#===================================================================================================
version="2.0.4" # -- dscudiero -- 11/07/2016 @ 14:51:58.85
#===================================================================================================
# Display a selection menue
# SelectMenu <MenueItemsArrayName> <returnVariableName> <Prompt text>
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function SelectMenu {

	local menuListArrayName=$1[@]
	local menuListArray=("${!menuListArrayName}")
	PushSettings "$FUNCNAME"
	shift
	local returnVarName=$1
	shift
	PopSettings
	local menuPrompt=$*
	[[ $menuPrompt == '' ]] && menuPrompt="\nPlease enter the (ordinal) number for an item above (or 'X' to quit) > "

	## Write out screen
		numMenuItems=${#menuListArray[@]}
		maxIdxWidth=${#numMenuItems}
		local i
		for (( i=0; i<=$(( $numMenuItems-1 )); i++ )); do
			printi=$(printf "%$maxIdxWidth"s "$i")
			printf "\t($printi) ${menuListArray[i]}\n"
		done

		printf "$menuPrompt"
		unset ans
		while [[ $ans == '' ]]; do
			read ans; ans=$(Lower $ans)
			#dump ans
			#echo '${#menuListArray[@]} = >'${#menuListArray[@]}'<'
			[[ ${ans:0:1} == 'x' || ${ans:0:1} == 'q' ]] && eval $returnVarName='' && return 0
			#echo '${#menuListArray[@]} = >'${#menuListArray[@]}'<'
			#echo '$(IsNumeric $ans)  = >'$(IsNumeric $ans)'<'
			if [[ $ans != '' && $ans -ge 0 && $ans -lt ${#menuListArray[@]} && $(IsNumeric $ans) == true ]]; then
				#eval $returnVarName=$(echo "${menuListArray[$ans]}" | cut -d" " -f1)
				#dump returnVarName
				#echo '${menuListArray[$ans]} = >'${menuListArray[$ans]}'<'
				[[ ${returnVarName:(-2)} == 'Id' ]] && eval $returnVarName=\"$ans\"|| eval $returnVarName=\"${menuListArray[$ans]}\"
				#eval $returnVarName=\"${menuListArray[$ans]}\"
				return 0
			else
				printf "*Error* -- Invalid selection ('$ans'), please try again > "
				unset ans
			fi
		done
		[[ $logFile != '' ]] && Msg2 "\n^$FUNCNAME: User selected '$ans', ${menuListArray[i]} " >> $logFile

	return 0
} #SelectMenu
export -f SelectMenu

#===================================================================================================
# Check-in Log
#===================================================================================================

