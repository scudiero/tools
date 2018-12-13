## XO NOT AUTOVERSION
#===================================================================================================
# version="1.0.0" # -- dscudiero -- Thu 12/13/2018 @ 16:03:40
#===================================================================================================
# Prompt user for a value
# Usage: varName promptText [validationList] [defaultValue]
# varName in the caller will be set to the response
#===================================================================================================
# Copyright 2018 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================F
PromptNew() {
	Import CallC MkTmpFile Msg
	local tmpFile=$(mkTmpFile)
	local variable=$1; shift||true
	local promptStr=$1; shift||true
	local validVals=$1; shift||true
	local defaultVals=$1; shift||true

	local promptArgs=" -prompt "

	[[ $verify == false ]] && { Warning "Requesting value for '$variable' but '-noPrompt' is active"; return 0; }

	[[ -n $promptStr ]] && promptArgs+="\"$promptStr\"" || { promptArgs+="\"Please specify the value to use for '$var'\""; validVals='*any*'; }
	[[ -n $validVals ]] && promptArgs+=" -valid \"$validVals\""
	[[ -n $defaultVals ]] && promptArgs+=" -default \"$defaultVals\""
	dump -2 promptStr validVals defaultVals promptArgs

	## Put data into the shell env pool to make it avaiable to the called pgm
	local exportVars="$variable verify client env envs srcEnv tgtEnv product products"
	local var
	for var in $exportVars; do
		[[ -n ${!var} ]] && export $var="${!var}"
	done
	## Call the program trapping file descriptor #3
	CallC prompt $variable $promptArgs 3> "$tmpFile"; rc=$?;
	## OK, source the tmpFile if it has data (set return data)
	[[ $(cut -d' ' -f1 <<< $(wc -l "$tmpFile")) -gt 0 ]] && { source <(cat "$tmpFile"); }
	rm -f "$tmpFile"
	return $rc
} ## PromptNew

export -f PromptNew

#===================================================================================================
# Check-in Log
#===================================================================================================