#!/bin/bash
#==================================================================================================
version=1.1.92 # -- dscudiero -- 02/13/2017 @ 16:01:22.61
#==================================================================================================
TrapSigs 'on'
imports='GetDefaultsData ParseArgs ParseArgsStd Hello Init Goodbye'
imports="$imports GetOutputFile"
Import "$imports"
originalArgStr="$*"
scriptDescription="Build workflow spreadsheet from workflow file"

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
		Msg2 $V2 "*** Starting $FUNCNAME ***"
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

		Msg2 $V2 "*** Ending $FUNCNAME ***"
		return 0
	}

	#==============================================================================================
	# Parse an wfrules record
	#==============================================================================================
	function ParseWfrule  {
		Msg2 $V2 "*** Starting $FUNCNAME ***"
		local ruleName="$1"; shift
		local line="$1"; shift
		local description="$*"
		local rtype value tmpStr
		dump -2 -t ruleName line description

		if [[ $(Contains "$line" '|attr|') == true ]]; then
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
				Msg2 $W "Unknown rule type: '$line'"
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

		Msg2 $V2 "*** Ending $FUNCNAME ***"
		return 0
	}

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
scriptNews+=("11/01/2016 - New")
helpSet='script,client,env'
GetDefaultsData $myName
ParseArgsStd
Hello
[[ $allItems == true ]] && allCims='allCims' || unset allCims
Init "getClient getEnv getDirs checkEnvs getCims $allCims"
if [[ $informationModeOnly == true ]]; then
	outFile='/dev/null'
else
	[[ $workbookFile != '' ]] && outFile="$workbookFile" || outFile="$(GetOutputFile "$client" "$env" "$product")"
fi

unset verifyArgs
verifyArgs+=("Client:$client")
verifyArgs+=("Env:$(TitleCase $env) ($srcDir)")
verifyArgs+=("CIMs:$cimStr")
verifyArgs+=("Output File:$outFile")
VerifyContinue "You are asking to generate a workflow spreadsheet for"

myData="Client: '$client', Env: '$env', Cims: '$cimStr' "
[[ $logInDb != false && $myLogRecordIdx != "" ]] && dbLog 'data' $myLogRecordIdx "$myData"


#==================================================================================================
# Main
#==================================================================================================

