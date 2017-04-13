## XO NOT AUTOVERSION

#
#  REPLACED WITH THE PROCESSLOGGER FUNCTION
#

function DbLog {
	return 0
} #DbLog
function dbLog { DbLog "$*"; }
export -f DbLog
export -f dbLog

#===================================================================================================
# Check-in Log
#===================================================================================================

## Wed Jan  4 13:53:13 CST 2017 - dscudiero - General syncing of dev to prod
## Fri Jan  6 16:40:59 CST 2017 - dscudiero - disable
## 04-13-2017 @ 08.12.10 - dscudiero - add a comment pointing to processlogger
