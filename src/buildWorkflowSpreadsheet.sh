#!/bin/bash
#==================================================================================================
version=1.2.43 # -- dscudiero -- Thu 10/19/2017 @ 16:39:11.89
#==================================================================================================
TrapSigs 'on'
includes='Msg3 Dump GetDefaultsData ParseArgsStd Hello DbLog Init Goodbye VerifyContinue MkTmpFile'
includes="$includes GetOutputFile ProtectedCall"
Import "$includes"

originalArgStr="$*"
scriptDescription="Extracts workflow data in a format that facilitates pasteing into a MS Excel workbook"

#==================================================================================================
# Run hourly from cron
#==================================================================================================
#==================================================================================================
# Copyright ©2014 David Scudiero -- all rights reserved.
# xx-xx-15 -- dgs - Initial coding
#==================================================================================================

#==================================================================================================
# local functions
#==================================================================================================
	#==============================================================================================
	# parse script specific arguments
	#==============================================================================================
	function parseArgs-makeWorkflowSpreadsheet  {
		argList+=(-workbookFile,1,option,workbookFile,,script,'The fully qualified spreadsheet file name')
		argList+=(-doNotLoadNulls,2,switch,doNotLoadNulls,,script,'If a data field is null then do not write out that data to the page')
		return 0
	}

	#==============================================================================================
	# Goodbye call back
	#==============================================================================================
	function Goodbye-makeWorkflowSpreadsheet  {
		eval $errSigOn
		if [[ -f $stepFile ]]; then echo rm stepFile; rm -f $stepFile; fi
		if [[ -f $backupStepFile ]]; then mv -f $backupStepFile $stepFile; fi
		[[ -f "$tmpFile" ]] && rm "$tmpFile"
		return 0
	}

	#==============================================================================================
	# TestMode overrides
	#==============================================================================================
	function testMode-makeWorkflowSpreadsheet  {
		env='dev'
		srcDir=~/testData/dev
		return 0
	}

	#==============================================================================================
	# Parse an esig record
	#==============================================================================================
	function ParseEsig  {
		local ruleName="$1"; shift
		local line="$1"; shift
		local description="$*"
		local stepName value tmpStr
		dump -2 -t ruleName line description

		#line = >UCCGCPREP|UCC & GC Preparers|function|UCCGCPrepsEsig|; <
		stepName="$(cut -d'|' -f2 <<< "$line")"
		value="$(cut -d'|' -f4 <<< "$line")"
		dump -2 -t stepName value
		if [[ ${esigs[$stepName]+abc} ]]; then
			tmpStr="${esigs["$stepName"]}"
			esigs["$stepName"]="$tmpStr ; function{$value}"
		else
			esigs["$stepName"]="$description\t\tfunction{$value}"
			esigsKeys+=("$stepName")
		fi

		return 0
	} ## ParseEsig

	#==============================================================================================
	# Parse an wfrules record
	#==============================================================================================
	function ParseWfrule  {
		local ruleName="$1"; shift
		local line="$1"; shift
		local description="$*"
		local rtype value tmpStr
		dump -2 -t ruleName line description

		[[ $(Contains ",${ignoreRules}," ",${ruleName},") == true ]] && return 0

		if [[ $(Contains "$line" '|attr|') == true || $(Contains "$line" '|function|wfAttr|') == true ]]; then
			#line = >Col|attr|college_prog.code|; <
			substitutionVars[$ruleName]="$description\t\tattr{$(cut -d'|' -f3 <<< "$line")}"
			substitutionVarsKeys+=($ruleName)
		else
			#line = >addProvost|function|AddProvost|; <
			if [[ $(Contains "$line" '|function|') == true ]]; then
				rtype="$(cut -d'|' -f2 <<< "$line")"
				value="$(cut -d'|' -f3 <<< "$line")"
			#line = >iffieldmatch|acad_level.code|value=UG; <
			elif [[ $(Contains "$line" '|iffieldmatch|') == true ]]; then
				rtype="$(cut -d'|' -f2 <<< "$line")"
				value="$(cut -d'|' -f3- <<< "$line")"
				value=$(tr -d ';' <<< "$value")
			else
				Warning "Unknown rule type: '$line'"
				continue
			fi
			dump -2 -t rtype value
			if [[ ${wfrules[$ruleName]+abc} ]]; then
				tmpStr="${wfrules[$ruleName]}"
				wfrules[$ruleName]="$tmpStr ; $rtype{$value}"
			else
				wfrules[$ruleName]="$description\t\t$rtype{$value}"
				wfrulesKeys+=($ruleName)
			fi
		fi
		return 0
	} ## ParseWfrule

