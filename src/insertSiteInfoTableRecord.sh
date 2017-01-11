#!/bin/bash
#==================================================================================================
version=1.1.108 # -- dscudiero -- 01/11/2017 @  9:51:23.67
#==================================================================================================
TrapSigs 'on'
imports='ParseCourseleafFile CleanString' #imports="$imports "
Import "$imports"
originalArgStr="$*"
scriptDescription="Create a record in the siteInfoTable"

#= Description +===================================================================================
# Create a record in the siteInfoTable, this is a helper script for 'buildSiteInfoTable' and is
# NOT MEANT TO BE CALLED STAND ALONE
# insertSiteInfoTableRecord $siteDir -clientId $clientId
#==================================================================================================
checkParent='buildsiteinfotable.sh'; calledFrom="$(Lower "$(basename "${BASH_SOURCE[2]}")")"
[[ $(Lower $calledFrom) != $(Lower $checkParent)  ]] && Terminate "Sorry, this script can only be called from '$checkParent', \nCurrent call parent: '$calledFrom' \nCall Stack: $(GetCallStack)"

#==================================================================================================
# Standard call back functions
#==================================================================================================
	function parseArgs-insertSiteInfoTableRecord {
		# argList+=(argFlag,minLen,type,scriptVariable,exCmd,helpSet,helpText)  #type in {switch,switch#,option,help}
		return 0
	}

#==================================================================================================
# local functions
#==================================================================================================

#==================================================================================================
# Standard argument parsing and initialization
#==================================================================================================
siteDir="$1" ; shift
clientId="$1"; shift
originalArgStr="$*"
ParseArgsStd "$*"

#==================================================================================================
# Declare local variables and constants
#==================================================================================================
share=$(cut -d '/' -f3 <<< $siteDir)
client=$(cut -d' ' -f1 <<< $(ParseCourseleafFile "$siteDir"))

