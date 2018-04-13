#!/bin/bash
#==================================================================================================
version=1.2.124 # -- dscudiero -- Fri 04/13/2018 @  8:59:11.37
#==================================================================================================
TrapSigs 'on'
includes='GetDefaultsData ParseArgsStd Hello DbLog Init Goodbye VerifyContinue MkTmpFile'
includes="$includes GetOutputFile ProtectedCall"
Import "$includes"

originalArgStr="$*"
scriptDescription="Extracts workflow data in a format that facilitates pasteing into a MS Excel workbook"

#==================================================================================================
# Parse site workflow files and print workflow in a friendly format
#==================================================================================================
#==================================================================================================
# Copyright ©2018 David Scudiero -- all rights reserved.
# xx-xx-15 -- dgs - Initial coding
#==================================================================================================

#==================================================================================================
# local functions
#==================================================================================================
	#==============================================================================================
	# parse script specific arguments
	#==============================================================================================
	function getCimWorkflows-ParseArgsStd {
		myArgs+=("w|workbookFile|option|workbookFile||help group|The fully qualified output workbook file name")
		return 0
	}

	#==============================================================================================
	# Goodbye call back
	#==============================================================================================
	function getCimWorkflows-Goodbye {
		eval $errSigOn
		if [[ -f $stepFile ]]; then echo rm stepFile; rm -f $stepFile; fi
		if [[ -f $backupStepFile ]]; then mv -f $backupStepFile $stepFile; fi
		[[ -f "$tmpFile" ]] && rm "$tmpFile"
		return 0
	}

	#==============================================================================================
	# TestMode overrides
	#==============================================================================================
	function getCimWorkflows-testMode {
		env='dev'
		srcDir=~/testData/dev
		return 0
	}

	#==============================================================================================
	# Parse an esig record
	#==============================================================================================
	function ParseEsig {
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
	function ParseWfrule {
		local ruleName="$1"; shift
		local line="$1"; shift
		local description="$*"
		local rtype value tmpStr
		dump -2 line -t ruleName description

		[[ $(Contains ",${ignoreRules}," ",${ruleName},") == true ]] && return 0

		if [[ $(Contains "$line" '|attr|') == true || $(Contains "$line" '|function|wfAttr|') == true || \
			$(Contains "$line" '|function|Related|') == true || $(Contains "$line" '|function|GetAcadLevel') == true || \
			$(Contains "$line" 'ProposalState') == true || $(Contains "$line" 'NotifyAllApprovers') == true || \
			$(Contains "$line" 'RelatedDepts') == true || \
			$(Contains "$wfOverrideSubstitutionVars" ",${ruleName^^[a-z]},") == true ]]; then
			#line = >Col|attr|college_prog.code|; <
			substitutionVars[$ruleName]="$description\t\tattr{$(cut -d'|' -f3 <<< "$line")}"
			substitutionVarsKeys+=($ruleName)
		else
			rtype="$(cut -d'|' -f2 <<< "$line")"
			value="$(cut -d'|' -f3- <<< "$line")"
			#line = >addProvost|function|AddProvost|; <
			if [[ $(Contains "$line" '|function|') == true ]]; then
				value="${value#;*}"
			#line = >iffieldmatch|acad_level.code|value=UG; <
			elif [[ $(Contains "$line" '|iffieldmatch|') == true ]]; then
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
ParseArgsStd $originalArgStr
[[ -n $unknowArgs ]] && cimStr="$unknowArgs"
[[ $allItems == true ]] && allCims='allCims' || unset allCims
Init "getClient getEnv getDirs checkEnvs getCims addPvt $allCims"
if [[ $informationModeOnly == true ]]; then
	outFile='/dev/null'
else
	[[ -n $workbookFile ]] && outFile="$workbookFile" || outFile="$(GetOutputFile "$client" "$env" "$product" "xls")"
fi

unset ignoreRules ignoreSteps ignoreWorkflows
ignoreRules="$(cut -d':' -f2- <<< $scriptData1)"
ignoreSteps="$(cut -d':' -f2- <<< $scriptData2)"
ignoreWorkflows="$(cut -d':' -f2- <<< $scriptData3)"
stdModifiers="$(cut -d':' -f2- <<< $scriptData4)"

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
SetFileExpansion 'off'
## Write out header data to the output file
	Msg "\n$myName ($version) $userName @ $(date)" > $outFile
	Msg "CIMs: $cimStr" >> $outFile

## Loop through CIMs
for cim in ${cimStr//,/ }; do
	Msg
	Msg "Processing CIM instance: '$cim'"
	grepFile="$srcDir/web/$cim/workflow.cfg"
	if [[ ! -f $grepFile ]]; then
		Warning "Could not locate file $(basename $grepFile), trying cimconfig.cfg"
		grepFile="$srcDir/web/$cim/cimconfig.cfg"
		[[ ! -f $grepFile ]] && Terminate "Could not locate file $grepFile"
	fi
	Msg "\n$(PadChar)" >> $outFile
	Msg "<<< $(Upper "$cim") >>>" >> $outFile

	## Read the workflow.cfg file for the cim
		## Get any special modifiers
			specialModifiers=$(ProtectedCall grep 'wfSpecialModifiers:' $grepFile)
			[[ -n $specialModifiers ]] && myModifiers="${specialModifiers##*:},$stdModifiers" || myModifiers="$stdModifiers"
			myModifiers="${myModifiers^^[a-z]}"

		## Get any over rided substitution variable names
			wfOverrideSubstitutionVars=$(ProtectedCall grep 'wfOverrideSubstitutionVars:' $grepFile)
			[[ -n $wfOverrideSubstitutionVars ]] && wfOverrideSubstitutionVars="${wfOverrideSubstitutionVars##*:}"
			wfOverrideSubstitutionVars=",${wfOverrideSubstitutionVars^^[a-z]},"

		## Parse off the wfrules
		unset substitutionVars wfrules wfrulesKeys substitutionVarsKeys esigsKeys wforders
		declare -A wfrules ; declare -A esigs ; declare -A substitutionVars
		Msg "^Parsing '$grepFile'"
		[[ -f $tmpFile ]] && rm -f $tmpFile
		\grep '^wfrules:\|^wforder:\|^esiglist:\|^voterules:\|^wfUgRe:\|^wfGrRe:' $grepFile >> $tmpFile
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
				##voterules:voteName| stepRegex|duration|attribute1;attribute2,...
				ruleName="$(cut -d'|' -f1 <<< "${line#*:}")"
				ruleRegex="$(cut -d'|' -f2 <<< "$line")"
				duration="$(cut -d'|' -f3 <<< "$line")"; [[ $duration == '0' ]] && duration='none'
				attributes="$(cut -d'|' -f4- <<< "$line")"; attributes="${attributes//;/; }"
				voterules+=("$ruleName / \"$ruleRegex\"\tDuration: $duration, Attributes: $attributes")
			elif [[ $ruleType == 'wfUgRe' ]]; then
				wfUgRe="$(cut -d':' -f2- <<< "$line")"
			elif [[ $ruleType == 'wfGrRe' ]]; then
				wfGrRe="$(cut -d':' -f2- <<< "$line")"
			else
				:
			fi
		done

		dump -1 -t wfUgRe wfGrRe

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
				Msg "^substitutionVars:"; for i in "${substitutionVarsKeys[@]}"; do echo -e "\t[$i] = >${substitutionVars[$i]}<"; done;
				Msg "^esigs:"; for i in "${esigsKeys[@]}"; do echo -e "\t[$i] = >${esigs[$i]}<"; done;
				Msg "^wfrules:"; for i in "${wfrulesKeys[@]}"; do echo -e "\t[$i] = >${wfrules[$i]}<"; done;
				Msg "^wforders:"; for ((jj=0; jj<${#wforders[@]}; jj++)); do echo -e "\t[$jj] = >${wforders[$jj]}<"; done;
				Msg "^voterules:"; for ((jj=0; jj<${#voterules[@]}; jj++)); do echo -e "\t[$jj] = >${voterules[$jj]}<"; done;
			fi

		## Write out 'Substitution Vars' data
			if [[ ${#substitutionVarsKeys[@]} -gt 0 ]]; then
				cntr=1
				Msg "\nSubstitued Variables:" >> $outFile
				Msg "This section defines variables that may appear in workflow step names that will be substituted with the corresponding value in the proposal when the proposal is place into workflow." >> $outFile
				Msg ".e.g. if a workflow step name is 'Dept Chair' and the current proposal value for department is 'ENG' then the resolved step name will be 'ENG Chair'" >> $outFile
				Msg "Note that all names are case sensitive, i.e. 'Abc' does not equal 'abc'." >> $outFile
				Msg "#\tVariable\tDescription\t\tImplementation / Comment" >> $outFile
				for i in "${substitutionVarsKeys[@]}"; do
					echo -e "$cntr\t$i\t${substitutionVars[$i]}" >> $outFile
					(( cntr += 1 ))
				done
				Msg "^^Found ${#substitutionVars[@]} Substitutiuon variables"
			fi

		## Write out 'Conditionals' data
			if [[ ${#wfrulesKeys[@]} -gt 0 ]]; then
				cntr=1
				Msg "\nConditional Definitions:" >> $outFile
				Msg "This section defines the conditionals that may be applied to a step, if the conditional evaluates to true then the step will be included in the calculated workflow." >> $outFile
				Msg "ALL conditionals applied to a step must evaluate to true.for that step to be included." >> $outFile
				Msg "e.g. if an 'Is New' conditional is applied to a step, that step will only be included in the workflow for new proposals." >> $outFile
				Msg "Note that all names are case sensitive, i.e. 'Abc' does not equal 'abc'." >> $outFile
				Msg "#\tCondition\tDescription\t\tImplementation / Comment" >> $outFile
				for i in "${wfrulesKeys[@]}"; do
					conditionalDef=$(sed s/'%7C'/' | '/g <<< "${wfrules[$i]}");					
					[[ -n "$wfUgRe" ]] && conditionalDef=$(sed s/'wfUgRe'/"$(sed 's/[^a-zA-Z 0-9]/\\&/g' <<< "$wfUgRe")"/g <<< $conditionalDef);
					[[ -n "$wfGrRe" ]] && conditionalDef=$(sed s/'wfGrRe'/"$(sed 's/[^a-zA-Z 0-9]/\\&/g' <<< "$wfGrRe")"/g <<< $conditionalDef);
					echo -e "$cntr\t$i\t$conditionalDef" >> $outFile
					(( cntr += 1 ))
				done
				Msg "^^Found ${#wfrulesKeys[@]} Conditional rules"
			fi

		## Write out esigs data
			if [[ ${#esigsKeys[@]} -gt 0 ]]; then
				cntr=1
				Msg "\nEsig/Delayed Approval setup:" >> $outFile
				Msg "Note that all names are case sensitive, i.e. 'Abc' does not equal 'abc'." >> $outFile
				Msg "#\tStepPattern\tDescription\t\tImplementation / Comment" >> $outFile
				for i in "${esigsKeys[@]}"; do
					echo -e "$cntr\t$i\t${esigs[$i]}" >> $outFile
					(( cntr += 1 ))
				done
				Msg "^^Found ${#esigsKeys[@]} Esig rules"
			fi

		## Write out 'voterules' data
			if [[ ${#voterules[@]} -gt 0 ]]; then
				cntr=1
				Msg "\nVoting rules:" >> $outFile
				Msg "Note that all names are case sensitive, i.e. 'Abc' does not equal 'abc'." >> $outFile
				Msg "#\Vote Rule\t\t\tComments / Explanation" >> $outFile
				for ((i=0; i<${#voterules[@]}; i++)); do
					echo -e "$cntr\t${voterules[$i]}" >> $outFile
					(( cntr += 1 ))
				done
				Msg "^^Found ${#voterules[@]} Vote rules"
			fi

		## Write out 'wforder' data
			if [[ ${#wforders[@]} -gt 0 ]]; then
				cntr=1
				Msg "\nWorkflow Order:" >> $outFile
				Msg "This section describes the order in which workflow will be selected, note this often uses the substitution variables defined above and the" >> $outFile
				Msg "proposal state information" >> $outFile
				Msg "#\tWorkflow\t\t\tComments / Explanation" >> $outFile
				for ((i=0; i<${#wforders[@]}; i++)); do
					echo -e "$cntr\t${wforders[$i]}" >> $outFile
					(( cntr += 1 ))
				done
				Msg "^^Found ${#wforders[@]} Workflow order rules"
			fi

	## Write out 'workflow' data
		Msg "\nWorkflow ." >> $outFile
		Msg "This section defines the various workflows and the steps in those workflows." >> $outFile
		Msg "The order that workflows are defined in the section is the order that the system will look for a matching workflow, the first one found will be use." >> $outFile
		Msg "e.g. If there is a workflow defined as 'Dept standard' , and there is a workflow defined with the name 'ENG standard', when the proposal is put into workflow," >> $outFile
		Msg "if the proposal's department is 'ENG' then the 'ENG standard' workflow will be selected." >> $outFile
		Msg "Note that all names are case sensitive, i.e. 'Abc' does not equal 'abc'." >> $outFile

	## Read the workflow.tcf file for the cim
		grepFile="$srcDir/web/$cim/workflow.tcf"
		[[ ! -r $grepFile ]] && Msg E "Could not read '$grepFile', skipping $cim" && continue
		Msg "^Parsing '$grepFile'"

		## Parse off the conditionals from the localsteps record
			localsteps=$(ProtectedCall grep 'localsteps:' $grepFile)
			[[ -z $localsteps ]] && Msg E "Could not retrieve 'localsteps' record from $grepFile', skipping $cim" && continue
			tokenStr=$(echo $localsteps | cut -d'|' -f4)
			tokenStr=$(echo $tokenStr | cut -d'=' -f2)
			tokenStr=$(echo $tokenStr | cut -d';' -f1)
			unset tokens
			ifs=$IFS; IFS=','; read -r -a tokens <<< "$tokenStr"; IFS=$ifs

			declare -A modifiersRef
			declare -A conditionalsRef
			## Write out a standard 'debug' workflow prefox
				Msg "\nworkflow:<<< LEEPFROG TESTING >>>\t\t\t\t${myName} - $(date)" >> $outFile
				Msg "#\tWorkflow Step\tStep Conditional(s)\tModifier(s)\tComments / Explanation" >> $outFile
				Msg "^START" >> $outFile
				Msg "^College 'Col'" >> $outFile
				Msg "^Department 'Dept'" >> $outFile
				Msg "^Subject 'Subj'" >> $outFile

				## Parse out conditionals and modifiers from the localsteps string
				for token in "${tokens[@]}"; do
					keyword=${token%%[*}
					#[[ $(Contains ",$(Upper "${modifiers},${specialModifiers}")," ",$Upper($keyword),") == true ]] && continue
					keywordDef=${token##*[}
					keywordDef="$(Upper "[${keywordDef##*[}")"
					if [[ $(Contains ",$myModifiers," ",$(Upper "$keyword"),") == true ]] ; then
						modifiersRef["$keyword"]=true
					else
						conditionalsRef["$keyword"]=true
					fi
					## Write out 'debug' workflow record
					Msg "^$keywordDef\t$keyword" >> $outFile
				done
				if [[ -n $specialModifiers ]]; then
					for token in $(tr ',' ' ' <<< ${specialModifiers##*:}); do
						modifiersRef["$token"]=true
					done
				fi
				if [[ $verboseLevel -ge 1 ]]; then Msg "^modifiersRef:"; for i in "${!modifiersRef[@]}"; do printf "\t\t[$i] = >${modifiersRef[$i]}<\n"; done; fi
				if [[ $verboseLevel -ge 1 ]]; then Msg "^conditionalsRef:"; for i in "${!conditionalsRef[@]}"; do printf "\t\t[$i] = >${conditionalsRef[$i]}<\n"; done; fi

				## Write out 'debug' workflow suffix
				Msg "^END" >> $outFile

	## Read the workflow.tcf file for the workflows
		ProtectedCall grep '^workflow:' $grepFile > $tmpFile
		SetFileExpansion 'off'
		while read -r line; do
			dump -1 -n -t line
			[[ ${line:0:23} == 'workflow:standard|START' ]] && continue
			workflow=$(echo $line | cut -d'|' -f1)
			[[ $(Contains ",${ignoreWorkflows}," ",${workflow##*:},") == true ]] && continue
			Msg "^^Parsing '$workflow'"
			Msg "\n$workflow\t\t\t\t${myName} - $(date)" >> $outFile
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
				modifiers=$(sed s/'optional'/'(If role exists)'/g <<< $modifiers);
				modifiers=$(sed s/'fyiall'/'(Notify All)'/g <<< $modifiers);
				modifiers=$(sed s/'fyi'/'(Notify First)'/g <<< $modifiers);
				modifiers=$(echo $modifiers | tr -d '*');
				echo -e "$stepCntr\t$step\t$conditionals\t$modifiers" >> $outFile
				(( stepCntr += 1 ))
			done
			Msg "^^^Found $stepCntr steps"
		done < $tmpFile
		SetFileExpansion
done # cims
Msg
Msg "Processed CIMs: $cimStr"
[[ $informationOnlyMode != true ]] && 
	{ Msg "Output written to: $outFile"; Msg "You can create a Excel workbook using the template work sheet:\n^$TOOLSPATH/workbooks/CIMWorkflows.xltm"; } 
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
## 10-20-2017 @ 08.50.19 - (1.2.60)    - dscudiero - Fix problem detectiong modifiers, reformatted output
## 10-31-2017 @ 10.15.04 - (1.2.62)    - dscudiero - Fixed setup of the callback functions
## 11-02-2017 @ 06.58.49 - (1.2.65)    - dscudiero - Switch to ParseArgsStd
## 11-02-2017 @ 11.02.06 - (1.2.66)    - dscudiero - Add addPvt to the init call
## 11-13-2017 @ 16.57.23 - (1.2.79)    - dscudiero - Fix problem parsing modifiers and special modifiers
## 12-13-2017 @ 15.41.39 - (1.2.80)    - dscudiero - Add message where the excel template file can be found
## 03-14-2018 @ 13:46:47 - 1.2.81 - dscudiero - Tweak looking for acadlevel for a substitution variablew
## 03-15-2018 @ 12:59:57 - 1.2.82 - dscudiero - D
## 03-19-2018 @ 14:00:57 - 1.2.91 - dscudiero - Translate the %7C in conditionals to |
## 03-19-2018 @ 14:51:00 - 1.2.101 - dscudiero - Tweak the verbiage used on the modifiers
## 03-23-2018 @ 15:34:46 - 1.2.102 - dscudiero - D
## 03-23-2018 @ 16:57:57 - 1.2.103 - dscudiero - Msg -> Msg
## 03-23-2018 @ 17:04:49 - 1.2.104 - dscudiero - Msg3 -> Msg
## 03-29-2018 @ 12:58:45 - 1.2.110 - dscudiero - Added code to escape the sed string for wfUG/GRre
## 04-13-2018 @ 09:10:24 - 1.2.124 - dscudiero - Added override substitution variables, fixed but where '*' were getting expanded on output
