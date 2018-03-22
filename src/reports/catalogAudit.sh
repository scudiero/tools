#!/bin/bash
#XO NOT AUTOVERSION
version=1.0.21 # -- dscudiero -- Thu 03/22/2018 @ 13:02:31.88
originalArgStr="$*"
scriptDescription=""
TrapSigs 'on'

#= Description +===================================================================================
#
#
#==================================================================================================
#==================================================================================================
# Standard call back functions
#==================================================================================================
function catalogAudit-ParseArgsStd2  { # or parseArgs-local
	#myArgs+=("shortToken|longToken|type|scriptVariableName|<command to run>|help group|help textHelp")
	myArgs+=('email|emailAddrs|option|emailAddrs||script|Email addresses to send reports to when running in batch mode')
	myArgs+=('report|reportName|option|emailAdreportNamedrs||script|The origional report name')
	myArgs+=('ignoreX|ignoreXmlFiles|switch|ignoreXmlFiles||script|Ignore extra xml files')
	myArgs+=('fix|fix|switch|fixMode||script|Remove the errant files')
	return 0
}

#==================================================================================================
# local functions
#==================================================================================================

#==================================================================================================
# Check all the files found in a page's directory to make sure they are listed on an externfiles
# record in the tcf file.  ignore .tcf, .tcs, and .tso files.
# Also do the .xml file processing
#==================================================================================================
function CheckExternfiles {
	local dir=$1
	local grepFile grepStr extraFilesStr

	local cwd=$(pwd); cd $dir
	## Check to make sure any existing files have extern records in the tcf file
	local files=($(find -mindepth 1 -maxdepth 1 -type f ! -name "*.tcf" ! -name "*.tca" ! -name "*.tso" ! -name "*.html" ))
	#dump -n dir
	for file in "${files[@]}"; do
		file=${file:2}
		if [[ $file == 'index.xml' ]]; then
			[[ $xmlFilesOk == true || $ignoreXmlFiles == true ]] && continue
			#[[ $fixMode == true ]] && rm -f ./$file && continue
			extraFilesStr="$extraFilesStr, $file"
			continue
		else
			grepFile="$(pwd)/index.tcf"
			unset grepStr; grepStr=$(ProtectedCall "grep \"externfiles:$file\" "$grepFile"")
			[[ $grepStr == '' ]] && extraFilesStr="$extraFilesStr, $file"
		fi

	done
	[[ $extraFilesStr != '' ]] && pagesWithExtraFiles+=("$dir (${extraFilesStr:2})") # && echo -e "pagesWithExtraFiles(${#pagesWithExtraFiles[@]}) - $dir"
	cd $cwd

	return 0
}

#==================================================================================================
# Check to see if the page is listed inthe pages database
#==================================================================================================
function CheckPageDb {
	local dir=$1

	local cwd=$(pwd); cd $dir
	sqlStmt="select count(*) from livepages where path=\"$dir/index.html\""
	RunSql "$siteDir/courseleaf/pagedb.dat" $sqlStmt
	[[ ${resultSet[0]} -eq 0 ]] && pagesNotInPagesDb+=("$dir")
	cd $cwd

	return 0
}

#==================================================================================================
# Declare local variables and constants
#==================================================================================================
tmpFile=$(mkTmpFile)
trueVars=''
falseVars='fixMode'
for var in $trueVars; do eval $var=true; done
for var in $falseVars; do eval $var=false; done

outDir=/home/$userName/Reports/$myName
[[ ! -d $outDir ]] && mkdir -p $outDir
outFile=$outDir/$(date '+%Y-%m-%d-%H%M%S').txt;

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
helpSet='script,client,env'
ParseArgsStd2 $originalArgStr
[[ $reportName != '' ]] && GetDefaultsData "$reportName" "$reportsTable"

Hello
allCims=true
Init "getClient getEnv getDirs checkEnvs getCims"

