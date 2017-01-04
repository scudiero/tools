## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.5" # -- dscudiero -- 01/04/2017 @ 13:37:32.76
#===================================================================================================
# Recursively modify attrributes for each directory in a path
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function CmdAlongPath {
	declare cmd="$1"
	declare root="$2"
	declare dir="$3"
	if [[ ${dir:0:1} != '/' ]]; then dir=/$dir; fi
	IFS='/' read -ra dirs <<< "$dir"
	path=$root
	for dir in "${dirs[@]:1}"; do
		path=$path'/'$dir
 		$cmd $path > /dev/null 2>&1
	done

	return 0
} #CmdAlongPath
export -f CmdAlongPath

#===================================================================================================
# Checkin Log
#===================================================================================================

## Wed Jan  4 13:53:04 CST 2017 - dscudiero - General syncing of dev to prod
