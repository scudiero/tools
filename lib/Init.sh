## XO NOT AUTOVERSION
#===================================================================================================
# version=2.1.68 # -- dscudiero -- Thu 03/22/2018 @ 13:34:02.62
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
	myIncludes="Msg3 RunSql SetSiteDirs GetCims PushPop SetFileExpansion Prompt"
	Import "$standardInteractiveIncludes $myIncludes"

	function MyContains { local string="$1"; local subStr="$2"; [[ "${string#*$subStr}" != "$string" ]] && echo true || echo false; return 0; }

	PushSettings "$FUNCNAME"
	SetFileExpansion 'off'

	local trueVars='noPreview noPublic addPvt'
	local falseVars='getClient anyClient getProducts getCims getEnv getSrcEnv getTgtEnv getDirs checkEnvs'
	falseVars="$falseVars allowMulti allowMultiProds allowMultiEnvs allowMultiCims checkProdEnv noWarn getjalot"
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
	done
	dump -3 -t -t parseStr getClient getEnv getDirs checkEnvs getProducts getCims allCims noPreview noPublic getJalot

	#===================================================================================================
	## Get data from user if necessary
	if [[ $getClient == true ]]; then
		local checkClient; unset checkClient
		if [[ $noCheck == true ]]; then
			[[ $testMode != true ]] && Warning "Requiring a client value and 'noCheck' flag was set"
			checkClient='noCheck';
		fi
		Prompt client 'What client do you wish to work with?' "$checkClient";
		Client="$client"; client=${client,,[a-z]}
		if [[ $client == '.' ]]; then
			client=$(basename $(pwd))
			if [[ $client == 'qa' || $client == 'test' || $client == 'next' || $client == 'curr'  || $client == 'preview'  || $client == 'public' ]]; then
				pushd $(pwd)
				cd ..
				Client=$(basename $(pwd)); client=${client,,[a-z]}
				popd
			fi
			getEnv=false; getSrcEnv=false; getTgtEnv=false; getDirs=false; checkEnvs=false
			srcDir="$(pwd)/web"
		fi
		#[[ $client == '*' || $client == 'all' || $client == '.' ]] && PopSettings "$FUNCNAME" && return 0
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
		unset clientEnvs
		if [[ $noCheck == true ]]; then
			unset tmpStr
			[[ $getSrcEnv == true ]] && tmpStr="$(ColorK 'Source')"
			[[ $getTgtEnv == true ]] && tmpStr="$(ColorK 'Target')"
			Warning "Requiring a environment value and 'noCheck' flag was set"
			clientEnvs="$courseleafDevEnvs,$courseleafProdEnvs"
			[[ $noPreview == true ]] && clientEnvs=$(sed s"/,preview//"g <<< $clientEnvs)
			[[ $noPublic == true ]] && clientEnvs=$(sed s"/,public//"g <<< $clientEnvs)
		else
			if [[ $client == '*' || $client == 'all' || $client == '.' ]]; then
				clientEnvs="$courseleafDevEnvs,$courseleafProdEnvs"
				[[ $noPreview == true ]] && clientEnvs=$(sed s"/,preview//"g <<< $clientEnvs)
				[[ $noPublic == true ]] && clientEnvs=$(sed s"/,public//"g <<< $clientEnvs)
			else
				unset notIn
				if [[ $noPreview == true || $noPublic == true ]]; then notIn='and env not in('; fi
				if [[ $noPreview == true ]]; then notIn="$notIn'preview'"; fi
				if [[ $noPublic == true ]]; then if [[ $noPreview == true ]]; then notIn="$notIn,'public'"; else notIn="$notIn'public'"; fi; fi
				if [[ $noPreview == true || $noPublic == true ]]; then notIn="$notIn)"; fi
				sqlStmt="select distinct env from $siteInfoTable where (name=\"$client\" or name=\"$client-test\") $notIn order by env"
				RunSql $sqlStmt
				if [[ ${#resultSet[@]} -eq 0 ]]; then
					for checkEnv in pvt dev test next curr; do
						[[ $(SetSiteDirs 'check' $checkEnv) == true ]] && clientEnvs="$clientEnvs $checkEnv"
					done
				else
					for result in "${resultSet[@]}"; do
						clientEnvs="$clientEnvs $result"
					done
					clientEnvs=${clientEnvs:1}
					[[ $(SetSiteDirs 'check' 'pvt') == true ]] && clientEnvs="pvt $clientEnvs"
				fi
			fi
			## If we have an envs variable that is not null then make sure all that are specified are valid
			if [[ -n $envs ]]; then
				if [[ $envs == 'all' ]]; then
					envs="${clientEnvs//all/}"; envs="${envs//,,/,}"
				else
					local i tmpEnvs
					tmpEnvs="$envs"; unset envs
					for i in ${tmpEnvs//,/ }; do [[ $(MyContains "$clientEnvs" "$i") == true ]] && envs="$envs,$i"; done
					envs="${envs:1}"
				fi
				env="${envs%% *}"
			fi
		fi

		if [[ $getEnv == true ]]; then
			unset promptModifer varSuffix
			if [[ $allowMultiEnvs == true ]]; then
				[[ -n $env && -z $envs ]] && envs="$env" && unset env
				varSuffix='s'
				promptModifer=" (comma separated)"
				clientEnvs="all $clientEnvs"
			fi
			unset defaultEnv
			if [[ $(Contains "$clientEnvs" 'pvt') == false ]]; then
				[[ $addPvt == true || $(SetSiteDirs 'check' 'pvt') == true ]] && clientEnvs="pvt $clientEnvs" && defaultEnv='pvt'
			fi
			[[ -z $env && -n $srcEnv ]] && env="$srcEnv"
			Prompt env "What environment/site do you wish to use?" "${clientEnvs// /,}" $defaultEnv; srcEnv=${srcEnv,,[a-z]}
			[[ $checkProdEnv == true ]] && checkProdEnv=$env
		fi

		if [[ $getSrcEnv == true ]]; then
			[[ -z $srcEnv && -n $env ]] && srcEnv="$env"
			[[ -z $srcEnv && -n $envs ]] && srcEnv="$envs"
			clientEnvsSave="$clientEnvs"
			clientEnvs="$clientEnvs skel"
			[[ -n $tgtEnv ]] && { clientEnvs="$(Trim "${clientEnvs//$tgtEnv/}")"; clientEnvs="${clientEnvs//,,/,}"; }
			unset defaultEnv
			if [[ $(Contains "$clientEnvs" 'pvt') == false ]]; then
				[[ $addPvt == true || $(SetSiteDirs 'check' 'pvt') == true ]] && clientEnvs="pvt $clientEnvs" && defaultEnv='pvt'
			fi
			Prompt srcEnv "What $(ColorK 'source') environment/site do you wish to use?" "${clientEnvs// /,}" $defaultEnv; srcEnv=${srcEnv,,[a-z]}
			clientEnvs="$clientEnvsSave"
			[[ $checkProdEnv == true ]] && checkProdEnv=$srcEnv
		fi

		if [[ $getTgtEnv == true ]]; then
			[[ -z $tgtEnv && -n $env && $srcEnv != $env ]] && tgtEnv="$env"
			[[ -z $tgtEnv && -n $envs && $srcEnv != $envs ]] && tgtEnv="$envs"
			[[ -n $srcEnv ]] && { clientEnvs="$(Trim "${clientEnvs//$srcEnv/}")"; clientEnvs="${clientEnvs//,,/,}"; }
			unset defaultEnv
			if [[ $(Contains "$clientEnvs" 'pvt') == false ]]; then
				[[ $addPvt == true || $(SetSiteDirs 'check' 'pvt') == true ]] && clientEnvs="pvt $clientEnvs"
			fi
			[[ -z $defaultEnv && $(Contains "$clientEnvs" 'test') == true ]] && defaultEnv='test'
			Prompt tgtEnv "What $(ColorK 'target') environment/site do you wish to use?" "${clientEnvs// /,}" $defaultEnv; srcEnv=${srcEnv,,[a-z]}
			[[ $checkProdEnv == true ]] && checkProdEnv=$tgtEnv
		fi

		# if [[ -n $srcEnv ]]; then
		# 	for j in $(echo pvt $clientEnvs skel | tr ',' ' '); do
		# 		[[ $srcEnv == ${j:0:${#srcEnv}} ]] && srcEnv="$j" && break;
		# 	done
		# fi
		# if [[ -n $tgtEnv ]]; then
		# 	for j in $(echo $clientEnvs | tr ',' ' '); do
		# 		[[ $tgtEnv == ${j:0:${#tgtEnv}} ]] && tgtEnv="$j" && break;
		# 	done
		# fi

		## Check to see if check production env is on and we are working in a next or curr environment, if yes then verify that
		## the user has authorization to modify a produciton environment.
		if [[ $checkProdEnv != false && $informationOnlyMode != true ]] && [[ $checkProdEnv == 'next' || $checkProdEnv == 'curr' ]]; then
		 	if [[ $noWarn != true ]]; then
				verify=true
				echo
				Warning "You are asking to update/overlay the $(ColorW $(Upper $checkProdEnv)) environment."
				unset productsinsupport
		 		sqlStmt="Select productsinsupport from $clientInfoTable where name=\"$client\""
		 		RunSql $sqlStmt
				[[ ${resultSet[0]} != 'NULL' ]] && productsinsupport="${resultSet[0]}"
				## If client has products in support and the user is not in the support group then quit
				[[ -n $UsersAuthGroups && -n $productsinsupport && $(Contains ",$UsersAuthGroups," ',support,') != true ]] && \
		 				Terminate "The client has products in support ($productsinsupport), please contact the support person assigned to this client to update the '$env' site"
		 		[[ -n productsinsupport ]] && Info 0 1 "FYI, the client has the following products in production: '$productsinsupport'"
				unset ans; Prompt ans "Are you sure" "Yes No"; ans=${ans:0:1}; ans=${ans,,[a-z]}
				[[ $ans != 'y' ]] && Goodbye -1
				getJalot=true
			fi
		fi
	fi
	dump -3 clientEnvs env envs srcEnv tgtEnv -n

	#===================================================================================================
	## get products
	if [[ $getProducts == true && -n $client ]]; then
		if [[ $client == '*' || $client == 'all' || $client == '.' ]]; then
			validProducts="$(tr ',' ' ' <<< $(Upper "$courseleafProducts"))"
		else
			unset validProducts
			## Get the products for this client
			if [[ $noCheck != true ]]; then
				sqlStmt="select products from $clientInfoTable where (name=\"$client\")"
				RunSql $sqlStmt
				if [[ ${#resultSet[@]} -gt 0 ]]; then
					## Remove the extra vanity products from the validProducts list
					for prod in $(tr ',' ' ' <<< ${resultSet[0]}); do
						[[ ${prod:0:3} == 'cat' || ${prod:0:3} == 'cim' ]] && [[ $prod != ${prod:0:3} ]] && continue
						validProducts="$validProducts,$prod"
					done
					[[ ${validProducts:0:1} == ',' ]] && validProducts=${validProducts:1}
					validProducts="$(tr ',' ' ' <<< $validProducts)"
				fi
			else
				validProducts='cat cim'
			fi
		fi
		unset promptModifer
		[[ $allowMultiProds == true ]] && prodVar='products' && promptModifer=" (comma separated)" || prodVar='product'
		## If there is only one product for this client then us it, otherwise prompt user
		prodCnt=$(grep -o ' ' <<< "$validProducts" | wc -l)
		if [[ $prodCnt -gt 0 ]]; then
			Prompt $prodVar "What $prodVar do you wish to work with$promptModifer?" "$validProducts all"
			prodVar=${prodVar,,[a-z]}; 
			eval $prodVar=\$$prodVar
			[[ $prodVar == 'all' ]] && eval $prodVar=$validProducts
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
	[[ -n $env ]] && eval siteDir="\$${env}Dir" || unset siteDir
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

	siteDir="$srcDir"

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
				[[ $(IsNumeric $jalot) != true ]] && { Msg3 "^Jalot must be numeric or 'na', please try again" ; unset jalot; }
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
## 10-05-2017 @ 09.41.42 - (2.1.19)    - dscudiero - Switch to use Msg3
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
## 03-22-2018 @ 13:42:22 - 2.1.68 - dscudiero - Updated for Msg3/Msg, RunSql2/RunSql, ParseArgStd/ParseArgStd2
