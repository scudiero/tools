## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.10" # -- dscudiero -- Tue 11/07/2017 @  7:36:50.73
#===================================================================================================
# Run a command and ignore non zero exit code trapping
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function ProtectedCall {
	Import "SetFileExpansion"
	previousTrapERR=$(trap -p ERR | cut -d ' ' -f3-)
	trap - ERR
	[[ $verbose == true && $verboseLevel -gt 1 ]] && printf "\n$FUNCNAME - $(date)\n" >> $stdout && printf "\tcwd: $(pwd)\n" >> $stdout && printf "\t$*\n\n" >> $stdout
	SetFileExpansion 'on'
	rc=0
	eval "$*"
	rc=$?
	SetFileExpansion
	[[ -n $previousTrapERR ]] && eval "trap $previousTrapERR"
	return 0
} #ProtectedCall
export -f ProtectedCall

#===================================================================================================
# Check-in Log
#===================================================================================================

## Wed Jan  4 13:54:11 CST 2017 - dscudiero - General syncing of dev to prod
## Wed Jan 11 15:38:48 CST 2017 - dscudiero - switch format of some if statementst to se -n
## 05-05-2017 @ 13.21.26 - ("2.0.9")   - dscudiero - Remove GD code
## 11-07-2017 @ 07.37.15 - ("2.0.10")  - dscudiero - Import SetFileExpansion
