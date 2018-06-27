## XO NOT AUTOVERSION
#===================================================================================================
# version="2.1.10" # -- dscudiero -- Wed 13/06/2018 @ 13:48:18
#===================================================================================================
# Verify result value
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================
function VerifyPromptVal {
	myIncludes="RunSql StartRemoteSession PushPop"
	Import "$myIncludes"

	local i
	PushSettings "$FUNCNAME"
	SetFileExpansion 'off'
	local allowMultiple=false
	local processedRequest=false
	[[ ${promptVar:(-1)} == 's' ]] && allowMultiple=true
	dump -3 -l -t allowMultiple promptVar response validateList
	unset verifyMsg

	if [[ $(Contains "$validateListString" 'noCheck') == true ]]; then
		verifyMsg=true
		SetFileExpansion
		PopSettings "$FUNCNAME"
		return 0
	fi

	## Client
	if [[ $promptVar == 'client' && -z $verifyMsg && $noCheck != true ]]; then
		if [[ $response == '*' || $response == 'all' ]]; then
			[[ $response == '*' ]] && response='all'
			eval $promptVar=$response
			verifyMsg=true
			SetFileExpansion
			PopSettings "$FUNCNAME"
			return 0
		elif [[ ${response:0:1} == '<' ]]; then
			response=${response:1}
			lenResponse=${#response}
			response=${response:0:$lenResponse-1}
			checkClient=false
		else
			## Load the clientData hash from the client data file
			## utoledo|University of Toledo|leepfrog|cat,cati,cim|
			## 	curr-build7/mesaverde#NULL;dev-build7/dev7#courseadmin,miscadmin,programadmin;
			## 	next-build7/mesaverde#NULL;test-build7/mesaverde#courseadmin,miscadmin,programadmin
			local grepStr="$(ProtectedCall "grep \"^${response}|\" $workwithDataFile")"
			if [[ -n $grepStr ]]; then
				local dataStr="${grepStr%|*}";
				clientData["${response}.code"]="${dataStr%%|*}"; dataStr="${dataStr#*|}"
				clientData["${response}.longName"]="${dataStr%%|*}"; dataStr="${dataStr#*|}"
				clientData["${response}.hosting"]="${dataStr%%|*}"; dataStr="${dataStr#*|}"
				clientData["${response}.products"]="${dataStr%%|*}"; dataStr="${dataStr#*|}"
				clientData["${response}.productsInSupport"]="${dataStr%%|*}"; dataStr="${dataStr#*|}"
				local envsStr="${grepStr##*|}" envStr prevEnvsStr envs clientDataKeys

				while [[ true ]]; do
					local envStr="${envsStr%%;*}"; envsStr="${envsStr#*;}"
					local env="${envStr%%-*}"; envStr="${envStr#*-}"
					local envs="$envs,$env"
					local host="${envStr%%/*}"; envStr="${envStr#*/}"
					clientData["${response}.${env}.host"]="$host"
					envStr="${envStr/\#/|}"
					local server="${envStr%%|*}"; envStr="${envStr#*|}"
					clientData["${response}.${env}.server"]="$server"
					local cims="$envStr"; [[ $cims == 'NULL' ]] && unset cims
					clientData["${response}.${env}.cims"]="$cims"
					[[ $env == test ]] && clientData["${response}.${env}.siteDir"]="/mnt/$server/${response}-test/$env" || \
											clientData["${response}.${env}.siteDir"]="/mnt/$server/$response/$env"
					[[ ! -d ${clientData["${response}.${env}.siteDir"]} ]] && unset clientData["${response}.${env}.siteDir"]
					[[ $envsStr == $prevEnvsStr ]] && break || prevEnvsStr="$envsStr"

				done
				## Do we have a pvt site, use dev info if we have it
				unset pvtDir
				if [[ ${clientData["${response}.dev.host"]} == $hostName && ${clientData["${response}.dev.server"]+abc} ]]; then
					[[ -d /mnt/${clientData["${response}.dev.server"]}/web/${response}-${userName} ]] && 
						pvtDir="/mnt/${clientData["${response}.dev.server"]}/web/${response}-${userName}"

					clientData["${response}.pvt.host"]="${clientData["${client}.dev.host"]}"
					clientData["${response}.pvt.server"]="${clientData["${client}.dev.server"]}"
					if [[ -r "$pvtDir/.clonedFrom" ]]; then 
						clonedFrom="$(cat "$pvtDir/.clonedFrom")"
						clientData["${response}.pvt.clonedFrom"]="$clonedFrom"
						clientData["${response}.pvt.cims"]="${clientData["${response}.${clonedFrom}.cims"]}"
					fi
					clientData["${response}.pvt.siteDir"]="$pvtDir"
					envs="$envs,pvt"
				else
					## Search for pvt dir
					for server in ${devServers//,/ }; do
						dump -3 -t server
						[[ -d "/mnt/$server/web/$response-$userName" ]] && { pvtDir="/mnt/$server/web/$response-$userName"; break; }
					done
					if [[ -n $pvtDir ]]; then
						clientData["${response}.pvt.host"]="$hostName"
						clientData["${response}.pvt.server"]="$server"
						if [[ -r "$pvtDir/.clonedFrom" ]]; then 
							clonedFrom="$(cat "$pvtDir/.clonedFrom")"
							clientData["${response}.pvt.clonedFrom"]="$clonedFrom"
							clientData["${response}.pvt.cims"]="${clientData["${response}.${clonedFrom}.cims"]}"
						fi
						clientData["${response}.pvt.siteDir"]="$pvtDir"
						envs="$envs,pvt"
					fi
				fi
				clientData["${response}.host"]="$host"
				clientData["${response}.envs"]="${envs:1}"
			else
				verifyMsg="$(Error "Client value of '$response' not found in '$workwithDataFile'")"
			fi
			## OK found client, now make sure it is valid for the current host
			if [[ $verifyMsg == "" ]]; then
				if [[ $anyClient != 'true' ]]; then
					if [[ ${clientData["${response}.host"]+abc} && ${clientData["${response}.host"]} != $hostName ]]; then
						if [[ $verify == true ]]; then
							if [[ $autoRemote != true ]]; then
								responseSave="$response"
								unset ans; Prompt ans "Client '$response' is hosted on '${clientData["${response}.host"]}', \
													Do you wish to start a session on that host" 'Yes No' 'Yes'
								ans="${ans:0:1}"; ans=${ans,,[a-z]}
								[[ $ans == 'n' ]] && Quit
								response="$responseSave"
							else
								ans='y'
							fi
						else
							verifyMsg="$(Error "Client value of '$response' is not valid on this host ('$hostName') it is hosted on '${clientData["${response}.host"]}' ")"
							[[ $autoRemote == true ]] && { ans=y; unset verifyMsg; } || { ans=n; }
						fi
						if [[ $ans == 'y' ]]; then
							Msg; Info "Starting ssh session to host '${clientData["${response}.host"]}', enter your credentials if prompted...";
							[[ $(Contains "$originalArgStr" "$response") == false ]] && commandStr="$response $originalArgStr" || commandStr="$originalArgStr"
							ssh "${userName}@${clientData["${response}.host"]}" $myName $commandStr
							Msg; Info "Back from remote ssh session\n"
							Goodbye 0
						fi ## [[ $ans == 'y' ]]
					fi ## Have host value != current host
				fi ## [[ $anyClient != 'true' ]]
			fi ## [[ $verifyMsg == "" ]]
		fi ## [[ ${response:0:1} == '?' ]];
		[[ -z $verifyMsg ]] && verifyMsg=true
	fi ## Client

	## Envs(s)
	if [[ $${promptVar:0:3} == 'env' && -z $verifyMsg ]]; then
		local answer=${response,,[a-z]}
		if [[ $allowMultiple != true && $(Contains "$answer" ",") == true ]]; then
			verifyMsg=$(Error "$promptVar' does not allow for multiple values, valid values is one in {$validateList}")
		else
			local i j found foundAll=true badList
			for i in $(tr ',' ' ' <<< $answer); do
				found=false
				for j in $(tr ',' ' ' <<< $validateList); do
					[[ $i == ${j:0:${#i}} ]] && found=true && break;
				done
				if [[ $found == false ]]; then
					badList="$badList,$i"
					foundAll=false
				fi
			done
			if [[ $foundAll == false ]]; then
				[[ -n $badList ]] && badList=${badList:1}
				verifyMsg=$(Error "Value of '$(ColorE "$badList")' not valid for '$promptVar', valid values in $(ColorK "{$validateList}")")
			fi
		fi
		[[ -z $verifyMsg ]] && verifyMsg=true
	fi ## Envs(s)

	## Product(s)
	if [[ ${promptVar:0:7} == 'product' && -z $verifyMsg ]]; then
		if [[ -z $validateList ]]; then
			if [[ -n $client ]]; then
				local sqlStmt="select products from $clientInfoTable where name='$client'"
				RunSql "$sqlStmt"
				[[ ${#resultSet[@]} -gt 0 && -n ${resultSet[0]} ]] && validateList="${resultSet[0]}"
			fi
		fi
		local ans=${response,,[a-z]}
		if [[ $allowMultiple != true && $(Contains "$ans" ",") == true ]]; then
			verifyMsg=$(Error "$promptVar' does not allow for multiple values, valid values is one in ${validateList// /, }")
		else
			[[ $ans == 'all' || $ans == 'a' ]] && { ans="${validateList// all/}"; ans="${ans// /,}"; response="$ans"; }
			local i j found foundAll=false
			for i in $(tr ',' ' ' <<< $ans); do
				found=false
				for j in $(tr ',' ' ' <<< $validateList); do
					[[ $i == $j ]] && found=true && break;
				done
				[[ $found == false ]] && foundAll=false || foundAll=true
			done
			if [[ $foundAll == false ]]; then
				if [[ $allowExtraProducts == true ]]; then
					unset ans
					echo -n -e "\tYou have specified a product not on this clients product list, please confirm this is correct (Yes, No)>"
					read ans; ans="${ans:0:1}"; ans=${ans,,[a-z]}
					[[ $ans == 'x' ]] && Goodbye 'x'
					[[ $ans == 'y' ]] && foundAll=true
				fi
			fi
			[[ $foundAll == false ]] && verifyMsg=$(Error "Value of '$response' not valid for '$promptVar', valid values in {${validateList// /, }} (1)")
		fi
		[[ -z $verifyMsg ]] && verifyMsg=true
	fi ## Product(s)

	## File
	if [[ $(Contains "$validateListString" '*file*') == true && -z $verifyMsg ]]; then
		[[ ! -r $response ]] && verifyMsg=$(Error "File '$response' does not exist") || unset validateListString
		[[ -z $verifyMsg ]] && verifyMsg=true
	fi ## File

	## Dir
	if [[ $(Contains "$validateListString" '*dir*') == true && -z $verifyMsg ]]; then
		[[ ! -d $response ]] && verifyMsg=$(Error "Directory '$response' does not exist") || unset validateListString
		[[ -z $verifyMsg ]] && verifyMsg=true
	fi ## Dir

	## isNumeric
	if [[ $(Contains "$validateListString" '*isNumeric*') == true && -z $verifyMsg ]]; then
		[[ $(IsNumeric "$response") != true ]] && verifyMsg=$(Error "Response must be numeric characters") || unset validateListString
		[[ -z $verifyMsg ]] && verifyMsg=true
	fi ## isNumeric

	## isAlpha
	if [[ $(Contains "$validateListString" '*isAlpha*') == true && -z $verifyMsg ]]; then
		[[ $(IsAlpha "$response") != true ]] && verifyMsg=$(Error "Response must be alpahbetic characters") || unset validateListString
		[[ -z $verifyMsg ]] && verifyMsg=true
	fi ## isAlpha

	## Everything else
	if [[ -z $verifyMsg ]]; then
		if [[ -z $validateListString ]]; then
			eval $promptVar=$response
		else
			local answer=${response,,[a-z]}
			local length token checkStr foundAll found
			## If allow multiples are allowed then loop throug responses and check each against valid values
			if [[ $allowMultiple == true ]]; then
				foundAll=true
				for token in $(tr ',' ' ' <<< "$answer"); do
					length=${#token}
					found=false
					for i in "${validValues[@]}"; do
						checkStr=${i:0:$length}; checkStr=${checkStr,,[a-z]}
						[[ $token == $checkStr ]] && found=true && break
					done
					[[ $found != true ]] && foundAll=false && break
				done
				[[ $foundAll == true ]] && PopSettings && verifyMsg=true && SetFileExpansion && return 0
			else  ## Single valued answer
				length=${#answer}
				for i in "${validValues[@]}"; do
					[[ $i == '*any*' ]] && PopSettings && verifyMsg=true && SetFileExpansion && return 0
					checkStr=${i:0:$length}; checkStr=${checkStr,,[a-z]}
					dump -3 -l -t -t answer length i checkStr
					[[ $answer == $checkStr ]] && PopSettings && verifyMsg=true && SetFileExpansion && return 0
				done
			fi
			verifyMsg=$(Error "Value of '$response' not valid for '$promptVar', valid values in {$validateListString} (2)")
		fi
		processedRequest=true
	fi ## Everything else

	[[ -z $verifyMsg ]] && verifyMsg=true
	SetFileExpansion
	PopSettings "$FUNCNAME"
	return 0

} #VerifyPromptVal
export -f VerifyPromptVal

#===================================================================================================
# Check-in Log
#===================================================================================================
## Wed Jan  4 13:54:39 CST 2017 - dscudiero - General syncing of dev to prod
## Mon Mar  6 15:55:11 CST 2017 - dscudiero - Tweak product parsing
## 03-30-2017 @ 15.06.14 - ("2.0.35")  - dscudiero - switch from runsql to RunSql
## 04-04-2017 @ 13.17.36 - ("2.0.46")  - dscudiero - Added support to verify multi value responses
## 04-05-2017 @ 10.08.43 - ("2.0.47")  - dscudiero - Turn off debug statements
## 05-19-2017 @ 14.38.31 - ("2.0.49")  - dscudiero - Set global client record when we look up client
## 05-19-2017 @ 14.40.06 - ("2.0.50")  - dscudiero - General syncing of dev to prod
## 05-22-2017 @ 09.12.16 - ("2.0.51")  - dscudiero - Added isNumeric and isAlpha types
## 05-22-2017 @ 09.16.07 - ("2.0.52")  - dscudiero - General syncing of dev to prod
## 09-22-2017 @ 07.18.50 - ("2.0.53")  - dscudiero - Include StartRemoteSession
## 09-29-2017 @ 16.09.19 - ("2.0.54")  - dscudiero - Add RunSql to includes
## 10-19-2017 @ 16.21.56 - ("2.0.55")  - dscudiero - Replace Msg2 with Msg
## 11-21-2017 @ 10.43.07 - ("2.0.56")  - dscudiero - Cosmetic/minor change
## 12-01-2017 @ 09.14.37 - ("2.0.59")  - dscudiero - Tweak messaging for do you want to start remote session
## 12-04-2017 @ 11.18.38 - ("2.0.63")  - dscudiero - Fix issue with the automagic ssh to other server
## 12-20-2017 @ 14.17.07 - ("2.0.65")  - dscudiero - Add PushPop to the includes list
## 03-22-2018 @ 13:42:51 - 2.0.73 - dscudiero - Updated for Msg/Msg, RunSql2/RunSql, ParseArgStd/ParseArgStd2
## 03-23-2018 @ 16:30:57 - 2.0.74 - dscudiero - D
## 03-23-2018 @ 17:04:35 - 2.0.75 - dscudiero - Msg3 -> Msg
## 03-26-2018 @ 15:51:40 - 2.0.76 - dscudiero - Switched from StartRemoteSession to just ssh
## 05-03-2018 @ 14:21:25 - 2.0.78 - dscudiero - Fix issue setting validValues in the products section
## 05-08-2018 @ 11:53:16 - 2.0.86 - dscudiero - Update how we deal with 'all' answers for products
## 05-29-2018 @ 13:20:53 - 2.0.90 - dscudiero - Refactored to limite direct usage of the data warehouse
## 05-30-2018 @ 11:58:56 - 2.0.91 - dscudiero - Do not check .clonedFrom file if not found
## 05-30-2018 @ 12:10:35 - 2.0.92 - dscudiero - Fix problem setting the pvt siteDir
## 05-31-2018 @ 15:46:49 - 2.0.93 - dscudiero - Fix problem setting pvt site name
## 06-04-2018 @ 08:51:41 - 2.0.95 - dscudiero - Change the way 'all' as an answer for products is processed
## 06-04-2018 @ 09:14:27 - 2.0.96 - dscudiero - Tweak includes
## 06-05-2018 @ 11:10:39 - 2.0.96 - dscudiero - Cosmetic/minor change/Sync
## 06-06-2018 @ 07:53:07 - 2.0.96 - dscudiero - Cosmetic/minor change/Sync
## 06-06-2018 @ 10:50:58 - 2.0.96 - dscudiero - Skip checking for client if noCheck is on
## 06-08-2018 @ 08:00:31 - 2.0.99 - dscudiero - Add debug
## 06-08-2018 @ 08:11:02 - 2.1.1 - dscudiero - Add debug
## 06-08-2018 @ 08:16:44 - 2.1.2 - dscudiero - Add debug
## 06-08-2018 @ 08:19:50 - 2.1.3 - dscudiero - Cosmetic/minor change/Sync
## 06-08-2018 @ 08:27:02 - 2.1.4 - dscudiero - Cosmetic/minor change/Sync
## 06-08-2018 @ 08:52:18 - 2.1.6 - dscudiero - Remove debug code
## 06-13-2018 @ 13:50:15 - 2.1.10 - dscudiero - Added code to set client pvt data if the client does not have a dev site
## 06-19-2018 @ 12:28:38 - 2.1.10 - dscudiero - Fix bug finding the pvt site if there is no dev site
## 06-27-2018 @ 12:13:44 - 2.1.10 - dscudiero - Comment out the version= line
