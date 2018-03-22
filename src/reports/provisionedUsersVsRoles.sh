##  #!/bin/bash
#DO NOT AUTOVERSION
#==================================================================================================
version=1.0.0 # -- dscudiero -- 10/20/2016 @ 14:58:14.98
#==================================================================================================
#= Description +===================================================================================
#
#
#==================================================================================================
#TrapSigs 'on'
imports='GetDefaultsData ParseArgs ParseArgsStd Hello Init Goodbye' #imports="$imports "
Import "$imports"

[[ $1 == '-reportName' ]] && shift || true && shift || true
originalArgStr="$*"
scriptDescription=""

# myArgList+=(-file1,4,option,file1,,script,'The file name relative to the root site directory')
# myArgList+=(-file2,4,option,file2,,script,'The file name relative to the root site directory')
# myArgList+=(-myflag,6,switch,myFlag,,script,'The file name relative to the root site directory')
#==================================================================================================
# Standard call back functions
#==================================================================================================

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
# helpSet='script,client
GetDefaultsData $myName
ParseArgsStd2 $originalArgStr
Hello
Init "getClient getEnv getDirs"

myData="Client: '$client', Env: '$env', Cims: '$cimStr' "
[[ $logInDb != false && $myLogRecordIdx != "" ]] && ProcessLogger 'Update' $myLogRecordIdx 'data' "$myData"

#===================================================================================================
# Main
#===================================================================================================
sqlite3 "$siteDir/db/clusers.sqlite" <<< "select * from users;" > $tmpFile

ifs="$IFS"; IFS=$'\r';
while read line; do
	userid=$(cut -d'|' -f2 <<< $line)
	#dump line; dump userid
	unset grepStr; grepStr=$(grep -v 'revhistorytca'  "$siteDir/web/courseleaf/roles.tcf" | grep "$userid")
	if [[ -n $grepStr ]]; then
		echo "$grepStr" > $tmpFile.grepout
		echo "'$userid' used in roles:"
		while read line; do
			role=${line%%|*}
			echo -e "\t${role##*:}"
		done < $tmpFile.grepout
	else
		echo -e "*** '$userid' not used in any roles"
	fi
done < $tmpFile
rm -f $tmpFile*

#===================================================================================================
## Done
#===================================================================================================
Goodbye 0 #'alert'

#===================================================================================================
## Check-in log
#===================================================================================================
## 03-22-2018 @ 13:03:03 - 1.0.0 - dscudiero - Updated for Msg3/Msg, RunSql2/RunSql, ParseArgStd/ParseArgStd2