# unset fixMode; Prompt fixMode "Do you wish to remove ignore errant xml files?" 'Yes No' 'No'; fixMode=$(Lower ${fixMode:0:1});
# [[ $fixMode == 'y' ]] && fixMode=true
# [[ $fixMode == 'n' ]] && fixMode=false

if [[ $ignoreXmlFiles == '' && $verify == true ]]; then
	Prompt ignoreXmlFiles "Do you wish to ignore errant xml files?" 'Yes No' 'No'; ignoreXmlFiles=$(Lower ${ignoreXmlFiles:0:1});
	[[ $ignoreXmlFiles == 'y' ]] && ignoreXmlFiles=true || ignoreXmlFiles=false
fi

unset verifyArgs
verifyArgs+=("Client:$client")
verifyArgs+=("Env:$(TitleCase $env)")
[[ $ignoreXmlFiles == true ]] && verifyArgs+=("Ignore 'extra' xml files:$ignoreXmlFiles")
[[ $fix == true ]] && verifyArgs+=("Remove errant files:$fix")
verifyArgs+=("Output File:$outFile")
VerifyContinue "You are asking to run the $myName report for"

myData="Client: '$client', Env: '$env', Cims: '$cimStr' "
[[ $logInDb != false && $myLogRecordIdx != "" ]] && dbLog 'data' $myLogRecordIdx "$myData"

#===================================================================================================
# Main
#===================================================================================================
## Get the list of directories to ignore
	Msg "Gathering courseleaf directories..."
	[[ $ignoreList = 'NULL' ]] && unset ignoreList
	cd $skeletonRoot/release/web
	ignoreList+=($(find -mindepth 1 -maxdepth 1 -type d -printf "%f\n"))
	unset ignoreStr
	for dir in "${ignoreList[@]}"; do
		[[ $ignoreStr == '' ]] && ignoreStr="-path ./$dir -prune" || ignoreStr="$ignoreStr -o -path ./$dir -prune"
	done

## Add the CIMS to the ignoreStr
	for cim in $(tr ',' ' ' <<< $cimStr ); do
		[[ $ignoreStr == '' ]] && ignoreStr="-path ./$cim -prune" || ignoreStr="$ignoreStr -o -path ./$cim -prune"
	done

## Check to see if courseleaf can create additional files
	xmlFilesOk=false
	grepFile="$siteDir/web/courseleaf/localsteps/default.tcf"
	grepStr=$(ProtectedCall "grep \"xmleverypage:\" $grepFile")
	if [[ $grepStr != '' ]]; then
		xmleverypage=$(Lower $(cut -d':' -f2 <<< $grepStr))
		[[ $xmleverypage == 'both' ]] && xmlFilesOk=true
	fi
	dump -1 xmleverypage xmlFilesOk ignoreXmlFiles

## Get the list of client directories
	unset pagesMissingTcfs pagesWithoutFiles pagesWithExtraFiles pagesNotInPagesDb
	cntr=1
	Msg "Analyzing client pages..."
	cd $siteDir/web
	## Have to use tmpfile because some directry names contain spaces!
 	find -mindepth 1 $ignoreStr -o -type d -print > $tmpFile
 	numPages=$(wc -l < $tmpFile)
 	Msg "^Found $numPages Pages"
 	while read -r dir; do
		## does the client directory contain files
		count=$(find "$dir" -mindepth 1 -maxdepth 1 -type f | wc -l)
		if [[ $count -eq 0 ]]; then
			pagesWithoutFiles+=("$dir")
			#echo -e "pagesWithoutFiles(${#pagesWithoutFiles[@]}) - $dir"
		else
			if [[ ! -f $dir/index.tcf ]]; then
				pagesMissingTcfs+=("$dir")
				#echo -e "pagesMissingTcfs(${#pagesMissingTcfs[@]}) - $dir"
			else
				CheckExternfiles "$dir"
			fi
		fi
 		[[ $(($cntr % 100)) -eq 0 ]]  && Msg "^Processed $cntr pages out of $numPages..."
 		let cntr=$cntr+1
		#[[ $cntr -eq 20 ]] && break
 	done < $tmpFile
 	rm -rf $tmpFile

