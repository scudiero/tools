## XO NOT AUTOVERSION
#===================================================================================================
version="2.0.4" # -- dscudiero -- 11/07/2016 @ 14:29:10.65
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

