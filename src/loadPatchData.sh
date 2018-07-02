#!/bin/bash
#DO NOT AUTOVERSION
#=======================================================================================================================
version=1.0.-1 # -- dscudiero -- 10/20/2016 @ 14:58:14.98
#=======================================================================================================================
#= Description #========================================================================================================
#
#
#=======================================================================================================================
TrapSigs 'on'
myIncludes="DatabaseUtilities SetFileExpansion PushPop"
Import "$standardInteractiveIncludes $myIncludes"

originalArgStr="$*"
scriptDescription=""

#=======================================================================================================================
# Standard call back functions
#=======================================================================================================================
	function loadPatchData-ParseArgsStd  {
		#myArgs+=("shortToken|longToken|type|scriptVariableName|<command to run>|help group|help textHelp")
		return 0
	}

	function loadPatchData-Goodbye  {
		SetFileExpansion 'on' ; rm -rf $tmpRoot/${myName}* >& /dev/null ; SetFileExpansion
		return 0
	}

	function loadPatchData-Help  {
		helpSet='client,env' # can also include any of {env,src,tgt,prod,cim,cat,clss}, 'script' and 'common' automatically addeed
		[[ $1 == 'setVarsOnly' ]] && return 0
		[[ -z $* ]] && return 0
		echo -e "This script can be used to refresh the tools 'auth' data shadow ($authShadowDir) from the database data."
		return 0
	}

	function loadPatchData-testMode  { # or testMode-local
		return 0
	}

#=======================================================================================================================
# local functions
#=======================================================================================================================

#=======================================================================================================================
# Declare local variables and constants
#=======================================================================================================================
tmpFile=$(mkTmpFile)
trueVars=''
falseVars=''
for var in $trueVars; do eval $var=true; done
for var in $falseVars; do eval $var=false; done
unset numfields fields

#=======================================================================================================================
# Standard arg parsing and initialization
#=======================================================================================================================
GetDefaultsData -f $myName
ParseArgsStd $originalArgStr
Hello
user="$client"

if [[ $batchMode != true ]]; then
	unset ans
	Prompt ans "You are asking to reload the courseleafPatch control data, do you wish to continue" 'Yes No' 'Yes';
	ans="${ans:0:1}"; ans="${ans,,[a-z]}"
	[[ $ans != 'y' ]] && Goodbye 3
fi

#============================================================================================================================================
# Main
#============================================================================================================================================
## Get the transactional database file from the internal stage config file
	grepStr=$(ProtectedCall "grep db:courseleafPatch $internalSiteRoot/stage/pagewiz.cfg")
	[[ -z $grepStr ]] && { Error "Could not locate the db definition record for courseleafPatch in '$internalSiteRoot/stage/pagewiz.cfg'"; return 0; }
	
	dbFile="${internalSiteRoot}/stage${grepStr##*|}"
	getTableColumns "$patchesTable" 'warehouse' 'numFields' 'fields'

## Get the data from the transactional table
	SetFileExpansion 'off'
	sqlStmt="select * from patchControl"
	RunSql "$dbFile" $sqlStmt
	SetFileExpansion
	for rec in "${resultSet[@]}"; do dataRecs+=("$rec"); done
	## Check the data
	for rec in "${dataRecs[@]}"; do
		recType="$(cut -f4 -d'|' <<< "$rec")"
		if [[ $recType == 'currentRelease' ]]; then
			## Check the value specified master the master repo
			product="$(cut -f2 -d'|' <<< "$rec")"
			[[ $product == 'cat' ]] && product='courseleaf'
			option="$(cut -f7 -d'|' <<< "$rec")"
			if [[ $option != 'master' ]]; then
				Pushd "$gitRepoRoot/${product}.git"
				tags="$(ProtectedCall "git tag" | tr '\n' ' ')"
				Popd
				## Loop through the tags to make sure the specified value is correct
				found=false
				for tag in $tags; do
					[[ $tag == $option ]] && { found=true; break; }
				done
				[[ $found != true ]] && Terminate "Specified value for 'currentRelease' ($option) in the transactional database is not a valid git tag\n\t\t$rec"
			fi
		fi
	done

## Data is good, Make a copy of the warehouse table 
	sqlStmt="drop table if exists ${patchesTable}New"
	RunSql $sqlStmt
	sqlStmt="create table ${patchesTable}New like ${patchesTable}"
	RunSql $sqlStmt

## Insert into warehouse table
	for ((i=0; i<${#dataRecs[@]}; i++)); do
		sqlStmt="insert into ${patchesTable}New ($fields) values("
		data="${dataRecs[$i]}"; #data="${data#*|}"
		#sqlStmt="${sqlStmt}null,\"${data//|/","}\")"
		sqlStmt="${sqlStmt}\"${data//|/","}\")"
		RunSql $sqlStmt
	done

## Swap tables
	sqlStmt="drop table if exists ${patchesTable}Bak"
	RunSql $sqlStmt
	sqlStmt="rename table $patchesTable to ${patchesTable}Bak"
	RunSql $sqlStmt
	sqlStmt="rename table ${patchesTable}New to $patchesTable"
	RunSql $sqlStmt

	return 0

#============================================================================================================================================
## Done
#============================================================================================================================================
Goodbye 0 #'alert'

#============================================================================================================================================
## Check-in log
#============================================================================================================================================
## 06-18-2018 @ 10:49:14 - 1.0.-1 - dscudiero - Allow passing in a userid name to update
## 06-18-2018 @ 15:19:04 - 1.0.-1 - dscudiero - Initial load
## 06-18-2018 @ 15:32:23 - 1.0.-1 - dscudiero - Change the name of the transactional table
## 07-02-2018 @ 13:32:59 - 1.0.-1 - dscudiero - Add data checks for the 'currentRecord' records
## 07-02-2018 @ 13:35:07 - 1.0.-1 - dscudiero - Popd after we get the git tabs
## 07-02-2018 @ 14:09:18 - 1.0.-1 - dscudiero - Tweak messaging