## Loop through CIMs
for cim in $(echo $cimStr | tr ',' ' '); do
	Msg2
	Msg2 "Processing CIM instance: '$cim'"
	grepFile="$srcDir/web/$cim/workflow.cfg"
	[[ ! -f $grepFile ]] && Msg2 $E1 "Could not locate file $grepFile" && continue
	Msg2 '-,-,-,-,false' "\n$(PadChar)" >> $outFile
	Msg2 "<<< $(Upper "$cim") >>>" >> $outFile

	## Read the workflow.cfg file for the cim
	## Parse off the wfrules
	unset substitutionVars wfrules wfrulesKeys substitutionVarsKeys esigsKeys
	declare -A wfrules ; declare -A esigs ; declare -A substitutionVars
	Msg2 "^Parsing '$grepFile'"
	#lines=($(ProtectedCall grep '^wfrules:' $grepFile))
	[[ -f $tmpFile ]] && rm -f $tmpFile
	#ProtectedCall grep '^wfrules:\|^esiglist:' $grepFile >> $tmpFile
	\grep '^wfrules:\|^esiglist:' $grepFile >> $tmpFile
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
			Msg2 "^substitutionVars:"; for i in "${substitutionVarsKeys[@]}"; do echo -e "\t[$i] = >${substitutionVars[$i]}<"; done;
			Msg2 "^esigs:"; for i in "${esigsKeys[@]}"; do echo -e "\t[$i] = >${esigs[$i]}<"; done;
			Msg2 "^wfrules:"; for i in "${wfrulesKeys[@]}"; do echo -e "\t[$i] = >${wfrules[$i]}<"; done;
		fi

	## Write out 'Substitution Vars' data
		if [[ ${#substitutionVarsKeys[@]} -gt 0 ]]; then
			cntr=1
			Msg2 "\n#\tVariable\tDescription\t\tImplementation / Comment" >> $outFile
			for i in "${substitutionVarsKeys[@]}"; do
				echo -e "$cntr\t$i\t${substitutionVars[$i]}" >> $outFile
				(( cntr += 1 ))
			done
		fi

	## Write out esigs data
		if [[ ${#esigsKeys[@]} -gt 0 ]]; then
			cntr=1
			Msg2 "\n#\tStepPattern\tDescription\t\tImplementation / Comment" >> $outFile
			for i in "${esigsKeys[@]}"; do
				echo -e "$cntr\t$i\t${esigs[$i]}" >> $outFile
				(( cntr += 1 ))
			done
			Msg2 "^^Found ${#esigsKeys[@]} Esig rules"
		fi

	## Write out 'Conditionals' data
		if [[ ${#wfrulesKeys[@]} -gt 0 ]]; then
			cntr=1
			Msg2 "\n#\tCondition\tDescription\t\tImplementation / Comment" >> $outFile
			for i in "${wfrulesKeys[@]}"; do
				echo -e "$cntr\t$i\t${wfrules[$i]}" >> $outFile
				(( cntr += 1 ))
			done
			Msg2 "^^Found ${#wfrulesKeys[@]} Conditional rules"
		fi

	## Read the workflow.tcf file for the cim
	## Parse off the conditionals
		grepFile="$srcDir/web/$cim/workflow.tcf"
		[[ ! -r $grepFile ]] && Msg2 E "Could not read '$grepFile', skipping $cim" && continue
		Msg2 "^Parsing '$grepFile'"
		localsteps=$(ProtectedCall grep 'localsteps:' $grepFile)
		[[ $localsteps == '' ]] && Msg2 E "Could not retrieve 'localsteps' record from $grepFile', skipping $cim" && continue
		tokenStr=$(echo $localsteps | cut -d'|' -f4)
		tokenStr=$(echo $tokenStr | cut -d'=' -f2)
		tokenStr=$(echo $tokenStr | cut -d';' -f1)
		IFSSave=$IFS; IFS=','; read -r -a tokens <<< "$tokenStr"; IFS=$IFSSave
		declare -A modifiersRef
		declare -A conditionalsRef
		## Write out 'debug' workflow prefox
			Msg2 "\nworkflow:<<< LEEPFROG TESTING >>>\t\t\t\t${myName} - $(date)" >> $outFile
			Msg2 "#\tWorkflow Step\tStep Conditional(s)\tModifier(s)\tComments / Explanation" >> $outFile
			Msg2 "^START" >> $outFile
			Msg2 "^College 'Col'" >> $outFile
			Msg2 "^Department 'Dept'" >> $outFile
			Msg2 "^Subject 'Subj'" >> $outFile

			## Parse out conditionals and modifiers
			for token in "${tokens[@]}"; do
				[[ $token == 'optional' || $token == 'fyi' || $token  == 'fyiall' ]] && continue
				token=$(echo $token | cut -d'[' -f1)
				token2="[$(Upper "$(echo $token | cut -d'[' -f2)")]"
				[[ $token == 'fyi' || $token == 'fyiall' || $token == 'optional' || $token == '***optional***' ]] && modifiersRef["$token"]=true || conditionalsRef["$token"]=true
				## Write out 'debug' workflow record
					Msg2 "^$token2\t$token" >> $outFile
			done
			if [[ $verboseLevel -ge 1 ]]; then Msg2 "^modifiersRef:"; for i in "${!modifiersRef[@]}"; do printf "\t\t[$i] = >${modifiersRef[$i]}<\n"; done; fi
			if [[ $verboseLevel -ge 1 ]]; then Msg2 "^conditionalsRef:"; for i in "${!conditionalsRef[@]}"; do printf "\t\t[$i] = >${conditionalsRef[$i]}<\n"; done; fi

			## Write out 'debug' workflow suffix
			Msg2 "^END" >> $outFile


	## Read the workflow.tcf file for the workflows
		ProtectedCall grep '^workflow:' $grepFile > $tmpFile
		while read -r line; do
			dump -1 -n -t line
			workflow=$(echo $line | cut -d'|' -f1)
			[[ $workflow == 'workflow:<<< LEEPFROG TESTING >>>' ]] && continue
			Msg2 "^^Parsing '$workflow'"
			Msg2 "\n$workflow\t\t\t\t${myName} - $(date)" >> $outFile
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
				conditionals=$(Trim "$conditionals");
				modifiers=$(sed s/'optional'/'(If Exists)'/g <<< $modifiers);
				modifiers=$(echo $modifiers | tr -d '*');
				echo -e "$stepCntr\t$step\t$conditionals\t$modifiers" >> $outFile
				(( stepCntr += 1 ))
			done
			Msg2 "^^^Found $stepCntr steps"
		done < $tmpFile
done # cims
Msg2
Msg2 "Processed CIMs: $cimStr"
[[ $informationOnlyMode != true ]] && Msg2 "Output written to: $outFile"
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
