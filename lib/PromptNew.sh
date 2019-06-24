## XO NOT AUTOVERSION
#===================================================================================================
# version="1.0.2" # -- dscudiero -- Mon 06/24/2019 @ 10:02:20
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

	[[ $verify == false ]] && { Warning "($FUNCNAME) Requesting value for '$variable' but '-noPrompt' is active"; return 0; }

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
	CallC prompt $variable $promptArgs 3> "$tmpFile"; local rc=$?;
	## OK, source the tmpFile if it has data (set return data)
	local wcOut="$(wc -l "$tmpFile")"
	[[ ${wcOut%% *} -gt 0 ]] && { echo 1; source <(cat "$tmpFile"); }
	rm -f "$tmpFile"
	return $rc
} ## PromptNew

export -f PromptNew

#===================================================================================================
# Check-in Log
#===================================================================================================## 01-29-2019 @ 11:27:39 - 1.0.1 - dscudiero - Added function name to messages
## 06-24-2019 @ 10:02:51 - 1.0.2 - dscudiero -  Streamline the parsing of the output of wc -l
