## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.62" # -- dscudiero -- Tue 04/09/2019 @ 09:42:13
#===================================================================================================
# Get CIMs
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================
function GetCims {
	myIncludes="ProtectedCall PushPop"
	Import "$standardInteractiveIncludes $myIncludes"

	local siteDir jj verb prefix multiCims onlyWithTestFile getAllCims
	[[ -n $allowMultiCims ]] && multiCims=$allowMultiCims
	[[ -n $onlyCimsWithTestFile ]] && onlyWithTestFile=$onlyCimsWithTestFile
	[[ -n $allCims ]] && getAllCims=$allCims

	## Parse defaults
		while [[ $# -gt 0 ]]; do
		    [[ $1 =~ ^-all|--getAllCims$ ]] && { getAllCims=true; shift 1; continue; }
		    [[ $1 =~ ^-multi|--multipleCims$ ]] && { multiCims=true; shift 1; continue; }
		    [[ $1 =~ ^-o|--onlyWithTestFile$ ]] && { onlyWithTestFile=true; shift 1; continue; }
		    [[ $1 =~ ^-v|--verb$ ]] && { verb="$2"; shift 2; continue; }
		    [[ $1 =~ ^-p|--prefix$ ]] && { prefix="$2"; shift 2; continue; }
		    [[ -z $siteDir ]] && siteDir=$1
		    shift 1 || true
		done

	[[ ${#*} -eq 2 ]] && verb="$2" && prefix="$1"
	[[ ${#*} -eq 1 ]] && verb="use" && prefix="$1"

	local ans suffix validVals
	if [[ $allowMultiCims == true ]]; then
		suffix=', a for all cims'
		validVals='Yes No Other All'
	else
		unset suffix
		validVals='Yes No Other'
	fi
	dump -3 -t siteDir allowMultiCims suffix validVals

	[[ ! -d $siteDir/web ]] && { unset cims cimStr; return 0; }
	Pushd "$siteDir/web"
	# cimDirsStr=$(ProtectedCall "find -mindepth 2 -maxdepth 2 -type f -name cimconfig.cfg -printf '%h\n' | sort")

	SetFileExpansion 'on'
	cimDirsStr="$(ls -d */ | grep "admin")"; cimDirsStr="${cimDirsStr//[$'\t\r\n']}"; cimDirsStr="${cimDirsStr//\// }"
	SetFileExpansion
	unset cimDirs
	[[ $cimDirsStr != '' ]] && readarray -t cimDirs <<< "${cimDirsStr}"
	#echo;echo "Array '$cimDirs':"; for ((jj=0; jj<${#cimDirs[@]}; jj++)); do echo -e "\t cimDirs[$jj] = >${cimDirs[$jj]}<"; done
	# [[ -f ./cim/cimconfig.cfg ]] && cimDirs+=('./cim')
	[[ -f ./cim/cimconfig.cfg ]] && cimDirsStr+='cim'
	Popd

	# for ((jj=0; jj<${#cimDirs[@]}; jj++)); do
	# 	dir="${cimDirs[$jj]}"; #dir=${dir:2}
	for dir in $cimDirsStr; do
		[[ $dir == "admin" || $(Contains "$dir" ".old") == true || $(Contains "$dir" ".bak") == true \
			|| $(Contains "$dir" " - Copy") == true  || $(Contains "$dir" "_") == true ]] && continue
		dump 3 -t dir
		[[ ! -f $siteDir/web/$dir/cimconfig.cfg ]] && continue	
		[[ $onlyWithTestFile == true && ! -f $siteDir/web/$dir/wfTest.xml ]] && continue
		if [[ $verify == true && $getAllCims != true ]]; then
			unset ans
			Prompt ans "${prefix}Found CIM Instance '$(ColorK $dir)' in source instance,\n${prefix}\tdo you wish to $verb it? (y to use$suffix)? >"\
		 			"$validVals"; ans=${ans,,[a-z]} ans=${ans:0:1};
			[[ $ans == 'a' ]] && { cims=(${cimDirs[@]}); break; }
			if [[ $ans == 'y' ]]; then
				cims+=($dir);
				[[ $multiCims != true ]] && break
			elif [[ $ans == 'o' ]]; then
				local dir
				while [[ -z $dir ]]; do
					Prompt dir "${prefix}Please specifiy the CIM instance directory (relative to '$siteDir/web')? >" '*dir'
					[[ $dir == 'x' || $dir == 'X' ]] && GoodBye 'x'
					[[ ! -f "$siteDir/web/$dir/cimconfig.cfg" ]] && { Error "Specified directory '$dir' is not a CIM instance (no cimconfig.cfg), "; unset dir; } || \
					{ unset cims; cimStr="$dir"; return 0; } 
				done
			fi
		else
			cims+=($dir)
		fi
	done
	if [[ -z $cimStr ]]; then
		cimStr=$(printf -- "%s, " "${cims[@]}")
		cimStr="${cimStr//.\//}"
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
## 10-16-2017 @ 12.35.41 - ("2.0.19")  - dscudiero - Refactor includes
## 10-30-2017 @ 09.34.23 - ("2.0.22")  - dscudiero - Switch lower caseing of ans to use variable substitution
## 11-20-2017 @ 10.06.01 - ("2.0.36")  - dscudiero - Add 'other' option when not standard cim naming for instance
## 11-30-2017 @ 12.42.20 - ("2.0.41")  - dscudiero - Updated to return any directory that contains a cimconfig.cfg file, add arguments to handle the special situations
## 12-11-2017 @ 11.46.41 - ("2.0.42")  - dscudiero - Added PushPop to the includes list
## 12-11-2017 @ 16.26.50 - ("2.0.43")  - dscudiero - Filter out cim imstances with '_' in the name
## 12-14-2017 @ 15.46.53 - ("2.0.44")  - dscudiero - Only set siteDir if it is null on parg parsing
## 04-20-2018 @ 07:56:12 - 2.0.45 - dscudiero - Do not terminate if we cannot find the passed in siteDir, just return nothing.
## 04-09-2019 @ 09:43:17 - 2.0.62 - dscudiero - \nSwitch from using find to using ls to get the list of potential cim directories
