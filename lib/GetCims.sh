## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.18" # -- dscudiero -- Thu 09/14/2017 @ 15:27:55.65
#===================================================================================================
# Get CIMs
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================
function GetCims {
	includes="Msg2 ProtectedCall"
	Import "$includes"

	local siteDir=$1 ; shift || true
	local verb prefix

	[[ ${#*} -eq 2 ]] && verb="$2" && prefix="$1"
	[[ ${#*} -eq 1 ]] && verb="use" && prefix="$1"

	local ans suffix validVals
	if [[ $allowMultiCims == true ]]; then
		suffix=', a for all cims'
		validVals='Yes No All'
	else
		unset suffix
		validVals='Yes No'
	fi
	dump -3 -t siteDir allowMultiCims suffix validVals

	[[ -d $siteDir/web ]] && cd $siteDir/web || Terminate "($FUNCNAME) Could not locate siteDir:\n^'$siteDir/web'"
	adminDirs=($(ProtectedCall "find -maxdepth 1 -type d -name '[a-z]*admin' -printf '%f\n' | sort"))

	[[ -d $siteDir/web/cim ]] && adminDirs+=('cim')
	for dir in ${adminDirs[@]}; do
		dump -3 -t -t dir
		[[ $(Contains "$dir" ".old") == true || $(Contains "$dir" ".bak") == true ]] && continue
		if [[ -f $siteDir/web/$dir/cimconfig.cfg ]]; then
			[[ $onlyCimsWithTestFile == true && ! -f $siteDir/web/$dir/wfTest.xml ]] && continue
			if [[ $verify == true && $allCims != true ]]; then
				unset ans
				Prompt ans "${prefix}Found CIM Instance '$(ColorK $dir)' in source instance,\n${prefix}\tdo you wish to $verb it? (y to use$suffix)? >"\
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
	return 0
} #GetCims
export -f GetCims

#===================================================================================================
# Check-in Log
#===================================================================================================

## Wed Jan  4 13:53:29 CST 2017 - dscudiero - General syncing of dev to prod
## Thu Jan  5 15:30:07 CST 2017 - dscudiero - modify debug messages
## Tue Mar 14 10:36:01 CDT 2017 - dscudiero - Add prefix argument to controle tabbing
## Thu Mar 16 08:13:26 CDT 2017 - dscudiero - add ability to pass in the verb to use in the message
## Thu Mar 16 09:38:34 CDT 2017 - dscudiero - Added a check to make sure the directory passed in exists
## 04-10-2017 @ 14.37.46 - ("2.0.14")  - dscudiero - tweak argument parsing
## 04-13-2017 @ 10.59.23 - ("2.0.16")  - dscudiero - s
## 04-13-2017 @ 11.43.55 - ("2.0.17")  - dscudiero - remove debug stuff
