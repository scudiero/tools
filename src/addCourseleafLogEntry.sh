##  #!/bin/bash
#XO NOT AUTOVERSION
#==================================================================================================
version="1.0.34" # -- dscudiero -- Wed 01/16/2019 @ 16:43:08
#==================================================================================================
#= Description +===================================================================================
#
#  
#==================================================================================================
TrapSigs 'on'
myIncludes="WriteChangelogEntry"
Import "$standardInteractiveIncludes $myIncludes"

originalArgStr="$*"
scriptDescription=""
#==================================================================================================
# Standard call back functions
#==================================================================================================
	function addCourseleafLogEntry-ParseArgsStd {
			myArgs+=('jalot|jalot|option|jalot||script|Jalot task number')
			myArgs+=('comment|comment|option|comment||script|Comment describing the reason for the update')
		return 0
	}

	function addCourseleafLogEntry-Goodbye {
		SetFileExpansion 'on' ; rm -rf $tmpRoot/${myName}* >& /dev/null ; SetFileExpansion
		return 0
	}

	function addCourseleafLogEntry-Help {
		helpSet='client,env' # can also include any of {env,cim,cat,clss}, 'script' and 'common' automatically added
		[[ $1 == 'setVarsOnly' ]] && return 0

		[[ -z $* ]] && return 0
		bullet=1
		echo -e "This script can be used to add formatted entry into a sites changelog.txt file"
		echo -e "\nSite files modified:"
		echo -e "\t$bullet) <siteDir>/changelog.txt"
		(( bullet++ ))
		echo -e "\nA change log entry with the following format will be created:"
		echo -e "\t<userName>	<date> via $myName version: $version"
		echo -e "\t\t(Task:###) <comment>"
		echo -e "\t\t\t<Changed file 1>"
		echo -e "\t\t\t<Changed file 2>"
		echo -e "\t\t\t..."
		echo -e "\t\t\t<Changed file n>"
		return 0
	}

	function addCourseleafLogEntry-testMode  { # or testMode-local
		return 0
	}

#==================================================================================================
# local functions
#==================================================================================================

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
GetDefaultsData $myName
ParseArgsStd $originalArgStr
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
Msg "Please specify the files changed"
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
## 03-22-2018 @ 12:34:59 - 1.0.8 - dscudiero - Updated for Msg3/Msg, RunSql2/RunSql, ParseArgStd/ParseArgStd2
## 03-23-2018 @ 15:31:20 - 1.0.9 - dscudiero - D
## 07-12-2018 @ 07:17:37 - 1.0.10 - dscudiero - Cosmetic/minor change/Sync
## 01-16-2019 @ 14:02:31 - 1.0.14 - dscudiero - Texting 1 2 3
## 01-16-2019 @ 14:09:33 - 1.0.15 - dscudiero - This is a test
## 01-16-2019 @ 14:10:52 - 1.0.17 - dscudiero - This is a test
## Wed Jan 16 14:45:24 CST 2019 - dscudiero - -m testing 1 2 3 4
