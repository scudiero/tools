##  #!/bin/bash
#DO NOT AUTOVERSION
#==================================================================================================
version=1.0.0 # -- dscudiero -- 10/20/2016 @ 14:58:14.98
#==================================================================================================
#= Description +===================================================================================
#
#
#==================================================================================================
TrapSigs 'on'
imports='GetDefaultsData ParseArgs ParseArgsStd Hello Init Goodbye TrapSigs WriteChangelogEntry' #imports="$imports "
Import "$imports"
originalArgStr="$*"
scriptDescription=""

# myArgList+=(-file1,4,option,file1,,script,'The file name relative to the root site directory')
# myArgList+=(-file2,4,option,file2,,script,'The file name relative to the root site directory')
# myArgList+=(-myflag,6,switch,myFlag,,script,'The file name relative to the root site directory')
#==================================================================================================
# Standard call back functions
#==================================================================================================
function addCourseleafLogEntry-ParseArgsStd  {
		argList+=(-jalot,3,option,jalot,,script,'Jalot task number')
		argList+=(-comment,7,option,comment,,script,'Comment describing the reason for the update')
	return 0
}

function addCourseleafLogEntry-Goodbye  {
	echo -e "\nIn $FUNCNAME..."
	SetFileExpansion 'on' ; rm -rf $tmpRoot/${myName}* >& /dev/null ; SetFileExpansion
	echo -e "\t$FUNCNAME done"
	return 0
}

function addCourseleafLogEntry-Help  {
		helpSet='script,client,env'
	return 0
}

function addCourseleafLogEntry-testMode  { # or testMode-local
	return 0
}

#==================================================================================================
# local functions
#==================================================================================================

# sqlStmt="select code from $authGroupsTable where members like \"%,$userName,%\""
# RunSql2 $sqlStmt
# unset usersAuthGroups
# if [[ ${#resultSet[@]} -ne 0 ]]; then
# 	for ((i=0; i<${#resultSet[@]}; i++)); do
# 		usersAuthGroups="$usersAuthGroups,${resultSet[$i]}"
# 	done
# 	usersAuthGroups=${usersAuthGroups:1}
# fi

#==================================================================================================
# Declare local variables and constants
#==================================================================================================
tmpFile=$(mkTmpFile)
trueVars=''
falseVars=''
for var in $trueVars; do eval $var=true; done
for var in $falseVars; do eval $var=false; done

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
# helpSet='script,client,env'
# scriptHelpDesc="This script can be used to patch on or more couseleaf instances.\
# \n\tPatches are defined in the '$courseleafPatchTable' table in the data warehouse and can be defined using the 'new' script.\
# \n\nEdited/changed files will be backed up to the /attic and actions will be logged in the /changelog.txt file."
# #helpNotes+=('1) If the noPrompt flag is active then the local repo will always be refreshed from the')
# #helpNotes+=('   master before the copy step.')
 GetDefaultsData $myName
 ParseArgsStd
Hello
Init "getClient getEnv getDirs checkEnvs"

## Get update comment
	[[ $verify == true ]] && echo
	Prompt jalot "Please enter the jalot task number:" "*isNumeric*"
	Prompt comment "Please enter the business reason for making this update:\n^" "*any*"
	[[ $jalot -eq 0 ]] && jalot='N/A'
	comment="(Task:$jalot) $comment"

## Get the file list for changed files
unset file changedFiles
Msg2 "Please specify the files changed"
while [[ 1 ]]; do
	Prompt file "^file" "*optional*"
	[[ -n "$file" ]] && changedFiles+=("$file") && unset file || break
done

unset verifyArgs
verifyArgs+=("Client:$client")
verifyArgs+=("Env:$(TitleCase $env)")
verifyArgs+=("Comment:$comment")
verifyContinueDefault='Yes'
VerifyContinue "You are asking to add a log entry to changelog.txt for"

myData="Client: '$client', Env: '$env'"
[[ $logInDb != false && $myLogRecordIdx != "" ]] && ProcessLogger 'Update' $myLogRecordIdx 'data' "$myData"

#===================================================================================================
# Main
#===================================================================================================
tgtDir="$siteDir"
tgtEnv="$env"
## Write out change log entries
unset changeLogLines
[[ -n $comment ]] && changeLogLines=("$comment")
env=$tgtEnv
if [[ $DOIT == '' ]]; then
	changeLogLines+=("${changedFiles[@]}")
	WriteChangelogEntry 'changeLogLines' "$tgtDir/changelog.txt" "$myName"
fi

#===================================================================================================
## Done
#===================================================================================================
Goodbye 0 #'alert'

#===================================================================================================
## Check-in log
#===================================================================================================
