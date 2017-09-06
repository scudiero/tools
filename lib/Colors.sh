#!/bin/bash
## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.16" # -- dscudiero -- Wed 09/06/2017 @ 16:44:53.73
#===================================================================================================
# Setup default colors functions and values
#===================================================================================================
# CopyrighFt 2017 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================
function Colors {
	unset colorRed colorBlue colorGreen colorCyan colorMagenta colorOrange colorGrey colorDefault
	unset colorTerminate colorError colorWarn colorWarning
	if [[ $TERM != 'dumb' ]]; then
		colorWhite='\e[97m'
		colorBlack='\e[30m'
		colorRed='\e[31m'
		colorBlue='\e[34m'
		colorGreen='\e[32m'
		colorCyan='\e[36m'
		colorMagenta='\e[35m'
		colorPurple="$colorMagenta"
		colorOrange='\e[33m'
		colorGrey='\e[90m'
		colorDefault='\e[0m'
		#colorDefaultVal='\e[0;4;90m #0=normal, 4=bold,90=foreground
		colorDefaultVal=$colorMagenta #0=normal, 4=bold,90=foreground
		colorTerminate='\e[1;97;101m' #1=bold, 97=foreground, 41=background
		colorFatalError="$colorTerminate"
		#colorTerminate='\e[1;31m'

		#backGroundColorRed='\e[41m'
		#colorTerminate=${backGroundColorRed}${colorWhite}
		colorError=$colorRed
		colorWarn=$colorMagenta
		colorKey=$colorGreen
		#colorKey=$colorMagenta
		colorWarning=$colorWarn
		colorInfo=$colorGreen
		colorNote=$colorGreen
		colorVerbose=$colorGrey
		colorMenu=$colorGreen
	else
		noNews=true
	fi

	function ColorE { local string="$*"; echo "${colorError}${string}${colorDefault}"; }
	function ColorI { local string="$*"; echo "${colorInfo}${string}${colorDefault}"; }
	function ColorT { local string="$*"; echo "${colorTerminate}${string}${colorDefault}"; }
	function ColorK { local string="$*"; echo "${colorKey}${string}${colorDefault}"; }
	return 0
}
export -f Colors
export -f ColorE
export -f ColorI
export -f ColorT
export -f ColorK

#===================================================================================================
## Check-in log
#===================================================================================================
## Wed Jan  4 13:54:41 CST 2017 - dscudiero - General syncing of dev to prod
## Thu Jan  5 07:58:49 CST 2017 - dscudiero - Refactored to correctly write data out to the appropriate file
## Thu Jan 19 12:49:07 CST 2017 - dscudiero - x
## Tue Jan 24 12:48:10 CST 2017 - dscudiero - Fix errant '%' in the output
## 05-09-2017 @ 11.55.51 - ("2.0.12")  - dscudiero - Refactored how logging is done, added an user activity log file
## 05-15-2017 @ 14.24.30 - ("2.0.14")  - dscudiero - log client and environment into the activity log
## 05-24-2017 @ 13.30.23 - ("2.0.15")  - dscudiero - Strip off the -test for test environments
