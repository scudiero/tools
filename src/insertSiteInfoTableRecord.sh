#!/bin/bash
#==================================================================================================
version="1.2.4" # -- dscudiero -- Mon 07/30/2018 @ 07:56:08
#==================================================================================================
TrapSigs 'on'

myIncludes="RunSql ParseCourseleafFile StringFunctions SetFileExpansion ProtectedCall GetCims"
Import "$standardIncludes $myIncludes"

originalArgStr="$*"
scriptDescription="Insert/Update a record into the '$siteInfoTable' and '$siteAdminsTable' tables in the data warehouse,\nThis script is not intended to be called stand alone."

#= Description +===================================================================================
# Create a record in the siteInfoTable, this is a helper script for 'buildSiteInfoTable' and is
# NOT MEANT TO BE CALLED STAND ALONE
# insertSiteInfoTableRecord $siteDir -clientId $clientId
#==================================================================================================
checkParent='buildSiteInfoTable'; found=false
for ((i=0; i<${#BASH_SOURCE[@]}; i++)); do [[ "$(basename "${BASH_SOURCE[$i]}")" == "${checkParent}.sh" ]] && found=true; done
[[ $found != true ]] && Terminate "Sorry, this script can only be called from '$checkParent'"

#==================================================================================================
# Standard call back functions
#==================================================================================================
	function insertSiteInfoTableRecord-ParseArgsStd {
		# argList+=(argFlag,minLen,type,scriptVariable,exCmd,helpSet,helpText)  #type in {switch,switch#,option,help}
		argList+=(-tableName,5,option,tableName,,script,"The name of the table to load")
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
#ParseArgsStd "$*"

#==================================================================================================
# Declare local variables and constants
#==================================================================================================
share=$(cut -d '/' -f3 <<< $siteDir)
client=$(cut -d' ' -f1 <<< $(ParseCourseleafFile "$siteDir"))

shareType='prod'; suffix='/'; env=${siteDir##*/}
[[ ${share:0:3} == 'dev' ]] && shareType='dev' && suffix='/web/' && env='dev'
dump 2 -n -t siteDir share shareType client env clientId

## Which table to use
	useSiteInfoTable="$siteInfoTable"
	useSiteAdminsTable="$siteAdminsTable"
	if [[ -n $tableName ]]; then
		useSiteInfoTable="$tableName"
		let tmpLen=${#tableName}-3
		[[ ${tableName:$tmpLen:3} == 'New' ]] && useSiteAdminsTable="${siteAdminsTable}New"
	fi
	[[ $WAREHOUSEDB == '$warehouseDev' ]] && useSiteInfoTable="${siteInfoTable}New" && useSiteAdminsTable="${siteAdminsTable}New"
	dump 1 siteInfoTable useSiteInfoTable tableName

#===================================================================================================
# Main
#===================================================================================================
[[ $DOIT != '' || $informationOnlyMode == true ]] && echo
Verbose 1 "^$myName -- $env ($siteDir) --> ${warehouseDb}.${useSiteInfoTable}"

## Remove any existing records for this client/env
	sqlStmt="delete from $useSiteInfoTable where clientId =\"$clientId\" and env=\"$env\""
	RunSql $sqlStmt

## Insert the initial record to get the siteId set
	fields="siteId,name,clientId,env,host,share,redhatVer,createdOn,createdBy"
	if [[ $env == 'preview' || $env == 'public' ]]; then
		host='N/A'
		share='N/A'
	else
		host=$hostName
	fi
	valueStr="NULL,\"$client\",\"$clientId\",\"$env\",\"$host\",\"$share\",\"$myRhel\",NOW(),\"$userName\""
	sqlStmt="insert into $useSiteInfoTable ($fields) values($valueStr)"
	RunSql $sqlStmt
	## Get newly inserted siteid
	[[ ${#resultSet[@]} -eq 0 ]] && Terminate "Could not insert seed record into $useSiteInfoTable"
	siteId=${resultSet[0]}
	Verbose 1 "\tSiteId for $client is '$siteId'"

## lookup urls from the clients table
	if [[ $env == 'test' || $env == 'next' || $env == 'curr' ]]; then
		sqlStmt="select ${env}url,${env}InternalUrl from $clientInfoTable where idx=\"$clientId\" "
		RunSql $sqlStmt
		url=\"$(cut -d'|' -f1 <<< ${resultSet[0]})\"
		[[ $url == '"NULL"' ]] && url=NULL
		internalUrl=\"$(cut -d'|' -f2 <<< ${resultSet[0]})\"
		[[ $internalUrl == '"NULL"' ]] && internalUrl=NULL
	else
		sqlStmt="select ${env}url from $clientInfoTable where idx=\"$clientId\" "
		RunSql $sqlStmt
		url=\"${resultSet[0]}\"
		[[ $url == '"NULL"' ]] && url=NULL
		internalUrl=NULL
	fi
	dump -1 -t url internalUrl

## See if the site has google search installed
	unset googleType
	grepFile=$(dirname $siteDir)/$env/web/ribbit/fsinjector.rjs
	if [[ -r $grepFile ]]; then
		googleType=$(ProtectedCall "grep '^var googletype' $grepFile | grep -v null")
		[[ -n $googleType ]] && googleType=$(cut -d"=" -f2 <<< $googleType | tr -d "'" | tr -d ";" | tr -d " ")
	fi
	[[ -z $googleType ]] && googleType=NULL || googleType="\"$googleType\""
	dump -2 -t googletype

## Preview or Public -- Parse archives and write out a short record
	unset archives archiveDir
	if [[ $env == 'preview' || $env == 'public' ]]; then
		#Check to see if the curr or next sites have archive path set, if the do then lookup archive directories
		for checkEnv in next curr; do
			unset archiveRoot archiveDir
			# Get archive path from the next env.
			grepFile=$(dirname $siteDir)/$checkEnv/web/courseleaf/localsteps/default.tcf
			dump -2 -n checkEnv grepFile
			if [[ -r $grepFile ]]; then
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
			[[ -n $archives ]] && break
		done;
		## Check to see what archives are active
			archives="\"$archives\""
			dump -2 archives
		## Write out the record
			setStr="url=$url,archives=$archives,googleType=$googleType"
			sqlStmt="update $useSiteInfoTable set $setStr where siteId=\"$siteId\""
			RunSql $sqlStmt
			return 0
	else
		archives="\"$archives\""
	fi #[[ $env = 'preview' || $env = 'public' ]]
	archives="\"$archives\""

## Get CIMS
	unset cimStr cims
	GetCims $siteDir -all
	[[ -n $cimStr ]] && cimStr=\"${cimStr// /}\" || cimStr=NULL
	dump -2 -t cimStr

## Get the cimVer
	clverFile="$siteDir/web/courseleaf/cim/clver.txt"
	unset cimVer
	if [[ -r $clverFile ]]; then
		cimVer=$(cat $clverFile);
		cimVer=$(cut -d":" -f2 <<< $cimVer | tr -d '\040\011\012\015');
	fi
	[[ $cimVer != 'NULL' ]] && cimVer=\""$cimVer"\"
	dump -2 -t cimVer

## Get the catVer
	clverFile="$siteDir/web/courseleaf/clver.txt"
	defaultTcfFile="$siteDir/web/courseleaf/default.tcf"
	unset catVer
	if [[ -r $clverFile ]]; then
		catVer=$(cat $clverFile);
		catVer=$(cut -d":" -f2 <<< $catVer | tr -d '\040\011\012\015');
	elif [[ -f $defaultTcfFile ]]; then
		catVer=$(ProtectedCall "grep '^clver:' $defaultTcfFile");
		catVer=$(cut -d":" -f2 <<< $catVer | tr -d '\040\011\012\015');
	fi
	#[[ -z $catVer ]] && catVer=NULL
	[[ $catVer != 'NULL' ]] && catVer=\""$catVer"\"
	dump -2 -t catVer

## Get the clssVer
	clverFile="$siteDir/web/wen/clver.txt"
	unset clssVer
	if [[ -r $clverFile ]]; then
		clssVer=$(cat $clverFile);
		clssVer=$(cut -d":" -f2 <<< $clssVer | tr -d '\040\011\012\015');
		[[ $clssVer != 'NULL' ]] && clssVer=\""$clssVer"\"
	fi
	[[ $clssVer != 'NULL' ]] && clssVer=\""$clssVer"\"
	dump -2 -t clssVer

## Get the cgiVersion
	unset courseleafCgiVer
	#courseleafCgiVer=NULL
	cgiFile="$siteDir/web/courseleaf/courseleaf.cgi"
	if [[ -x "$cgiFile" ]]; then
		courseleafCgiVer="$($cgiFile -v  2> /dev/null | cut -d" " -f3)"
	fi
	[[ $courseleafCgiVer != 'NULL' ]] && courseleafCgiVer=\""$courseleafCgiVer"\"
	dump -2 -t courseleafCgiVer

## Get the reportsVer
	unset reportsVer
	checkFile="$siteDir/web/courseleaf/localsteps/reports.js"
	if [[ -r "$checkFile" ]]; then
		reportsVer="$(ProtectedCall "grep -s -m 1 'version:' $checkFile")"
		reportsVer=${reportsVer##*: }
		reportsVer=$(CleanString "$reportsVer")
		#[[ -z $reportsVer ]] && reportsVer=NULL
	fi
	[[ $reportsVer != 'NULL' ]] && reportsVer=\""$reportsVer"\"
	dump -2 -t reportsVer

	## Get daily.sh versions
		unset dailyshVer
		checkFile="$siteDir/bin/daily.sh"
		if [[ -r $checkFile ]]; then
			grepStr=$(ProtectedCall "grep '## Nightly cron job for client' $checkFile")
			if [[ -n $grepStr ]]; then
				dailyshVer=$(ProtectedCall "grep 'version=' $checkFile")
				dailyshVer=${dailyshVer##*=} ; dailyshVer=${dailyshVer%% *}
			else
				dailyshVer='Old'
			fi
		else
			dailyshVer='None'
		fi
		[[ $dailyshVer != 'NULL' ]] && dailyshVer=\"$dailyshVer\"
		dump -2 -t dailyshVer

## Get the edition variable
	unset catEdition
	checkFile="$siteDir/web/courseleaf/localsteps/default.tcf"
	if [[ -f $checkFile ]]; then
		catEdition=$(cut -d":" -f2 <<< $(ProtectedCall "grep '^edition:' $checkFile") | tr -d '\040\011\012\015');
	fi
	[[ $catEdition != 'NULL' ]] && catEdition=\""$catEdition"\"
	dump -2 -t catEdition

## Get the publishing
	unset publishTarget
	if [[  "$env" = 'test' || "$env" = 'next' || "$env" = 'curr' ]]; then
		checkFile="$siteDir/courseleaf.cfg"
		if [[ -f $checkFile ]]; then
			mapfileProd=$(ProtectedCall "grep '^mapfile:production|' $checkFile");
			[[ $mapfileProd == '' ]] && mapfileProd=$(ProtectedCall "grep '^mapfile:production/|' $checkFile");
			if [[ $mapfileProd != '' ]]; then
				[[ $publishTarget == NULL ]] && publishTarget=$(cut -d'|' -f2 <<< $mapfileProd)
			fi
		fi
	fi
	[[ $publishTarget != 'NULL' ]] && publishTarget=\""$publishTarget"\"
	dump -2 -t publishTarget

## See if site has degree works tools enabled
	unset degreeWorks
	if [[ "$env" != 'preview' && "$env" != 'public' ]]; then
		checkFile="$siteDir/web/courseleaf/index.tcf"
		if [[ -f $checkFile ]]; then
			unset tempStr; tempStr=$(ProtectedCall "grep '^navlinks\:.*dworksenable' $checkFile")
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
					RunSql "$clUsersFile" "$sqlStmt"
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
								RunSql "$clUsersFile" "$sqlStmt"
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
						sqlStmt="insert into $useSiteAdminsTable ($fields) values(NULL,\"$siteId\",\"$client\",\"$env\",\"$admins\")"
						RunSql $sqlStmt
					fi
		fi
	fi

## Create the sites table record
	setStr="catver=$catVer,cimver=$cimVer,clssVer=$clssVer,courseleafCgiVer=$courseleafCgiVer,reportsVer=$reportsVer,dailyshVer=$dailyshVer"
	setStr="$setStr,CIMs=$cimStr,url=$url,internalUrl=$internalUrl,siteDir=\"$siteDir\",archives=$archives,googleType=$googleType"
	setStr="$setStr,CATedition=$catEdition,publishing=$publishTarget,degreeWorks=$degreeWorks"
	sqlStmt="update $useSiteInfoTable set $setStr where siteId=\"$siteId\""
	[[ $verboseLevel -gt 0 ]] && echo && echo "setStr = >$setStr<" && echo && echo "sqlStmt = >$sqlStmt<" && echo
	RunSql $sqlStmt

#==================================================================================================
## Done
#==================================================================================================
Goodbye 'Return'
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
## Thu Jan  5 13:40:42 CST 2017 - dscudiero - switch to RunSql
## Thu Jan  5 15:50:53 CST 2017 - dscudiero - General syncing of dev to prod
## Fri Jan  6 08:04:22 CST 2017 - dscudiero - General syncing of dev to prod
## Tue Jan 10 14:57:02 CST 2017 - dscudiero - Fix problem getting the correct siteId after the insert of the seed record
## Wed Jan 11 07:00:17 CST 2017 - dscudiero - Fix problem building the skeleton shadow
## Wed Jan 11 09:10:44 CST 2017 - dscudiero - Change clver to catVer, added dailyshVer
## Wed Jan 11 09:46:52 CST 2017 - dscudiero - x
## Wed Jan 11 09:54:45 CST 2017 - dscudiero - Fixed various problems with dailyshVer code
## Wed Jan 11 10:19:52 CST 2017 - dscudiero - General cleanup
## Wed Jan 11 16:13:05 CST 2017 - dscudiero - Update dailyshver code to write out Old or None based on found file
## Thu Jan 12 07:12:04 CST 2017 - dscudiero - Fix problem where we were double quoting cimver
## Tue Jan 17 15:38:34 CST 2017 - dscudiero - Set which table to load based on WAREHOUSEDB
## Tue Jan 17 15:39:43 CST 2017 - dscudiero - Make production table the default table name
## Wed Jan 18 07:20:50 CST 2017 - dscudiero - Modify siteAdmins table insert to use a variable for the table name
## Wed Jan 25 08:24:45 CST 2017 - dscudiero - refactor how we set useSitesTable & useSiteAdminsTable
## Tue Feb 14 13:19:24 CST 2017 - dscudiero - Refactored to delete the client records before inserting a new one
## Mon Feb 20 07:20:01 CST 2017 - dscudiero - Make messages level 1
## Tue Feb 21 06:46:58 CST 2017 - dscudiero - Fix error with verbose
## 03-27-2017 @ 13.30.29 - (1.1.121)   - dscudiero - General syncing of dev to prod
## 04-28-2017 @ 08.26.26 - (1.1.122)   - dscudiero - use Goodbye 'return'
## 05-19-2017 @ 15.13.04 - (1.1.123)   - dscudiero - Added siteDir to the sites record
## 09-27-2017 @ 16.51.07 - (1.1.125)   - dscudiero - Added starting message
## 10-18-2017 @ 14.16.26 - (1.1.126)   - dscudiero - Make the 'called from' logic more robust
## 10-18-2017 @ 14.20.52 - (1.1.127)   - dscudiero - Cosmetic/minor change
## 10-18-2017 @ 14.30.33 - (1.1.128)   - dscudiero - Fix who called check
## 10-19-2017 @ 09.42.44 - (1.1.129)   - dscudiero - Added debug arround caller check code
## 10-20-2017 @ 09.01.54 - (1.1.130)   - dscudiero - Fix problem in the caller check code
## 10-20-2017 @ 13.11.51 - (1.1.133)   - dscudiero - comment out the parseargsstd call
## 10-23-2017 @ 07.17.15 - (1.1.135)   - dscudiero - add debug statement
## 10-23-2017 @ 07.20.36 - (1.1.136)   - dscudiero - add debig
## 10-23-2017 @ 16.52.19 - (1.1.142)   - dscudiero - Fix problem with tons of quotes arround cims
## 10-27-2017 @ 08.25.20 - (1.1.143)   - dscudiero - Switch to use Verbose
## 10-30-2017 @ 09.34.52 - (1.1.144)   - dscudiero - Fix problem getting the cims not clearing cims array before calling GetCims
## 11-30-2017 @ 13.26.41 - (1.1.145)   - dscudiero - Switch to use the -all flag on the GetCims call
## 03-22-2018 @ 14:06:41 - 1.1.146 - dscudiero - Updated for Msg3/Msg, RunSql2/RunSql, ParseArgStd/ParseArgStd2
## 03-23-2018 @ 16:18:51 - 1.1.147 - dscudiero - D
## 04-20-2018 @ 08:03:23 - 1.1.148 - dscudiero - Only grep files if they are readable
## 07-25-2018 @ 11:18:02 - 1.2.2 - dscudiero - Set courseleaf data to "" instead of null if data not found for the site
## 07-26-2018 @ 06:51:39 - 1.2.3 - dscudiero - Do not store empty values as null, switch to ""
## 07-30-2018 @ 07:57:21 - 1.2.4 - dscudiero - Fix more issues setting values to NULL messing up courseleaf dbQUery
