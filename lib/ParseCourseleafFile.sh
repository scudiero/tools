## XO NOT AUTOVERSION
#===================================================================================================
version="2.0.2" # -- dscudiero -- 11/07/2016 @ 14:45:21.22
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

	local clientRoot fileEnd clientName env pcfCntr len
	local parseStart=4

	clientRoot="/${tokens[0]}/${tokens[1]}/${tokens[2]}/${tokens[3]}"
	if [[ ${tokens[1]:0:3} == 'dev' ]]; then
		clientName="${tokens[3]}"
		env='dev'
		len="-$userName"; len=${#len}
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
