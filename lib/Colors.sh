## XO NOT AUTOVERSION
#===================================================================================================
version="2.0.4" # -- dscudiero -- 12/14/2016 @ 13:54:13.34
#===================================================================================================
#
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================
#Default Colors and Emphasis
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
		unset colorRed colorBlue colorGreen colorCyan colorMagenta colorOrange colorGrey colorDefault
		unset colorTerminate colorError colorWarn colorWarning
		noNews=true
	fi

	function ColorD { local string="$*"; echo "${colorDefaultVal}${string}${colorDefault}"; }
	function ColorK { local string="$*"; echo "${colorKey}${string}${colorDefault}"; }
	function ColorI { local string="$*"; echo "${colorInfo}${string}${colorDefault}"; }
	function ColorN { local string="$*"; echo "${colorNote}${string}${colorDefault}"; }
	function ColorW { local string="$*"; echo "${colorWarn}${string}${colorDefault}"; }
	function ColorE { local string="$*"; echo "${colorError}${string}${colorDefault}"; }
	function ColorT { local string="$*"; echo "${colorTerminate}${string}${colorDefault}"; }
	function ColorV { local string="$*"; echo "${colorVerbose}${string}${colorDefault}"; }
	function ColorM { local string="$*"; echo "${colorMenu}${string}${colorDefault}"; }

export -f ColorD ColorK ColorI ColorN ColorW ColorE ColorT ColorV ColorM

#===================================================================================================
# Checkin Log
#===================================================================================================