#==================================================================================================
# Declare local variables and constants
#==================================================================================================
trueVars=''
falseVars=''
for var in $trueVars; do eval $var=true; done
for var in $falseVars; do eval $var=false; done
declare -A modifiersRef
declare -A conditionalsRef
declare -A esigs
declare -A wfrules
declare -A substitutionVars
tmpFile=$(MkTmpFile)

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
Hello
scriptNews+=("11/01/2016 - New")
helpSet='script,client,env'
GetDefaultsData $myName
ParseArgsStd
[[ $allItems == true ]] && allCims='allCims' || unset allCims
Init "getClient getEnv getDirs checkEnvs getCims $allCims"
if [[ $informationModeOnly == true ]]; then
	outFile='/dev/null'
else
	[[ $workbookFile != '' ]] && outFile="$workbookFile" || outFile="$(GetOutputFile "$client" "$env" "$product")"
fi

unset ignoreRules ignoreSteps ignoreWorkflows
ignoreRules="$(cut -d':' -f2- <<< $scriptData1)"
ignoreSteps="$(cut -d':' -f2- <<< $scriptData2)"
ignoreWorkflows="$(cut -d':' -f2- <<< $scriptData3)"
modifiers="$(cut -d':' -f2- <<< $scriptData4)"

unset verifyArgs
verifyArgs+=("Client:$client")
verifyArgs+=("Env:$(TitleCase $env) ($srcDir)")
verifyArgs+=("CIMs:$cimStr")
verifyArgs+=("IgnoreRules:$ignoreRules")
verifyArgs+=("IgnoreSteps:$ignoreSteps")
verifyArgs+=("IgnoreWorkflows:$ignoreWorkflows")

verifyArgs+=("Output File:$outFile")
verifyContinueDefault='Yes'
VerifyContinue "You are asking to generate a workflow spreadsheet for"

myData="Client: '$client', Env: '$env', Cims: '$cimStr' "
[[ $logInDb != false && $myLogRecordIdx != "" ]] && dbLog 'data' $myLogRecordIdx "$myData"


#==================================================================================================
# Main
#==================================================================================================

