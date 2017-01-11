## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.8" # -- dscudiero -- 01/11/2017 @ 15:38:06.80
#===================================================================================================
# Run a command and ignore non zero exit code trapping
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function ProtectedCall {
	#GD echo "In $FUNCNAME \$\* = >"$*'<'
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
