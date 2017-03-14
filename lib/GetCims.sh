## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.7" # -- dscudiero -- 03/14/2017 @ 10:29:37.95
#===================================================================================================
# Get CIMs
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================
function GetCims {
	Msg2 $V3 "*** $FUNCNAME -- Starting ***"
	local siteDir=$1 ; shift || true
	local prefix="$1"; #[[ -z $prefix ]] && prefix="\t"
	local ans suffix validVals
	if [[ $allowMultiCims == true ]]; then
		suffix=', a for all cims'
		validVals='Yes No All'
	else
		unset suffix
		validVals='Yes No'
	fi
	dump -3 -t siteDir allowMultiCims suffix validVals

	cd $siteDir/web
	adminDirs=($(ProtectedCall "find -maxdepth 1 -type d -name '[a-z]*admin' -printf '%f\n' | sort"))

	[[ -d $siteDir/web/cim ]] && adminDirs+=('cim')
	for dir in ${adminDirs[@]}; do
		dump -3 -t -t dir
		[[ $(Contains "$dir" ".old") == true || $(Contains "$dir" ".bak") == true ]] && continue
		if [[ -f $siteDir/web/$dir/cimconfig.cfg ]]; then
			[[ $onlyCimsWithTestFile == true && ! -f $siteDir/web/$dir/wfTest.xml ]] && continue
			if [[ $verify == true && $allCims != true ]]; then
				unset ans
				Prompt ans "${prefix}Found CIM Instance '$(ColorK $dir)' in source instance,\n${prefix}\tdo you wish to use it? (y to use$suffix)? >"\
			 			"$validVals"; ans=$(Lower ${ans:0:1});
				[[ $ans == 'a' ]] && cims=(${adminDirs[@]}) && break
				if [[ $ans == 'y' ]]; then
					cims+=($dir);
					[[ $allowMultiCims != true ]] && break
				fi
			else
				cims+=($dir)
			fi
		fi
	done
	if [[ $cimStr == '' ]]; then
		cimStr=$(printf -- "%s, " "${cims[@]}")
		cimStr=${cimStr:0:${#cimStr}-2}
	fi
	#[[ $products == '' ]] && products='cim' || products="$products,cim"
	[[ $verbose == true && $verboseLevel -ge 2 ]] && dump cimStr

	Msg2 $V3 "*** $FUNCNAME -- Completed ***"
	return 0
} #GetCims
export -f GetCims

#===================================================================================================
# Check-in Log
#===================================================================================================

## Wed Jan  4 13:53:29 CST 2017 - dscudiero - General syncing of dev to prod
## Thu Jan  5 15:30:07 CST 2017 - dscudiero - modify debug messages
## Tue Mar 14 10:36:01 CDT 2017 - dscudiero - Add prefix argument to controle tabbing