## Loop through CIMs
for cim in $(echo $cimStr | tr ',' ' '); do
	Msg3
	Msg3 "Processing CIM instance: '$cim'"
	grepFile="$srcDir/web/$cim/workflow.cfg"
	if [[ ! -f $grepFile ]]; then
		Warning "Could not locate file $(basename $grepFile), trying cimconfig.cfg"
		grepFile="$srcDir/web/$cim/cimconfig.cfg"
		[[ ! -f $grepFile ]] && Terminate "Could not locate file $grepFile"
	fi
	Msg3 "\n$(PadChar)" >> $outFile
	Msg3 "<<< $(Upper "$cim") >>>" >> $outFile

	## Read the workflow.cfg file for the cim
		## Get any special modifiers
			specialModifiers=$(ProtectedCall grep 'wfSpecialModifiers:' $grepFile)
			[[ -n $specialModifiers ]] && specialModifiers="${specialModifiers##*:}"

		## Parse off the wfrules
		unset substitutionVars wfrules wfrulesKeys substitutionVarsKeys esigsKeys wforders
		declare -A wfrules ; declare -A esigs ; declare -A substitutionVars
		Msg3 "^Parsing '$grepFile'"
		[[ -f $tmpFile ]] && rm -f $tmpFile
		\grep '^wfrules:\|^wforder:\|^esiglist:\|^voterules:' $grepFile >> $tmpFile
		unset lines; while read line; do lines+=("$line"); done < $tmpFile; [[ -f $tmpFile ]] && rm -f $tmpFile
		for line in "${lines[@]}"; do
			dump -1 -n line
			unset ruleType ruleName description
			line="$(tr -d '\011\012\015' <<< $line)"
			ruleType="$(cut -d':' -f1 <<< $line)"
			line="$(cut -d':' -f2- <<< $line)"
			ruleName="$(cut -d'|' -f1 <<< $line)"
			description="${line##*//}"
			line="${line%%//*}"
			dump -1 -t ruleType ruleName description

			if [[ $ruleType == 'esiglist' ]]; then
				ParseEsig "$ruleName" "$line" "$description"
			elif [[ $ruleType == 'wfrules' ]]; then
				ParseWfrule "$ruleName" "$line" "$description"
			elif [[ $ruleType == 'wforder' ]]; then
				wforders+=("$(cut -d':' -f2 <<< "$line")")
			elif [[ $ruleType == 'voterules' ]]; then
				voterules+=("$(cut -d':' -f2 <<< "$line")")
			else
				:
			fi
		done

		# ## Sort the hask keys arrays
		# 	[[ -f $tmpFile ]] && rm $tmpFile
		# 	for key in "${substitutionVarsKeys[@]}"; do echo "$key" >> $tmpFile; done ; sort $tmpFile -o $tmpFile
		# 	unset substitutionVarsKeys; while read line; do substitutionVarsKeys+=("$line"); done < $tmpFile
		# 	[[ -f $tmpFile ]] && rm $tmpFile
		#
		# 	for key in "${wfrulesKeys[@]}"; do echo "$key" >> $tmpFile; done ; sort $tmpFile -o $tmpFile
		# 	unset wfrulesKeys; while read line; do wfrulesKeys+=("$line"); done < $tmpFile
		# 	[[ -f $tmpFile ]] && rm $tmpFile

		## Debug info
			if [[ $verboseLevel -ge 1 || $informationModeOnly == true ]]; then
				Msg3 "^substitutionVars:"; for i in "${substitutionVarsKeys[@]}"; do echo -e "\t[$i] = >${substitutionVars[$i]}<"; done;
				Msg3 "^esigs:"; for i in "${esigsKeys[@]}"; do echo -e "\t[$i] = >${esigs[$i]}<"; done;
				Msg3 "^wfrules:"; for i in "${wfrulesKeys[@]}"; do echo -e "\t[$i] = >${wfrules[$i]}<"; done;
				Msg3 "^wforders:"; for ((jj=0; jj<${#wforders[@]}; jj++)); do echo -e "\t[$jj] = >${wforders[$jj]}<"; done;
				Msg3 "^voterules:"; for ((jj=0; jj<${#voterules[@]}; jj++)); do echo -e "\t[$jj] = >${voterules[$jj]}<"; done;
			fi

		## Write out 'Substitution Vars' data
			if [[ ${#substitutionVarsKeys[@]} -gt 0 ]]; then
				cntr=1
				Msg3 "\n#\tVariable\tDescription\t\tImplementation / Comment" >> $outFile
				for i in "${substitutionVarsKeys[@]}"; do
					echo -e "$cntr\t$i\t${substitutionVars[$i]}" >> $outFile
					(( cntr += 1 ))
				done
			fi

		## Write out esigs data
			if [[ ${#esigsKeys[@]} -gt 0 ]]; then
				cntr=1
				Msg3 "\n#\tStepPattern\tDescription\t\tImplementation / Comment" >> $outFile
				for i in "${esigsKeys[@]}"; do
					echo -e "$cntr\t$i\t${esigs[$i]}" >> $outFile
					(( cntr += 1 ))
				done
				Msg3 "^^Found ${#esigsKeys[@]} Esig rules"
			fi

		## Write out 'Conditionals' data
			if [[ ${#wfrulesKeys[@]} -gt 0 ]]; then
				cntr=1
				Msg3 "\n#\tCondition\tDescription\t\tImplementation / Comment" >> $outFile
				for i in "${wfrulesKeys[@]}"; do
					echo -e "$cntr\t$i\t${wfrules[$i]}" >> $outFile
					(( cntr += 1 ))
				done
				Msg3 "^^Found ${#wfrulesKeys[@]} Conditional rules"
			fi

		## Write out 'wforder' data
			if [[ ${#wforders[@]} -gt 0 ]]; then
				Msg3 "\n#\tWorkflow\tComment" >> $outFile
				for ((i=0; i<${#wforders[@]}; i++)); do
					echo -e "$i\t${wforders[$i]}" >> $outFile
				done
				Msg3 "^^Found ${#wforders[@]} Workflow order rules"
			fi

		## Write out 'voterules' data
			if [[ ${#voterules[@]} -gt 0 ]]; then
				Msg3 "\n#\Vote Rule\t\t\tComments / Explanation" >> $outFile
				for ((i=0; i<${#voterules[@]}; i++)); do
					echo -e "$i\t${voterules[$i]}" >> $outFile
				done
				Msg3 "^^Found ${#voterules[@]} Vote rules"
			fi

	## Read the workflow.tcf file for the cim
		grepFile="$srcDir/web/$cim/workflow.tcf"
		[[ ! -r $grepFile ]] && Msg3 E "Could not read '$grepFile', skipping $cim" && continue
		Msg3 "^Parsing '$grepFile'"

		## Parse off the conditionals from the localsteps record
			localsteps=$(ProtectedCall grep 'localsteps:' $grepFile)
			[[ -z $localsteps ]] && Msg3 E "Could not retrieve 'localsteps' record from $grepFile', skipping $cim" && continue
			tokenStr=$(echo $localsteps | cut -d'|' -f4)
			tokenStr=$(echo $tokenStr | cut -d'=' -f2)
			tokenStr=$(echo $tokenStr | cut -d';' -f1)
			unset tokens
			ifs=$IFS; IFS=','; read -r -a tokens <<< "$tokenStr"; IFS=$ifs

			declare -A modifiersRef
			declare -A conditionalsRef
			## Write out a standard 'debug' workflow prefox
				Msg3 "\nworkflow:<<< LEEPFROG TESTING >>>\t\t\t\t${myName} - $(date)" >> $outFile
				Msg3 "#\tWorkflow Step\tStep Conditional(s)\tModifier(s)\tComments / Explanation" >> $outFile
				Msg3 "^START" >> $outFile
				Msg3 "^College 'Col'" >> $outFile
				Msg3 "^Department 'Dept'" >> $outFile
				Msg3 "^Subject 'Subj'" >> $outFile

				## Parse out conditionals and modifiers from the localsteps string
				for token in "${tokens[@]}"; do
					keyword=${token%%[*}
					[[ $(Contains ",$(Upper "${modifiers},${specialModifiers}")," ",$Upper($keyword),") == true ]] && continue
					keywordDef=${token##*[}
					keywordDef="$(Upper "[${keywordDef##*[}")"

					if [[ $(Contains ",$(Upper "${modifiers},${specialModifiers},''***optional***'")," ",$Upper($keyword),") == true ]]; then
						modifiersRef["$keyword"]=true
					else
						conditionalsRef["$keyword"]=true
					fi
					## Write out 'debug' workflow record
					Msg3 "^$keywordDef\t$keyword" >> $outFile

				done
				if [[ $verboseLevel -ge 1 ]]; then Msg3 "^modifiersRef:"; for i in "${!modifiersRef[@]}"; do printf "\t\t[$i] = >${modifiersRef[$i]}<\n"; done; fi
				if [[ $verboseLevel -ge 1 ]]; then Msg3 "^conditionalsRef:"; for i in "${!conditionalsRef[@]}"; do printf "\t\t[$i] = >${conditionalsRef[$i]}<\n"; done; fi

				## Write out 'debug' workflow suffix
				Msg3 "^END" >> $outFile

	## Read the workflow.tcf file for the workflows
		ProtectedCall grep '^workflow:' $grepFile > $tmpFile
		while read -r line; do
			dump -1 -n -t line
			[[ ${line:0:23} == 'workflow:standard|START' ]] && continue
			workflow=$(echo $line | cut -d'|' -f1)
			[[ $(Contains ",${ignoreWorkflows}," ",${workflow##*:},") == true ]] && continue
			Msg3 "^^Parsing '$workflow'"
			Msg3 "\n$workflow\t\t\t\t${myName} - $(date)" >> $outFile
			echo -e "#\tWorkflow Step\tStep Conditional(s)\tModifier(s)\tComments / Explanation" >> $outFile
			line=$(echo $line | cut -d'|' -f2)
			IFSSave=$IFS; IFS=','; read -r -a wfsteps <<< "$line"; IFS=$IFSSave
			stepCntr=1
			for wfstep in "${wfsteps[@]}"; do
				dump -2 -t -t wfstep
				unset step conditionals modifiers found
				for word in $wfstep; do
					dump -3 -t -t -t word
					if [[ ${conditionalsRef["$word"]} == true ]]; then conditionals="$conditionals $word"
					elif [[ ${modifiersRef["$word"]} == true ]]; then modifiers="$modifiers $word"
					else
						step="$step $word"
					fi
				done
				step=$(Trim "$step");
				[[ $(Contains ",${ignoreSteps}," ",${step},") == true ]] && continue
				conditionals=$(Trim "$conditionals");
				modifiers=$(sed s/'optional'/'(If Exists)'/g <<< $modifiers);
				modifiers=$(echo $modifiers | tr -d '*');
				echo -e "$stepCntr\t$step\t$conditionals\t$modifiers" >> $outFile
				(( stepCntr += 1 ))
			done
			Msg3 "^^^Found $stepCntr steps"
		done < $tmpFile
done # cims
Msg3
Msg3 "Processed CIMs: $cimStr"
[[ $informationOnlyMode != true ]] && Msg3 "Output written to: $outFile"
[[ -f "$tmpFile" ]] && rm "$tmpFile"

#==================================================================================================
## Done
#==================================================================================================
Goodbye 0 #'alert'

#==================================================================================================
## Check-in log
#==================================================================================================
# 11-25-2015 -- dscudiero -- Reformat workflow files to easily copied into the workflow spreadsheet (1.1)
## Wed Jun 15 12:56:55 CDT 2016 - dscudiero - set originalArgStr
## Thu Jun 16 16:55:09 CDT 2016 - dscudiero - Refactored to add outputing substituted variables and conditions
## Tue Jul  5 16:25:33 CDT 2016 - dscudiero - Do not sort the conditions
## Thu Jul  7 11:47:14 CDT 2016 - dscudiero - Refactored to seperate out esigs
## Mon Oct 24 09:14:53 CDT 2016 - dscudiero - Display directory on verifyContinue
## Mon Feb 13 16:04:12 CST 2017 - dscudiero - make sure we are using our one tmpFile
## 04-13-2017 @ 13.58.16 - (1.1.93)    - dscudiero - add a default value for verifyContinue
## 05-12-2017 @ 11.09.09 - (1.2.1)     - dscudiero - Refactor parsing substitution variables to take into account wfAttr function bindings
## 05-16-2017 @ 13.05.44 - (1.2.2)     - dscudiero - Fix output format problem with wforders
## 05-24-2017 @ 13.43.28 - (1.2.17)    - dscudiero - General syncing of dev to prod
## 08-03-2017 @ 09.55.58 - (1.2.18)    - dscudiero - Fix problems with wforders
## 09-06-2017 @ 08.34.43 - (1.2.24)    - dscudiero - Ignore standard functions and workflow steps
## 10-03-2017 @ 11.02.07 - (1.2.36)    - dscudiero - General syncing of dev to prod
## 10-06-2017 @ 09.44.03 - (1.2.37)    - dscudiero - Remove verbose calls in functions
## 10-06-2017 @ 09.47.26 - (1.2.38)    - dscudiero - remove other verbose statements
## 10-09-2017 @ 16.54.59 - (1.2.39)    - dscudiero - Cosmetic/minor change
## 10-19-2017 @ 16.56.15 - (1.2.43)    - dscudiero - Read the cimconfig.cfg file if we cannot find the workflow.cfg file
