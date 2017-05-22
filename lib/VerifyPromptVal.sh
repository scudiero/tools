## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.52" # -- dscudiero -- Mon 05/22/2017 @  9:16:01.00
#===================================================================================================
# Verify result value
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function VerifyPromptVal {
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
	if [[ $promptVar == 'client' && $verifyMsg == '' ]]; then
		if [[ $response == '*' || $response == 'all' ]]; then
			[[ $response == '*' ]] && response='all'
			eval $promptVar=$response
			verifyMsg=true
			SetFileExpansion
			PopSettings "$FUNCNAME"
			return 0
		elif [[ ${response:0:1} == '?' ]]; then
			SelectClient 'response'
		elif [[ ${response:0:1} == '<' ]]; then
			response=${response:1}
			lenResponse=${#response}
			response=${response:0:$lenResponse-1}
			checkClient=false
		else
			## Look for client in the clients table
			SetFileExpansion 'off'
			local sqlStmt="select * from $clientInfoTable where name=\"$response\" "
			RunSql2 $sqlStmt
			if [[ ${#resultSet[@]} -eq 0 ]]; then
				verifyMsg="$(Msg2 $E "Client value of '$response' not found in $warehouseDb.$clientInfoTable")"
			else
				ClientData="${resultSet[0]}"
			fi
			SetFileExpansion
			## OK found client, now make sure it is valid for the current host
			if [[ $verifyMsg == "" ]]; then
				if [[ $anyClient != 'true' ]]; then
					sqlStmt="select host from $siteInfoTable where name=\"$response\""
					RunSql2 $sqlStmt
					[[ ${#resultSet[0]} -eq 0 ]] && verifyMsg="$(Msg2 $E "Could not retrieve any records for '$response' in the $warehouseDb.$siteInfoTable")"
					if [[ $verifyMsg == "" ]]; then
						hostedOn="${resultSet[0]}"
						if [[ $hostedOn != $hostName ]]; then
							if [[ $verify == true ]]; then
								if [[ $autoRemote == false ]]; then
									responseSave="$response"
									unset ans; Prompt ans "Client '$response' is hosted on '$hostedOn', Do you wish to start a session on that host" 'Yes No' 'Yes'; ans=$(Lower ${ans:0:1})
									response="$responseSave"
								else
									ans='y'
								fi
								if [[ $ans == 'y' ]]; then
									Msg2; Msg2 $I "Starting ssh session to host '$hostedOn', enter credentials and then 'exit' to return to '$hostName'...";
									[[ $(Contains "$originalArgStr" "$response") == false ]] && commandStr="$response $originalArgStr" || commandStr="$originalArgStr"
									StartRemoteSession "${userName}@${hostedOn}" $myName $commandStr
									Msg2; Msg2 $I "Back from remote ssh session"; Msg2
									Goodbye 0
								fi ## [[ $ans == 'y' ]]
							else
								ans='n'
							fi
							[[ $ans != 'y' ]] && verifyMsg="$(Msg2 $E "Client value of '$response' is not valid on this host ('$hostName') it is hosted on '$hostedOn' ")"
						fi ## [[ $hostedOn != $hostName ]]
					fi ## [[ $verifyMsg == "" ]]
				fi ## [[ $anyClient != 'true' ]]
			fi ## [[ $verifyMsg == "" ]]
		fi ## [[ ${response:0:1} == '?' ]];
		[[ $verifyMsg == '' ]] && verifyMsg=true
	fi ## Client

	## Envs(s)
	if [[ $${promptVar:0:3} == 'env' && $verifyMsg == '' ]]; then
		local answer=$(Lower $response)
		if [[ $allowMultiple != true && $(Contains "$answer" ",") == true ]]; then
			verifyMsg=$(Msg2 $E "$promptVar' does not allow for multiple values, valid values is one in {$validateList}")
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
				[[ $badList != '' ]] && badList=${badList:1}
				verifyMsg=$(Msg2 $E "Value of '$(ColorE "$badList")' not valid for '$promptVar', valid values in $(ColorK "{$validateList}")")
			fi
		fi
		[[ $verifyMsg == '' ]] && verifyMsg=true
	fi ## Envs(s)

	## Product(s)
	if [[ ${promptVar:0:7} == 'product' && $verifyMsg == '' ]]; then
		validProducts='cat,cim,clss'
		if [[ $client != '' ]]; then
			local sqlStmt="select products from $clientInfoTable where name='$client'"
			RunSql2 "$sqlStmt"
			[[ ${#resultSet[@]} -gt 0 ]] && validProducts="${resultSet[0]}"
		fi

		local ans=$(Lower $response)
		if [[ $allowMultiple != true && $(Contains "$ans" ",") == true ]]; then
			verifyMsg=$(Msg2 $E "$promptVar' does not allow for multiple values, valid values is one in {$validProducts}")
		else
			[[ $ans == 'all' ]] && ans="$validProducts" && response="$ans"
			local i j found foundAll=false
			for i in $(tr ',' ' ' <<< $ans); do
				found=false
				for j in $(tr ',' ' ' <<< $validProducts); do
					[[ $i == $j ]] && found=true && break;
				done
				[[ $found == false ]] && foundAll=false || foundAll=true
			done
			if [[ $foundAll == false ]]; then
				if [[ $allowExtraProducts == true ]]; then
					unset ans
					echo -n -e "\tYou have specified a product not on this clients product list, please confirm this is correct (Yes, No)>"
					read ans
					[[ $(Lower ${ans}) == 'x' ]] && Goodbye 'x'
					[[ $ans == 'y' ]] && foundAll=true
				fi
			fi
			[[ $foundAll == false ]] && verifyMsg=$(Msg2 $E "Value of '$response' not valid for '$promptVar', valid values in {$validProducts}")
		fi
		[[ $verifyMsg == '' ]] && verifyMsg=true
	fi ## Product(s)

	## File
	if [[ $(Contains "$validateListString" '*file*') == true && $verifyMsg == '' ]]; then
		[[ ! -r $response ]] && verifyMsg=$(Msg2 $E "File '$response' does not exist") || unset validateListString
		[[ $verifyMsg == '' ]] && verifyMsg=true
	fi ## File

	## Dir
	if [[ $(Contains "$validateListString" '*dir*') == true && $verifyMsg == '' ]]; then
		[[ ! -d $response ]] && verifyMsg=$(Msg2 $E "Directory '$response' does not exist") || unset validateListString
		[[ $verifyMsg == '' ]] && verifyMsg=true
	fi ## Dir

	## isNumeric
	if [[ $(Contains "$validateListString" '*isNumeric*') == true && $verifyMsg == '' ]]; then
		[[ $(IsNumeric "$response") != true ]] && verifyMsg=$(Msg2 $E "Response must be numeric characters") || unset validateListString
		[[ $verifyMsg == '' ]] && verifyMsg=true
	fi ## isNumeric

	## isAlpha
	if [[ $(Contains "$validateListString" '*isAlpha*') == true && $verifyMsg == '' ]]; then
		[[ $(IsAlpha "$response") != true ]] && verifyMsg=$(Msg2 $E "Response must be alpahbetic characters") || unset validateListString
		[[ $verifyMsg == '' ]] && verifyMsg=true
	fi ## isAlpha

	## Everything else
	if [[ $verifyMsg == '' ]]; then
		if [[ $validateListString == '' ]]; then
			eval $promptVar=$response
		else
			local answer=$(Lower $response)
			local length token checkStr foundAll found
			## If allow multiples are allowed then loop throug responses and check each against valid values
			if [[ $allowMultiple == true ]]; then
				foundAll=true
				for token in $(tr ',' ' ' <<< "$answer"); do
					length=${#token}
					found=false
					for i in "${validValues[@]}"; do
						checkStr=$(Lower ${i:0:$length})
						[[ $token == $checkStr ]] && found=true && break
					done
					[[ $found != true ]] && foundAll=false && break
				done
				[[ $foundAll == true ]] && PopSettings && verifyMsg=true && SetFileExpansion && return 0
			else  ## Single valued answer
				length=${#answer}
				for i in "${validValues[@]}"; do
					[[ $i == '*any*' ]] && PopSettings && verifyMsg=true && SetFileExpansion && return 0
					checkStr=$(Lower ${i:0:$length})
					dump -3 -l -t -t answer length i checkStr
					[[ $answer == $checkStr ]] && PopSettings && verifyMsg=true && SetFileExpansion && return 0
				done
			fi
			verifyMsg=$(Msg2 $E "Value of '$response' not valid for '$promptVar', valid values in {$validateListString}")
		fi
		processedRequest=true
	fi ## Everything else

	[[ $verifyMsg == '' ]] && verifyMsg=true
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
## 03-30-2017 @ 15.06.14 - ("2.0.35")  - dscudiero - switch from runsql to runsql2
## 04-04-2017 @ 13.17.36 - ("2.0.46")  - dscudiero - Added support to verify multi value responses
## 04-05-2017 @ 10.08.43 - ("2.0.47")  - dscudiero - Turn off debug statements
## 05-19-2017 @ 14.38.31 - ("2.0.49")  - dscudiero - Set global client record when we look up client
## 05-19-2017 @ 14.40.06 - ("2.0.50")  - dscudiero - General syncing of dev to prod
## 05-22-2017 @ 09.12.16 - ("2.0.51")  - dscudiero - Added isNumeric and isAlpha types
## 05-22-2017 @ 09.16.07 - ("2.0.52")  - dscudiero - General syncing of dev to prod
