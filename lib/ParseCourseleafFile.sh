## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.4" # -- dscudiero -- Thu 05/04/2017 @ 12:18:58.09
#===================================================================================================
# Parse a courseleaf client file returns <clientName> <clientEnv> <clientRoot> <fileEnd>
# clientRoot is everything up to the 'web' directory.  e.g. '/mnt/rainier/uww/next' or
# '/mnt/dev6/web/uww-dscudiero'
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================
function ParseCourseleafFile {
	local file="$1"
	[[ $file == '' ]] && file="$(pwd)"
	file=${file:1}
	local tokens=($(tr '/' ' ' <<< $file))
	local clientRoot fileEnd clientName env pcfCntr len str
	local parseStart=4

	clientRoot="/${tokens[0]}/${tokens[1]}/${tokens[2]}/${tokens[3]}"
	if [[ ${tokens[1]:0:3} == 'dev' ]]; then
		clientName="$(cut -d'.' -f1 <<< ${tokens[3]})"
		env='dev'
		str="-$userName"; len=${#str}
		[[ ${clientName:(-$len)} == "-$userName" ]] && env='pvt'
	else
		clientName="${tokens[2]}"
		env="${tokens[3]}"
	fi

	for ((pcfCntr = $parseStart ; pcfCntr < ${#tokens[@]} ; pcfCntr++)); do
	  	token="${tokens[$pcfCntr]}"
		fileEnd="${fileEnd}/${token}"
	done

	echo "$clientName" "$env" "$clientRoot" "$fileEnd"

	return 0
} #ParseCourseleafFile
export -f ParseCourseleafFile

#===================================================================================================
# Check-in Log
#===================================================================================================
## Wed Jan  4 13:54:05 CST 2017 - dscudiero - General syncing of dev to prod
## 05-04-2017 @ 12.19.57 - ("2.0.4")   - dscudiero - General syncing of dev to prod