shareType='prod'; suffix='/'; env=${siteDir##*/}
[[ ${share:0:3} == 'dev' ]] && shareType='dev' && suffix='/web/' && env='dev'
dump -2 -n -t siteDir share shareType client env clientId

#===================================================================================================
# Main
#===================================================================================================
[[ $DOIT != '' || $informationOnlyMode == true ]] && echo
Msg2 "^$env ($siteDir)"

## Insert the initial record to get the siteId set
	fields="siteId,name,clientId,env,host,share,redhatVer,createdOn,createdBy"
	if [[ $env == 'preview' || $env == 'public' ]]; then
		host='N/A'
		share='N/A'
	else
		host=$hostName
	fi
	valueStr="NULL,\"$client\",\"$clientId\",\"$env\",\"$host\",\"$share\",\"$myRhel\",now(),\"$userName\""
	sqlStmt="insert into $useSiteInfoTable ($fields) values($valueStr)"
	RunSql2 $sqlStmt
	## Get newly inserted siteid
	[[ ${#resultSet[@]} -eq 0 ]] && Terminate "Could not insert seed record into $useSiteInfoTable"
	siteId=${resultSet[0]}
	Msg2 $V2 "\tSiteId for $client is '$siteId'"

## lookup urls from the clients table
	if [[ $env == 'test' || $env == 'next' || $env == 'curr' ]]; then
		sqlStmt="select ${env}url,${env}InternalUrl from $clientInfoTable where idx=\"$clientId\" "
		RunSql2 $sqlStmt
		url=\"$(cut -d'|' -f1 <<< ${resultSet[0]})\"
		[[ $url == '"NULL"' ]] && url=NULL
		internalUrl=\"$(cut -d'|' -f2 <<< ${resultSet[0]})\"
		[[ $internalUrl == '"NULL"' ]] && internalUrl=NULL
	else
		sqlStmt="select ${env}url from $clientInfoTable where idx=\"$clientId\" "
		RunSql2 $sqlStmt
		url=\"${resultSet[0]}\"
		[[ $url == '"NULL"' ]] && url=NULL
		internalUrl=NULL
	fi
	dump -1 -t url internalUrl

## See if the site has google search installed
	unset googleType
	grepFile=$(dirname $siteDir)/$env/web/ribbit/fsinjector.rjs
	if [[ -f $grepFile ]]; then
		googleType=$(ProtectedCall "grep '^var googletype' $grepFile | grep -v null")
		[[ -n $googleType ]] && googleType=$(cut -d"=" -f2 <<< $googleType | tr -d "'" | tr -d ";" | tr -d " ")
	fi
	[[ -z $googleType ]] && googleType=NULL || googleType="\"$googleType\""
	dump -2 -t googletype

## Preview or Public -- Parse archives and write out a short record
	if [[ $env == 'preview' || $env == 'public' ]]; then
		unset archives archiveDir
		#Check to see if the curr or next sites have archive path set, if the do then lookup archive directories
		for checkEnv in next curr; do
			unset archiveRoot archiveDir
			# Get archive path from the next env.
			grepFile=$(dirname $siteDir)/$checkEnv/web/courseleaf/localsteps/default.tcf
			dump -2 -n checkEnv grepFile
			if [[ -f $grepFile ]]; then
				archiveRoot=$(cut -d":" -f2 <<< $(ProtectedCall "grep '^archiveroot:' $grepFile"));
				if [[ -n $archiveRoot ]]; then
					archiveRoot=$(tr -d "[:space:]" <<< $archiveRoot | tr -d "[:blank:]")
					dump -2 -t archiveRoot
					[[ ${archiveRoot:0:1} != '/' ]] && archiveRoot='/'$archiveRoot
					archiveDir=$(dirname $siteDir)/$env/web$archiveRoot
				else
					archivePath=$(cut -d":" -f2 <<< $(ProtectedCall "grep '^archivepath:' $grepFile"));
					archivePath=$(tr -d "[:space:]" <<< $archivePath | tr -d "[:blank:]")
					if [[ -n $archivePath ]]; then
						archivePath=$(tr -d "[:space:]" <<< $archivePath | tr -d "[:blank:]")
						dump -2 -t archivePath
						[[ ${archivePath:0:1} != '/' ]] && archivePath='/'$archivePath
						tmpStr=$(dirname $archivePath)
						[[ $tmpStr == '/' ]] && archiveRoot=$archivePath|| archiveRoot=$tmpStr
						archiveDir=$(dirname $siteDir)/$env/web$archiveRoot
					fi
				fi
				[[ -z $archiveDir ]] && archiveDir=$(dirname $siteDir)/$env/web/archive/
				dump -2 archiveDir
				if [[ -n $archiveDir && -d $archiveDir ]]; then
					cwd=$(pwd)
					cd $archiveDir
					SetFileExpansion 'on'; archives=$(ProtectedCall "ls -d */ 2> /dev/null"); SetFileExpansion 'off'
					archives="$(tr -d "[:space:]" <<< "${archives%?}" | tr -d "[:blank:]" | tr -s '/' ',')"
					cd $cwd
				fi
			fi
			[[ $archives != '' ]] && break
		done;
		## Check to see what archives are active
			[[ -z $archives ]] && archives=NULL || archives="\"$archives\""
			dump -2 archives
		## Write out the record
			setStr="url=$url,archives=$archives,googleType=$googleType"
			sqlStmt="update $useSiteInfoTable set $setStr where siteId=\"$siteId\""
			RunSql2 $sqlStmt
			return 0
	fi #[[ $env = 'preview' || $env = 'public' ]]

## NOT [[ $env = 'preview' || $env = 'public' ]]
	archives=NULL

## Get CIMS
	allCims=true
	GetCims $siteDir
	unset allCims
	[[ -n $cimStr ]] && cimStr=\"$(tr -d ' ' <<< $cimStr)\" || cimStr=NULL
	dump -2 -t cimStr

## Get the cimVer
	clverFile="$siteDir/web/courseleaf/cim/clver.txt"
	cimVer=NULL
	if [[ -r $clverFile ]]; then
		cimVer=$(cat $clverFile);
		cimVer=$(cut -d":" -f2 <<< $cimVer | tr -d '\040\011\012\015');
		[[ $cimVer != 'NULL' ]] && cimVer=\""$cimVer"\"
	fi
	[[ $cimVer != 'NULL' ]] && cimVer=\""$cimVer"\"
	dump -2 -t cimVer

## Get the catVer
	clverFile="$siteDir/web/courseleaf/clver.txt"
	defaultTcfFile="$siteDir/web/courseleaf/default.tcf"
	catVer=NULL
	if [[ -r $clverFile ]]; then
		catVer=$(cat $clverFile);
		catVer=$(cut -d":" -f2 <<< $catVer | tr -d '\040\011\012\015');
	elif [[ -f $defaultTcfFile ]]; then
		catVer=$(ProtectedCall "grep '^clver:' $defaultTcfFile");
		catVer=$(cut -d":" -f2 <<< $catVer | tr -d '\040\011\012\015');
	fi
	[[ -z $catVer ]] && catVer=NULL
	[[ $catVer != 'NULL' ]] && catVer=\""$catVer"\"
	dump -2 -t catVer

## Get the clssVer
	clverFile="$siteDir/web/wen/clver.txt"
	clssVer=NULL
	if [[ -r $clverFile ]]; then
		clssVer=$(cat $clverFile);
		clssVer=$(cut -d":" -f2 <<< $clssVer | tr -d '\040\011\012\015');
		[[ $clssVer != 'NULL' ]] && clssVer=\""$clssVer"\"
	fi
	[[ $clssVer != 'NULL' ]] && clssVer=\""$clssVer"\"
	dump -2 -t clssVer

## Get the cgiVersion
	courseleafCgiVer=NULL
	cgiFile="$siteDir/web/courseleaf/courseleaf.cgi"
	if [[ -x "$cgiFile" ]]; then
		courseleafCgiVer="$($cgiFile -v  2> /dev/null | cut -d" " -f3)"
	fi
	[[ $courseleafCgiVer != 'NULL' ]] && courseleafCgiVer=\""$courseleafCgiVer"\"
	dump -2 -t courseleafCgiVer

## Get the reportsVer
	reportsVer=NULL
	checkFile="$siteDir/web/courseleaf/localsteps/reports.js"
	if [[ -r "$checkFile" ]]; then
		reportsVer="$(ProtectedCall "grep -s -m 1 'version:' $checkFile")"
		reportsVer=${reportsVer##*: }
		reportsVer=$(CleanString "$reportsVer")
		[[ -z $reportsVer ]] && reportsVer=NULL
	fi
	[[ $reportsVer != 'NULL' ]] && reportsVer=\""$reportsVer"\"
	dump -2 -t reportsVer

	## Get daily.sh versions
		dailyshVer=NULL
		checkFile="$siteDir/bin/daily.sh"
		if [[ -r $checkFile ]]; then

			grepStr=$(ProtectedCall "grep '## Nightly cron job for client' $checkFile")
			if [[ -n $grepStr ]]; then
				dailyshVer=$(ProtectedCall "grep 'version=' $checkFile")
				dailyshVer=${dailyshVer##*=} ; dailyshVer=${dailyshVer%% *}
				[[ $dailyshVer != 'NULL' ]] && dailyshVer=\"$dailyshVer\"
			fi
		fi
		dump -2 -t dailyshVer

## Get the edition variable
	catEdition=NULL
	grepFile="$siteDir/web/courseleaf/localsteps/default.tcf"
	if [[ -f $grepFile ]]; then
		catEdition=$(cut -d":" -f2 <<< $(ProtectedCall "grep '^edition:' $grepFile") | tr -d '\040\011\012\015');
	fi
	[[ $catEdition != 'NULL' ]] && catEdition=\""$catEdition"\"
	dump -2 -t catEdition

## Get the publishing
	publishTarget=NULL
	if [[ "$env" = 'next' || "$env" = 'curr' ]]; then
		grepFile="$siteDir/courseleaf.cfg"
		if [[ -f $grepFile ]]; then
			mapfileProd=$(ProtectedCall "grep '^mapfile:production|' $grepFile");
			[[ $mapfileProd == '' ]] && mapfileProd=$(ProtectedCall "grep '^mapfile:production/|' $grepFile");
			if [[ $mapfileProd != '' ]]; then
				[[ $publishTarget == NULL ]] && publishTarget=$(cut -d'|' -f2 <<< $mapfileProd)
			fi
		fi
	fi
	[[ $publishTarget != 'NULL' ]] && publishTarget=\""$publishTarget"\"
	dump -2 -t publishTarget

## See if site has degree works tools enabled
	degreeWorks=NULL
	if [[ "$env" != 'preview' && "$env" != 'public' ]]; then
		grepFile="$siteDir/web/courseleaf/index.tcf"
		if [[ -f $grepFile ]]; then
			unset tempStr; tempStr=$(ProtectedCall "grep '^navlinks\:.*dworksenable' $grepFile")
			[[ -n $tempStr ]] && degreeWorks='Yes'
		fi
	fi
	[[ $degreeWorks != 'NULL' ]] && degreeWorks=\""$degreeWorks"\"
	dump -2 -t degreeWorks

## Retrieve site admins
	admins=NULL
	if [[ $quick != true ]]; then
		file="$siteDir/courseleaf.cfg"
		if [[ -r $file ]]; then
			## Check to see if we hava a clusers database and it is valid
				clUsersFile="$(dirname $file)/db/clusers.sqlite"
				haveClusers=false
				if [[ -r $clUsersFile ]]; then
					#sqlStmt='select * from sqlite_master;'
					sqlStmt='select * from sqlite_master where type="table" and name="users";'
					RunSql2 "$clUsersFile" "$sqlStmt"
					if [[ ${#resultSet[@]} -ne 0 ]]; then
						[[ $(Contains "${resultSet[0]}" ' userid ') == true && $(Contains "${resultSet[0]}" ' email ') == true ]] && haveClusers=true
					fi
				fi
			## Get email suffix from the config file
				grepStr=$(ProtectedCall "grep \"^emailsuffix:\" $file")
				[[ $grepStr != '' ]] && emailsuffix=$(cut -d':' -f2 <<< $grepStr | tr -d '\011\012\015') || unset emailsuffix
			## Get the user records from the config file, loop through the user records
				userRecs=($(ProtectedCall "\grep '^user:' $file | \grep admin | \grep -v cladmin | \grep -v clmig | \grep -v leepfrog"))
				if [[ ${#userRecs[@]} -ne 0 ]]; then
					unset admins
					for userRec in "${userRecs[@]}"; do
						userRec=$(tr -d '\011\012\015' <<< $userRec)
						dump -2 -n -t userRec
						#user:bfruscione||bfruscione@rider.edu|admin<
						adminId=$(cut -d':' -f2 <<< $userRec | cut -d '|' -f1 )
						adminEmail=$(cut -d '|' -f3 <<< $userRec)
						## If the email address is null then look up the email address in clusers
							if [[ $adminEmail == '' && $haveClusers == true ]]; then
								sqlStmt="select email from users where userid=\"$adminId\";"
								RunSql2 "$clUsersFile" "$sqlStmt"
								adminEmail="${resultSet[0]}"
							fi
						## If email is still null then set from the emailsuffix if it is not null
							[[ -z $adminEmail && -n $emailsuffix ]] && adminEmail="$adminId@$emailsuffix"
							[[ -n $adminEmail ]] && admins=$admins,$adminEmail || admins=$admins,$adminId
							dump -2 -t -t adminId adminEmail admins -n
					done
				fi
				## Write out the record to the siteadmins table
					if [[ -n $admins ]]; then
						admins=${admins:1}
						fields="idx,siteId,name,env,admins"
						sqlStmt="insert into $siteAdminsTable ($fields) values(NULL,\"$siteId\",\"$client\",\"$env\",\"$admins\")"
						RunSql2 $sqlStmt
					fi
		fi
	fi

## Create the sites table record
	setStr="catver=$catVer,cimver=$cimVer,clssVer=$clssVer,courseleafCgiVer=$courseleafCgiVer,reportsVer=$reportsVer,dailyshVer=$dailyshVer"
	setStr="$setStr,CIMs=$cimStr,url=$url,internalUrl=$internalUrl,archives=$archives,googleType=$googleType"
	setStr="$setStr,CATedition=$catEdition,publishing=$publishTarget,degreeWorks=$degreeWorks"
	sqlStmt="update $useSiteInfoTable set $setStr where siteId=\"$siteId\""
	[[ $verboseLevel -ge 2 ]] && echo && echo "setStr = >$setStr<" && echo && echo "sqlStmt = >$sqlStmt<" && echo
	RunSql2 $sqlStmt

#==================================================================================================
## Done
#==================================================================================================
[[ $verboseLevel -gt 0 ]] && echo -e "\t\t*** $myName - Ending ***"
#Goodbye 'quiet'
return 0

#==================================================================================================
## Check-in log
#==================================================================================================
## Wed Mar 23 11:46:55 CDT 2016 - dscudiero - Script to create site records, used by buildSiteInfoTable
## Fri Mar 25 15:08:24 CDT 2016 - dscudiero - General syncing of dev to prod
## Tue Mar 29 09:31:14 CDT 2016 - dscudiero - turn off messags parsing parms
## Tue Mar 29 11:48:57 CDT 2016 - dscudiero - Cleanup
## Tue Mar 29 12:23:16 CDT 2016 - dscudiero - Removed debug statements
## Tue Apr  5 13:49:53 CDT 2016 - dscudiero - Completely re-written to allow for parallel exection
## Wed Apr  6 12:56:00 CDT 2016 - dscudiero - Switch cims processing to use the cimStr from GetCims
## Mon Apr 11 10:01:48 CDT 2016 - dscudiero - Send stderr from courseleaf.cgi call when getting version to /dev/null
## Tue Apr 12 10:02:30 CDT 2016 - dscudiero - Trap stderr messags from the courseleaf.cgi -v call
## Wed Apr 27 16:04:36 CDT 2016 - dscudiero - Switch to use RunSql
## Wed Apr 27 16:32:47 CDT 2016 - dscudiero - Switch to use RunSql
## Tue May 10 07:17:59 CDT 2016 - dscudiero - Fix problem with setting publishing if the name of the directory just containd public
## Wed May 18 06:56:24 CDT 2016 - dscudiero - Refactored archives, publishing, and siteadmins
## Wed May 18 07:17:12 CDT 2016 - dscudiero - Refactored siteadmins to create a record per site/env
## Thu May 19 08:27:02 CDT 2016 - dscudiero - Fix siteadmin record insert
## Thu May 19 13:21:16 CDT 2016 - dscudiero - Fix sql for inserting siteadmin
## Tue Jun  7 07:01:17 CDT 2016 - dscudiero - Fix problem with setting url names
## Mon Jun 13 16:09:20 CDT 2016 - dscudiero - Tweak url selection
## Tue Jun 14 07:34:52 CDT 2016 - dscudiero - Update how urls are set
## Tue Sep  6 15:58:07 CDT 2016 - dscudiero - Set host and share to N/A if public or preview
## Fri Sep 23 12:44:10 CDT 2016 - dscudiero - Update to handle clver of the form version beta
## Fri Sep 23 13:41:59 CDT 2016 - dscudiero - General syncing of dev to prod
## Wed Sep 28 10:13:06 CDT 2016 - dscudiero - Removed extra comment lines
## Thu Oct  6 16:39:54 CDT 2016 - dscudiero - Set dbAcc level to Update for db writes
## Thu Oct  6 16:59:20 CDT 2016 - dscudiero - General syncing of dev to prod
## Fri Oct  7 08:00:28 CDT 2016 - dscudiero - Take out the dbAcc switching logic, moved to framework RunSql
## Thu Dec 29 15:58:23 CST 2016 - dscudiero - Switch to use RunMySql
## Tue Jan  3 07:43:05 CST 2017 - dscudiero - remove debug statement
## Thu Jan  5 13:40:42 CST 2017 - dscudiero - switch to RunSql2
## Thu Jan  5 15:50:53 CST 2017 - dscudiero - General syncing of dev to prod
## Fri Jan  6 08:04:22 CST 2017 - dscudiero - General syncing of dev to prod
## Tue Jan 10 14:57:02 CST 2017 - dscudiero - Fix problem getting the correct siteId after the insert of the seed record
## Wed Jan 11 07:00:17 CST 2017 - dscudiero - Fix problem building the skeleton shadow
## Wed Jan 11 09:10:44 CST 2017 - dscudiero - Change clver to catVer, added dailyshVer
## Wed Jan 11 09:46:52 CST 2017 - dscudiero - x
## Wed Jan 11 09:54:45 CST 2017 - dscudiero - Fixed various problems with dailyshVer code
