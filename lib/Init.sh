## XO NOT AUTOVERSION
#===================================================================================================
# version=2.0.53 # -- dscudiero -- 01/10/2017 @ 10:55:14.55
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

Import Prompt VerifyPromptVal SetSiteDirs GetCims VerifyContinue
function Init {
	PushSettings "$FUNCNAME"
	SetFileExpansion 'off'
	Msg2 $V3 "*** Starting: $FUNCNAME ***"

	local trueVars='noPreview noPublic'
	local falseVars='getClient anyClient getProducts getCims getEnv getSrcEnv getTgtEnv getDirs checkEnvs'
	falseVars="$falseVars allowMulti allowMultiProds allowMultiEnvs allowMultiCims checkProdEnv noWarn"
	for var in $trueVars; do eval $var=true; done
	for var in $falseVars; do eval $var=false; done

	local token checkProdEnv noWarn checkEnv
	#printf "%s\n" "$@"
	for token in $@; do
		token=$(Lower $token)
		dump -3 -t token
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
			Msg2 $W "Requiring a client value and 'noCheck' flag was set"
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
		[[ ! -d "$srcDir" ]] && Msg2 $T "Client = 'internal' but could not locate source directory:\n\t$srcDir"
		nextDir="/mnt/internal/site/stage"
		pvtDir=/mnt/dev11/web/internal-$userName
		[[ $env == '' ]] && env='next'
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
			Msg2 $W "Requiring a environment value and 'noCheck' flag was set"
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
				RunSql 'mysql' $sqlStmt
				if [[ ${#resultSet[@]} -eq 0 ]]; then
					for checkEnv in pvt dev test next curr; do
						[[ $(SetSiteDirs 'check' $checkEnv) == true ]] && clientEnvs="$clientEnvs $checkEnv"
					done
				else
					for result in "${resultSet[@]}"; do
						clientEnvs="$clientEnvs $result"
					done
				[[ $(SetSiteDirs 'check' 'pvt') == true ]] && clientEnvs=" pvt$clientEnvs"
				fi
				clientEnvs=${clientEnvs:1}
			fi
		fi

		if [[ $getEnv == true ]]; then
			unset promptModifer varSuffix
			if [[ $allowMultiEnvs == true ]]; then
				[[ $env != '' && $envs == '' ]] && envs="$env" && unset env
				varSuffix='s'
				promptModifer=" (comma separated)"
				clientEnvs="all $clientEnvs"
			fi
			Prompt "env$varSuffix" "What environment$varSuffix/site$varSuffix do you wish to use$promptModifer?" "$clientEnvs"; env=$(Lower $env)
			[[ $checkProdEnv == true ]] && checkProdEnv=$env
		fi
		if [[ $getSrcEnv == true ]]; then
			[[ $srcEnv == '' && $env != '' ]] && srcEnv="$env"
			clientEnvsSave="$clientEnvs"
			clientEnvs="$clientEnvs skel"
			Prompt srcEnv "What $(ColorK source) environment/site do you wish to use?" "$clientEnvs"; srcEnv=$(Lower $srcEnv)
			clientEnvs="$clientEnvsSave"
			[[ $checkProdEnv == true ]] && checkProdEnv=$srcEnv
		fi
		if [[ $getTgtEnv == true ]]; then
			[[ $tgtEnv == '' && $env != '' && $srcEnv != $env ]] && tgtEnv="$env"
			if [[ $srcEnv != '' ]]; then clientEnvs=$(echo $clientEnvs | sed s"/$srcEnv//"g); fi
			unset defaultEnv
			[[ $addPvt == true && $(Contains "$clientEnvs" 'pvt') == false ]] && clientEnvs="pvt,$clientEnvs"
			[[ $(Contains "$clientEnvs" 'pvt') == true ]] && defaultEnv='pvt'
			Prompt tgtEnv "What $(ColorK target) environment/site do you wish to use?" "$clientEnvs" "$defaultEnv"; tgtEnv=$(Lower $tgtEnv)
			[[ $checkProdEnv == true ]] && checkProdEnv=$tgtEnv
		fi

		if [[ $envs != '' ]]; then
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
		if [[ $srcEnv != '' ]]; then
			for j in $(echo $clientEnvs skel | tr ',' ' '); do
				[[ $srcEnv == ${j:0:${#srcEnv}} ]] && srcEnv="$j" && break;
			done
		fi
		if [[ $tgtEnv != '' ]]; then
			for j in $(echo $clientEnvs | tr ',' ' '); do
				[[ $tgtEnv == ${j:0:${#tgtEnv}} ]] && tgtEnv="$j" && break;
			done
		fi

		if [[ $checkProdEnv != false && $informationOnlyMode != true ]] && [[ $checkProdEnv == 'next' || $checkProdEnv == 'curr' ]]; then
		 	if [[ $noWarn != true ]]; then
				verify=true
				Msg2
				Warning "You are asking to update/overlay the $(ColorW $(Upper $checkProdEnv)) environment"
				unset ans; Prompt ans "Are you sure" "Yes No";
				ans=$(Lower ${ans:0:1})
				[[ $ans != 'y' ]] && Goodbye -1
			fi
		fi
	fi
	dump -3 clientEnvs env envs srcEnv tgtEnv -n

	#===================================================================================================
	## get products
	if [[ $getProducts == true && $client != '' ]]; then
		if [[ $client == '*' || $client == 'all' || $client == '.' ]]; then
			validProducts="$(tr ',' ' ' <<< $(Upper "$courseleafProducts"))"
		else
			unset validProducts
			## Get the products for this client
			sqlStmt="select products from $clientInfoTable where (name=\"$client\")"
			RunSql 'mysql' $sqlStmt
			if [[ ${#resultSet[@]} -gt 0 ]]; then
				## Remove the extra vanity products from the validProducts list
				for prod in $(tr ',' ' ' <<< ${resultSet[0]}); do
					[[ $(Contains ",$skipProducts," ",$prod,") == true ]] && continue
					validProducts="$validProducts,$prod"
				done
				[[ ${validProducts:0:1} == ',' ]] && validProducts=${validProducts:1}
				validProducts="$(tr ',' ' ' <<< $validProducts)"
			fi
		fi
		unset promptModifer
		[[ $allowMultiProds == true ]] && prodVar='products' && promptModifer=" (comma separated)" || prodVar='product'
		## If there is only one product for this client then us it, otherwise prompt user
		prodCnt=$(grep -o ' ' <<< "$validProducts" | wc -l)
		if [[ $prodCnt -gt 0 ]]; then
			Prompt $prodVar "What $prodVar do you wish to work with$promptModifer?" "$validProducts"
			eval $prodVar=$(Lower \$$prodVar)
		else
			Msg2 $NT1 "Only one value valid for '$prodVar', using '$validProducts'"
			eval $prodVar=$(Lower $validProducts)
		fi
	fi

	## If all clients then split
	[[ $client == '*' || $client == 'all' || $client == '.' ]] && PopSettings "$FUNCNAME" && return 0

	#===================================================================================================
	## Set Directories based on the current host name and client name
	# Set src and tgt directories based on client and env
	[[ $getDirs == true ]] && SetSiteDirs 'setDefault'
	[[ $env != '' ]] && eval siteDir="\$${env}Dir" || unset siteDir
	dump -3 env pvtDir devDir testDir nextDir currDir previewDir publicDir skelDir siteDir checkEnvs

	#===================================================================================================
	## Check to see if the srcDir exists
	#if [[ $checkEnvs == true && $anyClient != true && $srcDir == '' && $allowMultiEnvs != true ]] && [[ $getDirs == true || $getEnv == true || $getSrcEnv == true ]]; then
	if [[ $srcDir == '' && $allowMultiEnvs != true ]] && [[ $getDirs == true || $getEnv == true || $getSrcEnv == true ]]; then
		[[ $srcEnv == '' && $env != '' ]] && srcEnv=$env
		dump -3 srcEnv
		local i
		for i in $(echo "$courseleafDevEnvs $courseleafProdEnvs" | tr ',' ' ') skel; do
			if [[ $srcEnv == $i ]]; then
				chkDirName="${i}Dir"; chkDir="${!chkDirName}"
				[[ ! -d $chkDir && $checkEnvs == true && $noCheck != true ]] && Msg2 $T "Env is '$(TitleCase $i)' and directory '$chkDir' not found\nProcess stopping."
				srcDir=$chkDir
				break
			fi
		done
		dump -3 srcDir
	fi

	#===================================================================================================
	## Check to see if the tgtDir exists
	if [[ $getTgtEnv == true && $getDirs == true && $tgtDir == '' && $allowMultiEnvs != true ]]; then
		[[ $tgtEnv == '' && $env != '' ]] && tgtEnv=$env
		dump -3 tgtEnv
		local i
		for i in $(echo "$courseleafDevEnvs $courseleafProdEnvs" | tr ',' ' '); do
			if [[ $tgtEnv == $i ]]; then
				chkDirName="${i}Dir"; chkDir="${!chkDirName}"
				[[ ! -d $chkDir && $checkEnvs == true && $noCheck != true ]] && Msg2 $T "Env is '$(TitleCase $i)' and directory '$chkDir' not found\nProcess stopping."
				tgtDir=$chkDir
				break
			fi
		done
		dump -3 tgtDir
	fi

	siteDir="$srcDir"

	#===================================================================================================
	## find CIMs
	if [[ $getCims == true || $allCims == true ]] && [[ $getDirs == true ]] && [[ $cimStr == '' ]]; then
		[[ ${#cims} -eq 0 ]] && GetCims $siteDir
		[[ $cimStr == '' ]] && cimStr=$(printf -- "%s, " "${cims[@]}") && cimStr=${cimStr:0:${#cimStr}-2}
	fi

	#===================================================================================================
	## If testMode then run local customizations
		[[ $testMode == true && $(type -t testmode-$myName) == 'function' ]] && testMode-$myName
		[[ $testMode == true && $(type -t testmode-local) == 'function' ]] && testMode-local

	PopSettings "$FUNCNAME"
	Msg2 $V3 "*** Ending: $FUNCNAME ***"

	return 0
} #Init
export -f Init

#===================================================================================================
## Check-in log
#===================================================================================================
## Wed Jan  4 13:53:46 CST 2017 - dscudiero - General syncing of dev to prod
## Tue Jan 10 10:55:40 CST 2017 - dscudiero - Tweak messaging when updateing next env