#echo "\${#pagesWithoutFiles[@]} = >${#pagesWithoutFiles[@]}<"
#echo "\${#pagesMissingTcfs[@]} = >${#pagesMissingTcfs[@]}<"
#echo "\${#pagesWithExtraFiles[@]} = >${#pagesWithExtraFiles[@]}<"

## Generate report
if [[ $secondaryMessagesOnly != true ]]; then
	clear
	Msg | tee -a $outFile
	Msg "Report: $myName" | tee -a $outFile
	Msg "Date: $(date)" | tee -a $outFile
	Msg "Client: $client" | tee -a $outFile
	Msg "Env: $env" | tee -a $outFile
	[[ $ignoreXmlFiles == true ]] && Msg "Ignore 'extra' xml files: $ignoreXmlFiles" | tee -a $outFile
	[[ $fix == true ]] && Msg "Remove errant files: $fix" | tee -a $outFile
	Msg | tee -a $outFile
fi

Msg | tee -a $outFile
if [[ ${#pagesMissingTcfs} -gt 0 ]]; then
	Msg "1) Found ${#pagesMissingTcfs[@]} pages missing .tcf files:" | tee -a $outFile
	for dir in "${pagesMissingTcfs[@]}"; do
		Msg "^${dir:1}" | tee -a $outFile
	done
else
	Msg "1) Found no client pages missing .tcf files" | tee -a $outFile
fi

Msg | tee -a $outFile
if [[ ${#pagesWithoutFiles} -gt 0 ]]; then
	Msg "2) Found ${#pagesWithoutFiles[@]}  pages have zero files in the page directory:" | tee -a $outFile
	for dir in "${pagesWithoutFiles[@]}"; do
		Msg "^${dir:1}" | tee -a $outFile
	done
else
	Msg "2) Found no client pages with zero files" | tee -a $outFile
fi

Msg | tee -a $outFile
if [[ ${#pagesWithExtraFiles} -gt 0 ]]; then
	Msg "3) Found ${#pagesWithExtraFiles[@]} pages have files the page directory not listed with an 'externfiles:' entry" | tee -a $outFile
	for dir in "${pagesWithExtraFiles[@]}"; do
		Msg "^${dir:1}" | tee -a $outFile
	done
else
	Msg "3) Found no client pages with 'extra' files" | tee -a $outFile
fi

Msg | tee -a $outFile
if [[ ${#pagesNotInPagesDb} -gt 0 ]]; then
	Msg "4) Found ${#pagesNotInPagesDb[@]} pages are not listed in the pages db" | tee -a $outFile
	for dir in "${pagesNotInPagesDb[@]}"; do
		Msg "^${dir:1}" | tee -a $outFile
	done
else
	Msg "4) Found no client pages missing from the pages db" | tee -a $outFile
fi

[[ $secondaryMessagesOnly != true ]] && Msg && Msg "Output was saved in '$outFile'"

#===================================================================================================
## Done
#===================================================================================================
secondaryMessagesOnly=false
[[ $secondaryMessagesOnly == true ]] && secondaryMessagesOnly=false && return 0
[[ -f "$tmpFile" ]] && rm "$tmpFile"
Goodbye 0

#===================================================================================================
## Check-in log
#===================================================================================================
## Mon Feb 13 16:09:13 CST 2017 - dscudiero - make sure we have our own tmpFile
## 05-26-2017 @ 06.39.10 - (1.0.19)    - dscudiero - Change cleanup code
## 03-22-2018 @ 13:02:45 - 1.0.21 - dscudiero - Updated for Msg3/Msg, RunSql2/RunSql, ParseArgStd/ParseArgStd2
