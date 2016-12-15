#!/bin/bash
#==================================================================================================
version=1.7.67 # -- dscudiero -- 12/14/2016 @ 11:30:00.93
#==================================================================================================
TrapSigs 'on'
imports='GetDefaultsData ParseArgs ParseArgsStd Hello Init Goodbye SelectMenuNew ParseCourseleafFile'
imports="$imports WriteChangelogEntry"
Import "$imports"
originalArgStr="$*"
scriptDescription="Patch Courseleaf - dispatcher"

#= Description +===================================================================================
# Display a list of patch scripts & execute
#==================================================================================================

#==================================================================================================
# Standard call back functions
#==================================================================================================
	function parseArgs-patchCourseleaf  {
		argList+=(-patch,2,option,patchId,,script,"Patch Id of the patch to apply, see '$TOOLSPATH/$myName.tcf'")
		argList+=(-excludeList,2,option,excludeList,,script,"Comma sperated list of sites to exclude from processing, format for each is '<siteName>/<env>'. Note that if it is a test site you MUST include the '-test' in <siteName>")
	}
	function Goodbye-patchCourseleaf  {
		return 0
	}
	function testMode-patchCourseleaf  {
		emailAddrs="$userName@leepfrog.com"
		return 0
	}

#==================================================================================================
# Local Subroutiens
#==================================================================================================

#==================================================================================================
# Declare local variables and constants
#==================================================================================================
patchOutDays=$scriptData1
[[ $patchOutDays == '' ]] && patchOutDays=7
sendMail=false
foldCols=100

unset prePatchEmailPrefix prePatchEmailSuffix
prePatchEmailPrefix+=("The following TEST sites have been patch in advance of a wider application of the")
prePatchEmailPrefix+=("patch to the NEXT sites.")

prePatchEmailSuffix+=("If you have any concerns or should you notice anomalies with a site that you believe might be related")
prePatchEmailSuffix+=("to the patch please contact $(getent passwd $userName | cut -d':' -f5) ($userName@leepfrog.com)")
prePatchEmailSuffix+=("")
prePatchEmailSuffix+=("Note that the plan is to apply this patch to the effected NEXT sites on $(date --date="+$patchOutDays day" +"%a %b %d, %Y ")")

unset postPatchEmailPrefix postPatchEmailSuffix
postPatchEmailPrefix+=("As per the previous notification sent out on $(date --date="-$patchOutDays day" +"%a %b %d, %Y ")")
postPatchEmailPrefix+=("The following NEXT sites have had the above patched applied")

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
helpSet='script,client,envs'
scriptHelpDesc="This script can be used to patch on or more couseleaf instances.\
\n\tPatches are defined in the '$courseleafPatchTable' table in the data warehouse and can be defined using the 'new' script.\
\n\nEdited/changed files will be backed up to the /attic and actions will be logged in the /changelog.txt file."

GetDefaultsData $myName
ParseArgsStd
displayGoodbyeSummaryMessages=true
Hello
Init "getClient"
Init "getEnvs checkEnv getDirs noCheck noPreview noPublic"
patchIdIn=$patchId

## Set arguments to called scripts
addedCalledScriptArgs="-secondaryMessagesOnly"
[[ $verbose == true ]] && addedCalledScriptArgs="$addedCalledScriptArgs -v$verboseLevel"
[[ $DOIT != '' ]] && addedCalledScriptArgs="$addedCalledScriptArgs -x"
[[ $informationOnlyMode == true ]] && addedCalledScriptArgs="$addedCalledScriptArgs -information"

