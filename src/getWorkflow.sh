#!/bin/bash
#==================================================================================================
version=1.0.27 # -- dscudiero -- Thu 11/02/2017 @ 11:00:56.28
#==================================================================================================
TrapSigs 'on'
includes='Msg2 Dump GetDefaultsData ParseArgsStd Hello DbLog Init Goodbye VerifyContinue MkTmpFile'
includes="$includes GetCims"
Import "$includes"
originalArgStr="$*"
scriptDescription="This script can be used to retrieve the workflow generated for a CourseLeaf object"

#= Description +===================================================================================
#
#
#==================================================================================================
#==================================================================================================
# Standard call back functions
#==================================================================================================
function getWorkflow-parseArgsStd2 { # or parseArgs-local
	myArgs+=("prop|proposal|option|proposal||script|The proposal key of the CIM proposal to lookup")
	myArgs+=("page|page|option|page||script|The CAT page to lookup")
	return 0
}
function getWorkflow-Goodbye { # or Goodbye-local
	rm -rf $tmpRoot > /dev/null 2>&1
	return 0
}
function getWorkflow-testMode { # or testMode-local
	return 0
}

#==================================================================================================
# local functions
#==================================================================================================

#==================================================================================================
# Declare local variables and constants
#==================================================================================================
step='testworkflow'
cgiOut=$(mkTmpFile).cgiOut
unset cims cimStr

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
helpSet='script,client,env,cim'
Hello
GetDefaultsData $myName
ParseArgsStd2 $originalArgStr
dump -1 client cimStr proposal page

Init "getClient getEnv getDirs checkEnvs addPvt"

[[ $cim != '' ]] && wfType='proposal'
[[ $cat != '' ]] && wfType='page'

## Get wfType
	if [[ $page == '' && $cimStr == '' && $wfType == '' ]]; then
		Prompt wfType 'Is this a CIM proposal or a Catalog page:' 'cim page' 'cim'; wfType=$(Lower $wfType)
	else
		[[ $page != '' ]] && wfType='page'
		[[ $cimStr != '' ]] && wfType='proposal'
	fi
	[[ $wfType == 'cim' ]] && wfType='proposal'

## Get cim instance if wfType is cim
	if [[ $wfType == 'proposal' && $cimStr == '' ]]; then
		allowMultiCims=false
		Msg2 "Please select a CIM instance to use:"
		while [[ $cimStr == '' ]]; do
			GetCims $srcDir
			[[ $cimStr == '' ]] && Msg2 && Msg2 $ET "You must select a CIM instance"
		done
	fi

## Get proposal or page
	foundObj=false
	while [[ $foundObj != true ]]; do
		if [[ $wfType == 'page' ]]; then
			Prompt page "What catalog page do you wish to lookup (page path from siteDir)" "*any*"
			[[ ${page:0:1} != '/' ]] && page="/$page"
			[[ ! -d $srcDir/web/$page ]] && Msg2 $ET1 "Could not locate '$siteDir/$page'" && unset page && continue
			foundObj=true
		else
			Prompt proposal "What CIM proposal in '$cimStr' do you wish to lookup (enter key value)" "*any*"
			[[ ! -d $srcDir/web/$cimStr/$proposal ]] && Msg2 $ET1 "Could not locate proposal key '$proposal' in '$cimStr'" && unset proposal && continue
			foundObj=true
			page="/$cimStr/$proposal"
		fi
	done

## See of the page / proposal is in workflow
unset tsodate tsouser inWorkflowData workflowFileEdate
tsoFile="$srcDir/web${page}/index.tso"
if [[ -f $tsoFile ]]; then
	tsoDate="$(cut -d':' -f2 <<< $(ProtectedCall 'grep tsodate:' "$tsoFile"))"
	tsoEdate=$(date --date="$tsoDate" +%s)
	tsoUser="$(cut -d':' -f2 <<< $(ProtectedCall 'grep user:' "$tsoFile"))"
	inWorkflowData="$(TitleCase "$wfType") was placed into workflow on '$tsoDate' by '$tsoUser'"
	[[ $wfType == 'proposal' ]] && workflowFile="$srcDir/web/$cimStr/workflow.tcf" || workflowFile="$srcDir/web/courseleaf/workflows.tcf"
	workflowFileEdate=$(stat -c %Y $workflowFile)
fi

