## XO NOT AUTOVERSION
#===================================================================================================
version="2.2.2" # -- dscudiero -- Tue 12/06/2018 @ 07:03:05
#===================================================================================================
# Standard initializations for Courseleaf Scripts
# Parms:
# 	'courseleaf' - get all items, client, env, site dirs, cims
# 	'getClient' -  get client name
# 	'getEnv' - get environments
# 	'getDirs' - get site dirs
# 	'checkEnvs' - check to make sure env dirs exist
# 	'getCims' - get cims
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================
function Init {
	[[ $fastInit == true ]] && { Note 0 1 "'fastInit' is active, skipping argument validation"; return 0; }
	myIncludes="SetSiteDirs CourseleafUtilities PushPop SetFileExpansion Prompt"
	Import "$standardInteractiveIncludes $myIncludes"

	function MyContains { local string="$1"; local subStr="$2"; [[ "${string#*$subStr}" != "$string" ]] && echo true || echo false; return 0; }

	PushSettings "$FUNCNAME"
	SetFileExpansion 'off'

	local trueVars='noPreview noPublic'
	local falseVars='getClient anyClient getProducts getCims getEnv getSrcEnv getTgtEnv getDirs checkEnvs'
	falseVars="$falseVars allowMulti allowMultiProds allowMultiEnvs allowMultiCims checkProdEnv noWarn getjalot addPvt addSkel"
	for var in $trueVars; do eval $var=true; done
	for var in $falseVars; do eval $var=false; done

	local token checkEnv
	#printf "%s\n" "$@"
	for token in $@; do
		token=${token,,[a-z]}
		dump -3 -t token
		[[ $token == 'clean' || $token == 'clear' ]] && unset env srcEnv tgtEnv srcDir tgtDir siteDir pvtDir devDir testDir currDir previewDir publicDir
		if [[ $token == 'courseleaf' || $token == 'all' ]]; then getClient=true; getEnv=true; getDirs=true; checkEnvs=true; fi
		if [[ $token == 'getclient' || $token == 'getclients' ]]; then getClient=true; fi
		if [[ $token == 'anyclient' || $token == 'anyclients' ]]; then anyClient=true; fi
		[[ $token == 'getproduct' ]] && getProducts=true
		if [[ $token == 'getproducts' ]]; then getProducts=true; allowMultiProds=true; fi
		[[ $token == 'getcim' ]] && getCims=true
		if [[ $token == 'getcims' ]]; then getCims=true; allowMultiCims=true; fi
		if [[ $token == 'nocim' || $token == 'nocims' ]]; then getCims=false; fi
		if [[ $token == 'allcim' || $token == 'allcims' ]]; then allCims=true; fi
		[[ $token == 'getenv' ]] && getEnv=true
		if [[ $token == 'getenvs' ]]; then getEnv=true; allowMultiEnvs=true; fi
		if [[ $token == 'getsrcenv' ]]; then getSrcEnv=true; getEnv=false; fi
		if [[ $token == 'gettgtenv' ]]; then getTgtEnv=true; getEnv=false; fi
		[[ $token == 'getdirs' ]] && getDirs=true
		if [[ $token == 'checkenv'  || $token == 'checkenvs' || $token == 'checkdir' || $token == 'checkdirs' ]]; then checkEnvs=true; fi
		[[ $token == 'nopreview' ]] && noPreview=true
		[[ $token == 'nopublic' ]] && noPublic=true
		[[ $token == 'nocheck' ]] && noCheck=true
		[[ $token == 'checkprodenv' ]] && checkProdEnv=true
		[[ $token == 'nowarn' ]] && noWarn=true
		[[ $token == 'getjalot' ]] && getJalot=true
		[[ $token == 'addpvt' ]] && addPvt=true
		[[ $token == 'addskel' ]] && addSkel=true
	done
	dump -3 -t -t parseStr getClient getEnv getDirs checkEnvs getProducts getCims allCims noPreview noPublic getJalot

	#===================================================================================================
	## Get data from user if necessary
	if [[ $getClient == true ]]; then
		local checkClient; unset checkClient
		if [[ $noCheck == true ]]; then
			[[ $testMode != true ]] && Warning "Requiring a client value and 'noCheck' flag was set"
			Prompt client 'Please specify the full path of the site directory' '*dir*';
		else
			Prompt client 'What client do you wish to work with?';
		fi
		client=${client,,[a-z]}
		if [[ $client == '.' ]]; then
			client=$(basename $(pwd))
			if [[ $client == 'qa' || $client == 'test' || $client == 'next' || $client == 'curr'  || $client == 'preview'  || $client == 'public' ]]; then
				pushd $(pwd)
				cd ..
				client=$(basename $(pwd)); client=${client,,[a-z]}
				popd
			fi
			getEnv=false; getSrcEnv=false; getTgtEnv=false; getDirs=false; checkEnvs=false
			srcDir="$(pwd)/web"
		fi
		#[[ $client == '*' || $client == 'all' || $client == '.' ]] && PopSettings "$FUNCNAME" && return 0
	fi

	## If noCheck is active then assume the current value for client is a fully specified directory name
	if [[ $noCheck == true ]]; then
		siteDir="$client"
		[[ ! -d $siteDir ]] && Terminate "'noCheck' option is active and the directory specified does not exist"
		client="$(basename $siteDir)"
		[[ $(Contains "$client" "-$userName") == true ]] && { env='pvt'; client="${client%-*}"; }

		## scan passed in directory and set env
		if [[ -z $env ]]; then
			## Is this a 'dev' site?
			for token in ${devServers//,/ }; do
				[[ $(Contains "$siteDir" "/$token/") == true ]] && { env='dev'; break; }
			done
			## Is this a 'prod' site?
			if [[ -z $env ]]; then
				for env in ${courseleafProdEnvs//,/ }; do
					[[ $(Contains "$siteDir" "/$env/") == true ]] && break;
				done
			fi
		fi
		[[ $getSrcEnv == true ]] && srcEnv="$env"
		[[ $getTgtEnv == true ]] && tgtEnv="$env"
	fi

	## Special processing for the 'internal' site
	if [[ $getEnv == true && $client == 'internal' ]]; then
		srcDir=/mnt/internal/site/stage
		[[ ! -d "$srcDir" ]] && Terminate "Client = 'internal' but could not locate source directory:\n\t$srcDir"
		nextDir="/mnt/internal/site/stage"
		pvtDir=/mnt/dev11/web/internal-$userName
		[[ -z $env ]] && env='next'
		eval "srcDir="\$${env}Dir""
		PopSettings "$FUNCNAME"
		siteDir="$srcDir"
		tgtDir="$pvtDir"
		unset MyContains
		return 0
	fi

	## Process env and envs
	if [[ $getEnv == true || $getSrcEnv == true || $getTgtEnv == true ]]; then
		[[ ${clientData["${client}.envs"]+abc} ]] && clientEnvs="${clientData["${client}.envs"]}" || clientEnvs="$courseleafDevEnvs,$courseleafProdEnvs"
		clientEnvs="${clientEnvs/,preview}"
		clientEnvs="${clientEnvs/,public}"
		[[ $noCheck == true ]] && Warning "Requiring a environment value and 'noCheck' flag was set"
		# [[ $addPvt == true ]] && clientEnvs="${clientEnvs},pvt"

		## Generic get env
		if [[ $getEnv == true ]]; then
			unset promptModifer varSuffix
			if [[ $allowMultiEnvs == true ]]; then
				[[ -n $env && -z $envs ]] && envs="$env" && unset env
				varSuffix='s'
				promptModifer=" (comma separated)"
				clientEnvs="$clientEnvs,all"
			fi
			[[ $(Contains "$clientEnvs" 'pvt') == true ]] && defaultEnv='pvt' || unset defaultEnv
			[[ -z $env && -n $srcEnv ]] && env="$srcEnv"
			[[ -z $env && -n $envs ]] && env="$envs"
			Prompt env "What environment/site do you wish to use?" "$clientEnvs" $defaultEnv; srcEnv=${srcEnv,,[a-z]}
			[[ $checkProdEnv == true ]] && checkProdEnv=$env
		fi

		if [[ $getSrcEnv == true ]]; then
			[[ -z $srcEnv && -n $env ]] && srcEnv="$env"
			[[ -z $srcEnv && -n $envs ]] && srcEnv="$envs"
			[[ -z $srcEnv && -n $tgtEnv ]] && { clientEnvs="$(Trim "${clientEnvs//$tgtEnv/}")"; clientEnvs="${clientEnvs//,,/,}"; }

			[[ $addSkel == true ]] && clientEnvs="$clientEnvs,skel"
			[[ $(Contains "$clientEnvs" 'pvt') == true ]] && defaultEnv='pvt' || unset defaultEnv
			[[ ${clientEnvs:${#clientEnvs}-1:1} == ',' ]] && clientEnvs="${clientEnvs:0:${#clientEnvs}-1}"
			Prompt srcEnv "What $(ColorK 'source') environment/site do you wish to use?" "$clientEnvs" $defaultEnv; srcEnv=${srcEnv,,[a-z]}
			[[ $checkProdEnv == true ]] && checkProdEnv=$srcEnv
			[[ ${clientData["${client}.${srcEnv}.siteDir"]]+abc} ]] && srcDir="${clientData["${client}.${srcEnv}.siteDir"]}"
			[[ $srcEnv == 'skel' ]] && srcDir="$skeletonRoot/release"	
		fi

		if [[ $getTgtEnv == true ]]; then
			[[ -z $tgtEnv && -n $env && $srcEnv != $env ]] && tgtEnv="$env"
			[[ -z $tgtEnv && -n $envs && $srcEnv != $envs ]] && tgtEnv="$envs"
			[[ -z $tgtEnv && -n $srcEnv ]] && { clientEnvs="$(Trim "${clientEnvs//$srcEnv/}")"; clientEnvs="${clientEnvs//,,/,}"; }
			clientEnvs="$(Trim "${clientEnvs//skel/}")"; clientEnvs="${clientEnvs//,,/,}";
			[[ -z $defaultEnv && $(Contains "$clientEnvs" 'test') == true ]] && defaultEnv='test' || unset defaultEnv
			[[ $addPvt == true ]] && clientEnvs="${clientEnvs},pvt"
			[[ ${clientEnvs:${#clientEnvs}-1:1} == ',' ]] && clientEnvs="${clientEnvs:0:${#clientEnvs}-1}"
			Prompt tgtEnv "What $(ColorK 'target') environment/site do you wish to use?" "$clientEnvs" $defaultEnv; srcEnv=${srcEnv,,[a-z]}
			[[ $checkProdEnv == true ]] && checkProdEnv=$tgtEnv	
			[[ ${clientData["${client}.${tgtEnv}.siteDir"]+abc} ]] && tgtDir="${clientData["${client}.${tgtEnv}.siteDir"]}"		
		fi

		## Check to see if check production env is on and we are working in a next or curr environment, if yes then verify that
		## the user has authorization to modify a produciton environment.
		if [[ $checkProdEnv != false && $informationOnlyMode != true ]] && [[ $checkProdEnv == 'next' || $checkProdEnv == 'curr' ]]; then
		 	if [[ $noWarn != true ]]; then
				verify=true
				echo
				Warning "You are asking to update/overlay the $(ColorW $(Upper $checkProdEnv)) environment."
				if [[ ${clientData["${client}.productsInSupport"]+abc} ]]; then
					## If client has products in support and the user is not in the support group then quit
					[[ $(Contains ",$UsersAuthGroups," ',support,') != true ]] && \
		 				Terminate "The client has products in support (${clientData["${client}.productsInSupport"]}), please contact the support person assigned to this client to update the '$env' site"
					Info 0 1 "FYI, the client has the following products in production: '${clientData["${client}.productsInSupport"]}'"
				fi
				unset ans; Prompt ans "Are you sure" "Yes No"; ans=${ans:0:1}; ans=${ans,,[a-z]}
				[[ $ans != 'y' ]] && Goodbye -1
				getJalot=true
			fi
		fi
		[[ -n $envs && -z $env ]] && env="$envs"
		[[ -n $env && -z $envs ]] && envs="$env"
	fi
	dump -3 clientEnvs env envs srcEnv tgtEnv -n

	#===================================================================================================
	## get products
	if [[ $getProducts == true && -n $client ]]; then
		unset validProducts
		if [[ $client == '*' || $client == 'all' || $client == '.' ]]; then
			validProducts="$courseleafProducts"
		else
			[[ ${clientData["${client}.products"]+abc} ]] && validProducts="${clientData["${client}.products"]}"
		fi
		[[ $noCheck == true ]] && validProducts='cat cim'

		unset promptModifer
		[[ $allowMultiProds == true ]] && prodVar='products' && promptModifer=" (comma separated)" || prodVar='product'
		## If there is only one product for this client then us it, otherwise prompt user
		prodCnt=$(grep -o ',' <<< "$validProducts" | wc -l)
		if [[ $prodCnt -gt 0 ]]; then
			Prompt $prodVar "What $prodVar do you wish to work with$promptModifer?" "$validProducts all"
			prodVar=${prodVar,,[a-z]}; 
			[[ $prodVar == 'all' ]] && eval $prodVar="${validProducts// /,}" || eval $prodVar=\$$prodVar
		else
			Note 0 1 "Only one value valid for '$prodVar', using '$validProducts'"
			prodVar=${validProducts,,[a-z]}; 
			eval $prodVar=\$$prodVar
		fi
	fi # getProducts

	## If all clients then split
	[[ $client == '*' || $client == 'all' || $client == '.' ]] && PopSettings "$FUNCNAME" && unset MyContains && return 0

	#===================================================================================================
	## Set Directories based on the current host name and client name
	# Set src and tgt directories based on client and env
	if [[ $getDirs == true ]]; then
		SetSiteDirs #'setDefault'
		[[ -z $pvtDir && -n $devDir ]] && pvtDir="$(sed s/$client/$client-$userName/g <<< $devDir)"
		[[ -z $pvtDir ]] && pvtDir="/mnt/$defaultDevServer/web/$client-$userName"
	fi
	[[ -n $env && -z $siteDir ]] && eval siteDir="\$${env}Dir" # || unset siteDir

	dump -3 env pvtDir devDir testDir nextDir currDir previewDir publicDir skelDir siteDir checkEnvs

	#===================================================================================================
	## Check to see if the srcDir exists
	if [[ -z $srcDir && $allowMultiEnvs != true ]] && [[ $getDirs == true || $getEnv == true || $getSrcEnv == true ]]; then
		[[ -z $srcEnv && -n $env ]] && srcEnv=$env
		dump -3 srcEnv
		local i
		for i in $(echo "$courseleafDevEnvs $courseleafProdEnvs" | tr ',' ' ') skel; do
			if [[ $srcEnv == $i ]]; then
				chkDirName="${i}Dir"; chkDir="${!chkDirName}"
				[[ ! -d $chkDir && $checkEnvs == true && $noCheck != true ]] && Terminate "Env is '$(TitleCase $i)' and site directory '$chkDir' not found\nProcess stopping."
				srcDir=$chkDir
				break
			fi
		done
		dump -3 srcDir
	fi

	#===================================================================================================
	## Check to see if the tgtDir exists
	if [[ $getTgtEnv == true && $getDirs == true && -z $tgtDir && $allowMultiEnvs != true ]]; then
		[[ -z $tgtEnv && -n $env ]] && tgtEnv=$env
		local i
		for i in $(echo "$courseleafDevEnvs $courseleafProdEnvs" | tr ',' ' '); do
			if [[ $tgtEnv == $i ]]; then
				chkDirName="${i}Dir"; chkDir="${!chkDirName}"
				[[ ! -d $chkDir && $checkEnvs == true && $noCheck != true ]] && Terminate "Env is '$(TitleCase $i)' and site directory '$chkDir' not found\nProcess stopping."
				tgtDir=$chkDir
				break
			fi
		done
		dump -3 tgtDir
	fi

	## Set siteDir
	[[ -n $srcDir && -z $siteDir ]] && siteDir="$srcDir"
	[[ -n $tgtDir && -z $siteDir ]] && siteDir="$tgtDir"

	#===================================================================================================
	## find CIMs
	if [[ $getCims == true || $allCims == true ]] && [[ $getDirs == true ]] && [[ -z $cimStr ]]; then
		[[ ${#cims} -eq 0 ]] && GetCims "$siteDir"
		[[ -z $cimStr ]] && cimStr=$(printf -- "%s, " "${cims[@]}") && cimStr=${cimStr:0:${#cimStr}-2}
	fi

	#===================================================================================================
	## Get jalot task number
	if [[ $getJalot == true ]]; then
		[[ -n $jalot && $(IsNumeric $jalot) != true && $jalot != 'na' && $jalot != 'n/a' ]] && unset jalot
		while [[ -z $jalot ]]; do
			Prompt jalot "Please enter the jalot task number:" "*any*,na"
			if [[ $jalot == 'na' || $jalot == 'n/a' || $jalot == 0 ]]; then
				jalot='N/A'
			else
				[[ $(IsNumeric $jalot) != true ]] && { Msg "^Jalot must be numeric or 'na', please try again" ; unset jalot; }
			fi
			[[ $noComment != true && -n $jalot && ${jalot,,[a-z]} != 'n/a' ]] && Prompt comment "Please enter the business reason for making this update:\n^" "*any*"
		done
		[[ $jalot == 'na' || $jalot == 'n/a' || $jalot == 0 ]] && jalot='N/A'
		[[ -n $comment ]] && comment="(Task:$jalot) $comment"
	fi

	#===================================================================================================
	## If testMode then run local customizations
		if [[ $testMode == true ]]; then
			[[ $(Contains ",$adminUsers," ",$userName,") != true ]] && Terminate "Sorry, you do not have sufficient permissions to run this script in 'testMode'"
			[[ $(type -t testmode-$myName) == 'function' ]] && testMode-$myName
			[[ $(type -t testmode-$myName) == 'function' ]] && testMode-$myName
		fi

	PopSettings "$FUNCNAME"

	unset MyContains
	return 0
} #Init
export -f Init

#===================================================================================================
## Check-in log
#===================================================================================================
## Wed Jan  4 13:53:46 CST 2017 - dscudiero - General syncing of dev to prod
## Tue Jan 10 10:55:40 CST 2017 - dscudiero - Tweak messaging when updateing next env
## Fri Jan 20 10:26:54 CST 2017 - dscudiero - fix problem setting environment if nocheck is active
## Fri Jan 20 12:48:16 CST 2017 - dscudiero - cixes to getSrcEnv and getTgtEnv
## Mon Jan 23 12:41:16 CST 2017 - dscudiero - Fix problem setting tgtEnv
## Wed Jan 25 12:44:31 CST 2017 - dscudiero - Fix issue setting srcEnv and tgtEnv when abbreviated values were passed in on the command line
## Tue Feb  7 15:15:43 CST 2017 - dscudiero - x
## Mon Mar  6 15:55:02 CST 2017 - dscudiero - Tweak product parsing
## Tue Mar 14 09:31:45 CDT 2017 - dscudiero - v
## Tue Mar 14 10:36:22 CDT 2017 - dscudiero - Add tab char to GetCims call
## Tue Mar 14 10:38:48 CDT 2017 - dscudiero - General syncing of dev to prod
## 04-11-2017 @ 07.08.59 - (2.0.120)   - dscudiero - Add checks for admin functions
## 04-13-2017 @ 08.12.33 - (2.0.125)   - dscudiero - set default env to pvt if present in the env list
## 04-13-2017 @ 09.49.28 - (2.0.134)   - dscudiero - Fix problem parsing envs
## 05-02-2017 @ 11.28.12 - (2.0.135)   - dscudiero - Hide nocheck message of in test mode
## 05-24-2017 @ 12.18.27 - (2.0.136)   - dscudiero - skip
## 06-08-2017 @ 16.27.22 - (2.0.138)   - dscudiero - Add the clear option
## 08-07-2017 @ 15.50.01 - (2.1.0)     - dscudiero - Refactor checking the production enviroments, check user's auth
## 08-25-2017 @ 15.34.51 - (2.1.1)     - dscudiero - Change messageing
## 08-25-2017 @ 15.35.25 - (2.1.2)     - dscudiero - Tweak messaging
## 08-28-2017 @ 07.25.51 - (2.1.3)     - dscudiero - skip
## 08-28-2017 @ 07.46.41 - (2.1.4)     - dscudiero - General syncing of dev to prod
## 08-28-2017 @ 10.34.36 - (2.1.5)     - dscudiero - g
## 08-28-2017 @ 11.14.59 - (2.1.6)     - dscudiero - fix syntax error
## 09-01-2017 @ 13.44.07 - (2.1.6)     - dscudiero - Tweak messaging format
## 09-28-2017 @ 07.42.51 - (2.1.8)     - dscudiero - Remove the 'setDefaults' from the SetSiteDirs call for getEnvs
## 09-28-2017 @ 07.57.54 - (2.1.9)     - dscudiero - set pvtDir if getDirs
## 09-28-2017 @ 08.32.48 - (2.1.10)    - dscudiero - Make sure in getEnv that pvtDir has a value even if devDir is not found
## 10-03-2017 @ 14.59.00 - (2.1.11)    - dscudiero - Commented out the auth check for now
## 10-03-2017 @ 15.46.33 - (2.1.17)    - dscudiero - Uncomment auth check for updating next sites
## 10-04-2017 @ 13.09.46 - (2.1.18)    - dscudiero - General syncing of dev to prod
## 10-05-2017 @ 09.41.42 - (2.1.19)    - dscudiero - Switch to use Msg
## 10-19-2017 @ 16.05.16 - (2.1.20)    - dscudiero - Add to include list
## 11-01-2017 @ 09.54.16 - (2.1.35)    - dscudiero - Tweak how envs are process in getenv
## 11-02-2017 @ 10.51.57 - (2.1.38)    - dscudiero - Add 'addPvt' option
## 11-02-2017 @ 15.54.00 - (2.1.45)    - dscudiero - Fix addPvt code to check to make sure the pvt site exists befor adding to the envs list
## 11-03-2017 @ 09.53.34 - (2.1.56)    - dscudiero - Fix problem adding pvt site to clientEnvs lsit
## 12-01-2017 @ 09.14.03 - (2.1.58)    - dscudiero - Make sure env is set from envs if envs has a value
## 12-04-2017 @ 09.55.21 - (2.1.59)    - dscudiero - Update 'products in support' messaging
## 12-14-2017 @ 15.47.21 - (2.1.60)    - dscudiero - Remove errant "t" on call to GetCims
## 12-20-2017 @ 09.19.45 - (2.1.61)    - dscudiero - Added 'getJalot' as an action request
## 12-20-2017 @ 09.33.39 - (2.1.62)    - dscudiero - Force getJalot if updating next or curr
## 12-20-2017 @ 09.41.19 - (2.1.63)    - dscudiero - Cosmetic/minor change
## 03-22-2018 @ 13:42:22 - 2.1.68 - dscudiero - Updated for Msg/Msg, RunSql2/RunSql, ParseArgStd/ParseArgStd2
## 03-23-2018 @ 17:04:12 - 2.1.69 - dscudiero - Msg3 -> Msg
## 04-24-2018 @ 11:24:04 - 2.1.70 - dscudiero - Bail out if fastInit is set
## 04-24-2018 @ 11:58:35 - 2.1.71 - dscudiero - Remive 'if' from the fastInit check
## 05-08-2018 @ 08:13:28 - 2.1.73 - dscudiero - Add a message if fastInit is active
## 05-08-2018 @ 11:51:42 - 2.1.75 - dscudiero - Set env variable if envs has a value and vice versa
## 05-11-2018 @ 09:19:34 - 2.1.76 - dscudiero - Change includes from GetCims to CourseleafUtilities
## 05-29-2018 @ 13:20:45 - 2.1.103 - dscudiero - Refactored to limite direct usage of the data warehouse
## 05-29-2018 @ 14:36:18 - 2.1.108 - dscudiero - Fix bug if env is passed in in script args
## 05-30-2018 @ 12:10:10 - 2.1.120 - dscudiero - Fix problem setting clientEnvs
## 06-01-2018 @ 11:26:58 - 2.1.124 - dscudiero - In product processioing, if all then comma delmite the values
## 06-05-2018 @ 11:05:50 - 2.1.124 - dscudiero - Fix problem setting valid values for srcEnv and tgtEnv
## 06-05-2018 @ 11:10:11 - 2.1.124 - dscudiero - Cosmetic/minor change/Sync
## 06-06-2018 @ 10:52:15 - 2.1.124 - dscudiero - Incorporate the client nocheck logic
## 06-11-2018 @ 16:44:42 - 2.2.1 - dscudiero - Commented out the products in support checks
## 06-12-2018 @ 07:03:32 - 2.2.2 - dscudiero - Add products in support check back in