#==================================================================================================
# Main
#==================================================================================================
## Get a list of avaiable patches from db
	fields="idx,shortDescription,longDescription,requester,clVersion,cgiVersion,script,createdOn"
	sqlStmt="Select $fields from $courseleafPatchTable where status=\"active\" order by idx"
	RunSql 'mysql' "$sqlStmt"
	#echo '${#resultSet[@]} = >'${#resultSet[@]}'<'
	[[ ${#resultSet[@]} -eq 0 ]] && Msg "T No records returned from source database"
	for result in "${resultSet[@]}"; do
	 	resultString=$result; resultString=$(echo "$resultString" | tr "\t" "|" )
	 	dump -1 resultString
	 	patchId="$(cut -d'|' -f1 <<< $resultString)"
		patchList["$patchId"]="$(cut -d'|' -f2- <<< $resultString)"
		patchKeys+=("$patchId")
	done

unset patchId
## If patch id was passed in then use it , otherwise display menu
	if [[ $patchIdIn != '' && ${patchList[patchIdIn]+abc} ]]; then
		patchShortDesc=$(cut -d'|' -f1 <<< "${patchList[$patchIdIn]}")
		patchLongDesc=$(cut -d'|' -f2 <<< "${patchList[$patchIdIn]}")
		patchReq=$(cut -d'|' -f3 <<< "${patchList[$patchIdIn]}")
		tmpStr="$(cut -d'|' -f7 <<< ${patchList[$patchIdIn]})"  #
		patchDate="$(cut -d' ' -f1 <<< $tmpStr)"
		Msg "N Using patchId: $patchIdIn ($patchShortDesc / $patchReq / $patchDate)"
		patchId="$patchIdIn"
		dump -1 patchId patchDesc patchDate patchWho
	fi

if [[ $patchId == '' ]]; then
	## Get the patch script to run
	if [[ $verify != true ]]; then Msg "T No value specified for patchId and verify is off"; fi
	## Build the menuList
		unset menuList menuItem
		menuList+=("|Description|Patch Date|Requester|Id")
		for i in "${patchKeys[@]}"; do
			#echo '${patchList[$i]} =>'${patchList[$i]}'<'
			menuItem="|$(cut -d'|' -f1 <<< ${patchList[$i]})"  #Description
			tmpStr="$(cut -d'|' -f7 <<< ${patchList[$i]})"  #Date
			menuItem="${menuItem}|$(cut -d' ' -f1 <<< $tmpStr)"
			menuItem="${menuItem}|$(cut -d'|' -f3 <<< ${patchList[$i]})" #Requester
			menuItem="${menuItem}|$i"
			menuList+=("$menuItem")
		done
		Msg2
		Msg2 "Please select the patch that you wish to apply, enter the ordinal number:"
		Msg2
		SelectMenuNew 'menuList' 'patchId' "\nPatch ordinal number $(ColorK '(ord)') (or 'x' to quit) > "
		[[ $patchId == '' ]] && Goodbye 0 || patchId=$(cut -d'|' -f1 <<< $patchId)
		patchId=$(echo "${menuList[$patchId]}" | cut -d'|' -f5)
fi
dump -1 patchId
[[ $verboseLevel -ge 1 ]] && echo 'patchList["$patchId"] = >'${patchList["$patchId"]}'<'

## parse the patch information
	dump -1 patchId; [[ $verboseLevel -ge 1 ]] && echo '${patchList[$patchId]} = >'${patchList[$patchId]}'<'
	#description|requester|clVersion|cgiVersion|date"
	#Insert structuredcontent:embedtab|jlinderman|3.6.8|9.2.50|2015-12-23 00:00:00
	patchString="${patchList[$patchId]}"
	patchShortDesc=$(echo $patchString | cut -d'|' -f1 )
	patchLongDesc=$(echo $patchString | cut -d'|' -f2 )
	[[ $patchLongDesc == 'NULL' ]] && unset patchLongDesc
	patchMinClver=$(echo $patchString | cut -d'|' -f4 )
	[[ $patchMinClver == 'NULL' ]] && unset patchMinClver
	patchMinCgiver=$(echo $patchString | cut -d'|' -f5 )
	[[ $patchMinCgiver == 'NULL' ]] && unset patchMinCgiver
	patchScript=$(echo $patchString | cut -d'|' -f6 )
	dump -1 patchString patchShortDesc patchLongDescpatchMinClver patchMinCgiver patchScript

## Verify user wants to continue
	unset verifyArgs
	verifyArgs+=("Client:$client")
	verifyArgs+=("Patch Id:$patchId -- $patchShortDesc")
	[[ $patchMinClver != '' ]] && verifyArgs+=("Patch Min Clver:$patchMinClver")
	[[ $patchMinCgiver != '' ]] && verifyArgs+=("Patch Min Cgiver:$patchMinCgiver")
	[[ $envs != '' ]] && verifyArgs+=("Envs:$(Upper $envs)")
	[[ $excludeList != '' ]] && verifyArgs+=("Exclude:$excludeList")
	# [[ $(Contains "$envs" "test") == true && $(Contains "$envs" "next") != true && informationOnlyMode != true ]] && verifyArgs+=("Notification Email:Pre-Patch")
	# [[ $(Contains "$envs" "next") == true && informationOnlyMode != true ]] && verifyArgs+=("Notification Email:Patch")
	VerifyContinue "You are asking to patch ALL files:"

	[[ ${envs:0:1} == ',' ]] && envs=${envs:1}
	myData="patchId: '$patchId', envs: '$envs', patchAction: '$patchAction patchFile: '$patchFile'"
	[[ $logInDb != false && $myLogRecordIdx != "" && $testMode != true ]] && dbLog 'data' $myLogRecordIdx "$myData"

## Run the worker script
	Msg2
	unset patchedSiteDirs
	## Get the executable
	FindExecutable "$patchScript" "std" 'Bash:sh' 'patches' ## Sets variable executeFile

	## Run the patch script on each system
	source $executeFile "$client" "$envs" "$patchId" $addedCalledScriptArgs
	for host in $(tr ',' ' ' <<< $linuxHosts); do
		[[ $host == $(cut -d'.' -f1 <<< $(hostname)) ]] && continue
		Msg2; Msg2
		StartRemoteSession "${userName}@${host}" $DISPATCHER $executeFile "$client" "$envs" "$patchId" $addedCalledScriptArgs
	done

## Send out notifications
	## Which emails to send out
		if [[ $(Contains "$envs" "test") == true && $(Contains "$envs" "next") != true ]]; then
			subj="Pre-Patch notification"
			emailPrefix=("${prePatchEmailPrefix[@]}")
			emailSuffix=("${prePatchEmailSuffix[@]}")
		elif [[ $(Contains "$envs" "next") == true ]]; then
			subj="Post-Patch notification"
			emailPrefix=("${postPatchEmailPrefix[@]}")
			emailSuffix=("${postPatchEmailSuffix[@]}")
		else
			sendMail=false
		fi

# 	[[ ${#patchedSiteDirs[@]} -gt 0 && $informationOnlyMode != true ]] && sendMail=true
# 	dump -1 noEmails sendMail
# 	if [[ $noEmails != true && $sendMail == true ]]; then
# 		tmpFile=$(mkTmpFile "$myName")
# 		## Build the email
# 			echo > $tmpFile
# 			echo -e "$subj: PatchId: $patchId -- $patchShortDesc -- \n" >> $tmpFile
# 			if [[ $patchLongDesc != '' ]]; then
# 				fold -sw $foldCols <<< $(echo "$patchLongDesc") > $tmpFile.1
# 				while read -r line; do
# 					echo -e "\t${line}" >> $tmpFile
# 				done < $tmpFile.1
# 				rm -f $tmpFile.1
# 				echo >> $tmpFile
# 			fi
# 			for line in "${emailPrefix[@]}" ; do
# 				echo "$line" >> $tmpFile
# 			done
# 			echo >> $tmpFile
# 			for line in "${patchedSiteDirs[@]}"; do
# 				echo -e "\t$(cut -d',' -f1 <<< $line)\t$(cut -d',' -f2 <<< $line)" >> $tmpFile
# 			done
# 			echo >> $tmpFile
# 			for line in "${emailSuffix[@]}"; do
# 				echo "$line" >> $tmpFile
# 			done

# 		## Send out the emails
# 			echo "set realname=\"$myName\"" > $tmpFile.2
# 			for emailAddr in $(echo $emailAddrs | tr ',' ' '); do
# 				$DOIT mutt -F $tmpFile.2 -s "$subj" -- $emailAddr < $tmpFile
# 			done
# 			rm -f $tmpFile.2

# 		Msg2; Msg2 "Sending '$subj' email to: \n^$(sed s"/,/, /g" <<< $emailAddrs)"
# 		[[ -f $tmpFile ]] && rm -f $tmpFile
# 	fi

#==================================================================================================
## Done
#==================================================================================================
Goodbye 0 #'alert'

#==================================================================================================
## Check-in log
#==================================================================================================
# 09-15-2015 -- dscudiero -- Driver program to install courseleaf patches (1.1)
# 10-16-2015 -- dscudiero -- Update for framework 6 (1.2)# 12-23-2015 -- dscudiero -- Refactored to do most of the work (1.4.0)
# 12-30-2015 -- dscudiero -- refactored, added more action types (1.5.2)
## Tue Mar 29 14:12:59 CDT 2016 - dscudiero - refactored
## Wed Mar 30 16:09:20 CDT 2016 - dscudiero - Update script calls
## Wed Apr 27 12:34:43 CDT 2016 - dscudiero - Completely refactored to source script and also format and send out notifications.
## Wed Apr 27 12:41:38 CDT 2016 - dscudiero - Tweak help text
## Wed Apr 27 14:22:17 CDT 2016 - dscudiero - do not send emails unless test or next
## Wed Apr 27 14:22:54 CDT 2016 - dscudiero - do not send emails unless test or next
## Wed Apr 27 15:02:14 CDT 2016 - dscudiero - Use DOIT to block actions of the -x flag was used on the call
## Wed Apr 27 16:08:14 CDT 2016 - dscudiero - Switch to use RunSql
## Thu Apr 28 08:35:07 CDT 2016 - dscudiero - General syncing of dev to prod
## Thu Apr 28 13:35:45 CDT 2016 - dscudiero - Added prompt line above list of patches
## Wed Jun 22 07:39:02 CDT 2016 - dscudiero - General syncing of dev to prod
## Thu Aug  4 11:01:11 CDT 2016 - dscudiero - Added displayGoodbyeSummaryMessages=true
## Tue Aug 23 11:21:53 CDT 2016 - dscudiero - Updated to correctly parse output of selectMenuNew
## Fri Oct 14 13:41:28 CDT 2016 - dscudiero - General syncing of dev to prod
