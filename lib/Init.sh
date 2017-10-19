## XO NOT AUTOVERSION
#===================================================================================================
# version=2.1.21 # -- dscudiero -- Thu 10/19/2017 @ 16:07:54.05
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
	myIncludes="Msg3 RunSql2 SetSiteDirs GetCims PushPop SetFileExpansion Prompt"
	Import "$standardInteractiveIncludes $myIncludes"

	PushSettings "$FUNCNAME"
	SetFileExpansion 'off'

	local trueVars='noPreview noPublic'
	local falseVars='getClient anyClient getProducts getCims getEnv getSrcEnv getTgtEnv getDirs checkEnvs'
	falseVars="$falseVars allowMulti allowMultiProds allowMultiEnvs allowMultiCims checkProdEnv noWarn"
	for var in $trueVars; do eval $var=true; done
	for var in $falseVars; do eval $var=false; done

	local token checkEnv
	#printf "%s\n" "$@"
	for token in $@; do
		token=$(Lower $token)
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
	done
	dump -3 -t -t parseStr getClient getEnv getDirs checkEnvs getProducts getCims allCims noPreview noPublic

	#===================================================================================================
	## Get data from user if necessary
	if [[ $getClient == true ]]; then
		local checkClient; unset checkClient
		if [[ $noCheck == true ]]; then
			[[ $testMode != true ]] && Warning "Requiring a client value and 'noCheck' flag was set"
			checkClient='noCheck';
		fi
		Prompt client 'What client do you wish to work with?' "$checkClient";
		Client="$client"; client=$(Lower $client)
		if [[ $client == '.' ]]; then
			client=$(basename $(pwd))
			if [[ $client == 'qa' || $client == 'test' || $client == 'next' || $client == 'curr'  || $client == 'preview'  || $client == 'public' ]]; then
				pushd $(pwd)
				cd ..
				Client=$(basename $(pwd)); client=$(Lower $client)
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
				RunSql2 $sqlStmt
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
		fi

		if [[ $getEnv == true ]]; then
			unset promptModifer varSuffix
			if [[ $allowMultiEnvs == true ]]; then
				[[ -n $env && -z $envs ]] && envs="$env" && unset env
				varSuffix='s'
				promptModifer=" (comma separated)"
				clientEnvs="all $clientEnvs"
			fi
			[[ $addPvt == true && $(Contains "$clientEnvs" 'pvt') == false && $srcEnv != 'pvt' ]] && clientEnvs="pvt,$clientEnvs"
			[[ $(Contains "$clientEnvs" 'pvt') == true ]] && defaultEnv='pvt' || unset defaultEnv
			Prompt env "What environment/site do you wish to use?" "$(tr ' ' ',' <<< $clientEnvs)" $defaultEnv; srcEnv=$(Lower $srcEnv)
			[[ $checkProdEnv == true ]] && checkProdEnv=$env
		fi

		if [[ $getSrcEnv == true ]]; then
			[[ -z $srcEnv && -n $env ]] && srcEnv="$env"
			clientEnvsSave="$clientEnvs"
			clientEnvs="$clientEnvs skel"
			if [[ -n $tgtEnv ]]; then
				unset clientEnvsNew
				for token in $clientEnvs; do
					[[ $token != $tgtEnv ]] && clientEnvsNew="$clientEnvsNew $token"
				done
				[[ ${clientEnvsNew:0:1} == '' ]] && $clientEnvsNew=${clientEnvsNew:1}
				clientEnvs="$clientEnvsNew"
			fi
			unset defaultEnv
			[[ $addPvt == true && $(Contains "$clientEnvs" 'pvt') == false && $srcEnv != 'pvt' ]] && clientEnvs="pvt,$clientEnvs"
			[[ $(Contains "$clientEnvs" 'pvt') == true ]] && defaultEnv='pvt'
			Prompt srcEnv "What $(ColorK 'source') environment/site do you wish to use?" "$(tr ' ' ',' <<< $clientEnvs)" $defaultEnv; srcEnv=$(Lower $srcEnv)
			clientEnvs="$clientEnvsSave"
			[[ $checkProdEnv == true ]] && checkProdEnv=$srcEnv
		fi

		if [[ $getTgtEnv == true ]]; then
			[[ -z $tgtEnv && -n $env && $srcEnv != $env ]] && tgtEnv="$env"
			if [[ -n $srcEnv ]]; then
				unset clientEnvsNew
				for token in $clientEnvs; do
					[[ $token != $srcEnv ]] && clientEnvsNew="$clientEnvsNew $token"
				done
				[[ ${clientEnvsNew:0:1} == '' ]] && $clientEnvsNew=${clientEnvsNew:1}
				clientEnvs="$clientEnvsNew"
			fi
			unset defaultEnv
			[[ $addPvt == true && $(Contains "$clientEnvs" 'pvt') == false && $srcEnv != 'pvt' ]] && clientEnvs="pvt,$clientEnvs"
			[[ $(Contains "$clientEnvs" 'pvt') == true ]] && defaultEnv='pvt'
			[[ -z $defaultEnv && $(Contains "$clientEnvs" 'test') == true ]] && defaultEnv='test'
			Prompt tgtEnv "What $(ColorK 'target') environment/site do you wish to use?" "$(tr ' ' ',' <<< $clientEnvs)" $defaultEnv; srcEnv=$(Lower $srcEnv)
			[[ $checkProdEnv == true ]] && checkProdEnv=$tgtEnv
		fi

		if [[ -n $envs ]]; then
			if [[ $envs == 'all' ]]; then
				envs="$clientEnvs"
				envs=$(sed s'/all//' <<< $envs)
			else
				local i j tmpEnvs
				tmpEnvs="$envs"
				unset envs
				for i in $(echo $tmpEnvs | tr ',' ' '); do
					for j in $(echo $clientEnvs | tr ',' ' '); do
						[[ $i == ${j:0:${#i}} ]] && envs="$envs,$j" && break;
					done
				done
				envs="${envs:1}"
			fi
		fi
		if [[ -n $srcEnv ]]; then
			for j in $(echo pvt $clientEnvs skel | tr ',' ' '); do
				[[ $srcEnv == ${j:0:${#srcEnv}} ]] && srcEnv="$j" && break;
			done
		fi
		if [[ -n $tgtEnv ]]; then
			for j in $(echo $clientEnvs | tr ',' ' '); do
				[[ $tgtEnv == ${j:0:${#tgtEnv}} ]] && tgtEnv="$j" && break;
			done
		fi

		## Check to see if check production env is on and we are working in a next or curr environment, if yes then verify that
		## the user has authorization to modify a produciton environment.
		if [[ $checkProdEnv != false && $informationOnlyMode != true ]] && [[ $checkProdEnv == 'next' || $checkProdEnv == 'curr' ]]; then
		 	if [[ $noWarn != true ]]; then
				verify=true
				echo
				Warning "You are asking to update/overlay the $(ColorW $(Upper $checkProdEnv)) environment."
				unset productsinsupport
		 		sqlStmt="Select productsinsupport from $clientInfoTable where name=\"$client\""
		 		RunSql2 $sqlStmt
				[[ ${resultSet[0]} != 'NULL' ]] && productsinsupport="${resultSet[0]}"
				## If client has products in support and the user is not in the support group then quit
				[[ -n $UsersAuthGroups && -n $productsinsupport && $(Contains ",$UsersAuthGroups," ',support,') != true ]] && \
		 				Terminate "You do not have authority to modify the $env environment, please contact the support person assigned to this client"
		 		[[ -n productsinsupport ]] && Info 0 1 "FYI, the client has the following products in production: '${resultSet[0]}'"
				unset ans; Prompt ans "Are you sure" "Yes No";
				ans=$(Lower ${ans:0:1})
				[[ $ans != 'y' ]] && Goodbye -1
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
				RunSql2 $sqlStmt
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
			eval $prodVar=$(Lower \$$prodVar)
			[[ $prodVar == 'all' ]] && eval $prodVar=$validProducts
		else
			Note 0 1 "Only one value valid for '$prodVar', using '$validProducts'"
			eval $prodVar=$(Lower $validProducts)
		fi
	fi # getProducts

	## If all clients then split
	[[ $client == '*' || $client == 'all' || $client == '.' ]] && PopSettings "$FUNCNAME" && return 0

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
				[[ ! -d $chkDir && $checkEnvs == true && $noCheck != true ]] && Terminate "Env is '$(TitleCase $i)' and directory '$chkDir' not found\nProcess stopping."
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
		dump -3 tgtEnv
		local i
		for i in $(echo "$courseleafDevEnvs $courseleafProdEnvs" | tr ',' ' '); do
			if [[ $tgtEnv == $i ]]; then
				chkDirName="${i}Dir"; chkDir="${!chkDirName}"
				[[ ! -d $chkDir && $checkEnvs == true && $noCheck != true ]] && Terminate "Env is '$(TitleCase $i)' and directory '$chkDir' not found\nProcess stopping."
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
		[[ ${#cims} -eq 0 ]] && GetCims "$siteDir" "\t"
		[[ -z $cimStr ]] && cimStr=$(printf -- "%s, " "${cims[@]}") && cimStr=${cimStr:0:${#cimStr}-2}
	fi

	#===================================================================================================
	## If testMode then run local customizations
		if [[ $testMode == true ]]; then
			[[ $(Contains ",$adminUsers," ",$userName,") != true ]] && Terminate "Sorry, you do not have sufficient permissions to run this script in 'testMode'"
			[[ $(type -t testmode-$myName) == 'function' ]] && testMode-$myName
			[[ $(type -t testmode-$myName) == 'function' ]] && testMode-$myName
		fi

	PopSettings "$FUNCNAME"

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