## if CIM Get the title information for the 'page'
	unset pageTitle
	if [[ $wfType == 'proposal' ]]; then
		grepFile=$srcDir/web/$cimStr/$proposal/index.tcf
		grepStr=$(ProtectedCall "grep ^title:" $grepFile)
		pageTitle=$(cut -d':' -f2- <<< $grepStr)
	fi

## Varify with user
	unset verifyArgs
	verifyArgs+=("Client:$client")
	verifyArgs+=("Env:$(TitleCase $env)")
	[[ $wfType == 'proposal' ]] && verifyArgs+=("CIMs:$cimStr") && verifyArgs+=("Proposal:$proposal ($pageTitle)")
	[[ $wfType == 'page' ]] && verifyArgs+=("Page:$page")
	verifyContinueDefault='Yes'
	VerifyContinue "You are asking to generate a workflow report for"

	myData="Client: '$client', Env: '$env', Cims: '$cimStr' "
	[[ $logInDb != false && $myLogRecordIdx != "" ]] && dbLog 'data' $myLogRecordIdx "$myData"

#===================================================================================================
# Main
#===================================================================================================
Msg2
[[ $wfType == 'proposal' ]] && Msg2 "^$client / CIM: $cimStr, Proposal: $proposal" || Msg2 "^$client / Page: $page"
[[ $inWorkflowData != '' ]] && Msg2 $NT1 "$inWorkflowData"
Msg2

## Get the workflow preview data
	cwd=$(pwd)
	cd $srcDir/web/courseleaf
	./courseleaf.cgi $step $page/index.tcf > $cgiOut
	cd $cwd

## Loop through data and pull out workflow data
	foundStart=false
	while read -r line; do
		[[ $(Contains "$line" 'Workflow:') == true ]] && foundStart=true;
		if [[ $foundStart == true ]]; then
			if [[ $(Contains "$line" 'Workflow:') == true ]]; then
				line=${line##'<p><strong>'}
				## WParse 'Workflow' record
				workflowwfType=$(cut -d':' -f1 <<< $line)
				if [[ $workflowwfType == 'Manually Assigned Workflow' ]]; then
					Msg2 "^^$workflowwfType"
					line=${line#*:</strong> }
					line=${line%%<*}
					IFS=',' read -r -a steps <<< "$line"
					for step in "${steps[@]}"; do
						Msg2 "^^^$step"
					done
					break
				else
					line=${line#*:</strong> }
					workflow=${line%%<*}
					Msg2 "^^Workflow: $workflow"
					line=${line#*<ul class=\"role\">}
				fi
			fi
			## Parse off the step
			if [[ ${line:0:12} == '<li><strong>' ]]; then
				unset fyiStr
				[[ $(Contains "$line" '<em>FYI</em>') == true ]] && fyiStr='fyi'
				[[ $(Contains "$line" '<em>FYI All</em>') == true ]] && fyiStr='fyiall'
				line=${line##'<li><strong>'}
				step=${line%%<*}
				Msg2 "^^^$step $fyiStr"
			fi
		fi
	done < $cgiOut

## If workflow file has changed since the page/proposal was placed in workflow
	if [[ $workflowFileEdate > $tsoEdate ]]; then
		Msg2
		Warning 0 1 "The workflow file has changed since this $wfType was placed into workflow"
		Msg2 "^^Tso file date: $(date -d @$tsoEdate '+%D')"
		Msg2 "^^Workflow file date: $(date -d @$workflowFileEdate '+%D @ %H:%M:%S')"
	fi

#===================================================================================================
## Done
#===================================================================================================
Goodbye 0 #'alert'

#===================================================================================================
## Check-in log
#===================================================================================================
## Thu May  5 08:55:17 CDT 2016 - dscudiero - Retrieve workflow data from a catalog page or cim proposal
## Thu May  5 11:38:49 CDT 2016 - dscudiero - Added checking the time/date of the tso file to the workflow file
## Tue Jul 12 14:22:31 CDT 2016 - dscudiero - Fix cim/cat prompt
## Thu Jul 14 14:04:37 CDT 2016 - dscudiero - Add page title to the verifyContinue display for cim proposals
## Fri Mar 10 16:48:28 CST 2017 - dscudiero - Updated verify messages
## 04-13-2017 @ 14.00.56 - (1.0.20)    - dscudiero - Add a default for VerifyContinue
## 11-02-2017 @ 06.58.54 - (1.0.26)    - dscudiero - Switch to ParseArgsStd2
## 11-02-2017 @ 11.02.09 - (1.0.27)    - dscudiero - Add addPvt to the init call
