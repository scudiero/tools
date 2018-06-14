
#==================================================================================================
# Common imports
#==================================================================================================
from __future__ import print_function
import os, sys, inspect, sys, traceback, subprocess
from sys import version_info
import argparse
import re
import datetime, time
# import string
# from array import *

#==================================================================================================
# Constants / initial checks
#==================================================================================================
version="2.1.4" # -- dscudiero -- Wed 06/06/2018 @ 13:39:24
myName=os.path.basename(__file__)
userName=os.environ['USERNAME']
userProfile=os.environ['USERPROFILE']

#==================================================================================================
# Local Functions
#==================================================================================================
# Quick quit
def Quit(*args):
	rc=0
	if len(args) != 0: rc=str(args[0])
	exit(rc)

# Print Msgs
def Msg(*objs):
	print(myName + ": " + str(*objs), file=sys.stdout)

## Simple function to find a string in a file
def grep(pattern, file, includeLineNumbers=False, stopAtFirst=False):
	f = open(file,"r")
	grepRe = re.compile(pattern)
	retArray=[]
	#for line in file_obj:
	for lineNum, line in enumerate(f):
		line=line.rstrip()
		if grepRe.search(line):
			if includeLineNumbers:
				retArray.append(str(lineNum+1) + " " + line)
			else:
				retArray.append(line)
			if (stopAtFirst): 
				retArray.append(line)
				break
	f.close()
	return retArray


def sed(file, fromStr, toStr):
	## sed runs all the replacements in a single pass
	sedCmd = "sed -i s'_" + fromStr + "_" + toStr + "_' " + file
	if verbosity > 0: Msg("sedCmd = >" + sedCmd + "<")
	return subprocess.check_call(sedCmd, stderr=subprocess.STDOUT)

#==================================================================================================
# Parse arguments
#==================================================================================================
#print(sys.argv[1:])
parser=argparse.ArgumentParser()
parser.add_argument("fullName", help="The Full file name including path.")
parser.add_argument("filePath", nargs="?", help="The path to the file")
parser.add_argument("fileName", nargs="?", help="The basename of the file without extension")
parser.add_argument("fileExt", nargs="?", help="The extension of the file")
parser.add_argument("-v","--verbosity", default=0, action="count", help="Debug informaton, -vv for more info.")

args=parser.parse_args()

fullName=args.fullName
filePath=args.filePath
fileName=args.fileName
fileExt=args.fileExt
verbosity=args.verbosity

#==================================================================================================
# MAIN
#==================================================================================================
if verbosity > 0:
	Msg("fullName = '" + fullName + "'")
	Msg("filePath = '" + filePath + "'")
	Msg("fileName = '" + fileName + "'")
	Msg("fileExt = '" + fileExt + "'")
	Msg("verbosity = '" + str(verbosity) + "'\n")

validExtensions=["sh","py","tcf","cfg","atj"]
found = False
for ext in validExtensions:
	if fileExt == ext: 
		found = True
		break

## If we find the string 'DO NOT AUTOVERSION' then quit
grepStr=grep("DO NOT AUTOVERSION", fullName, False, True)
if len(grepStr) > 0:
	found=False

if found:
	verStr="version"
	assignmentDelim="="
	quoteStr="\""
	commentChar="#"
	if fileName == "workflowLib" and fileExt == "atj":
		verStr="wfLibVersion"
		commentChar="//"
	elif fileExt == "tcf" or fileExt == "cfg" or fileExt == "atj":
		assignmentDelim=":"
		commentChar=""
	if verbosity > 0:
		Msg("verStr = '" + verStr + "'")
		Msg("assignmentDelim = '" + assignmentDelim + "'")
		Msg("quoteStr = '" + quoteStr + "'")
		Msg("commentChar = '" + commentChar + "'")

	## Get the version data from the file
	grepStr=grep(verStr+assignmentDelim, fullName, False, True)
	if len(grepStr) > 0:
		if verbosity > 0: Msg("grepStr = '" + str(grepStr[0]) + "'" )
		fromStr=grepStr[0]
		version=fromStr.split(assignmentDelim)[1]

		## Parse version from the line
		version=version.split(" ")[0]; version = re.sub(quoteStr, '', version)
		if verbosity > 0: Msg("version = '" + str(version) + "'" )
		versionParts=version.split(".")

		# Msg("len(versionParts) = '" + str(len(versionParts)) + "'")
		# Msg("versionParts[0] = '" + versionParts[0] + "'")
		# Msg("versionParts[1] = '" + versionParts[1] + "'")
		# Msg("versionParts[2] = '" + versionParts[2] + "'")

		## Increment the editCount number, if editCount is 99 then increment the version and set editCount to 0
		if int(versionParts[2]) < 99:
			newVersion = versionParts[0] + "." + versionParts[1] + "." + str(int(versionParts[2]) + 1)
		else:
			newVersion = versionParts[0] + "." + str(int(versionParts[1]) + 1) + ".0"
		if verbosity > 0: Msg("newVersion = '" + newVersion + "'")

		## build the sed 'to' string
		toStr=verStr + assignmentDelim + quoteStr + newVersion + quoteStr + " " + commentChar + " -- " + userName + " -- " 
		toStr=toStr + datetime.datetime.today().strftime('%a %m/%d/%Y @ %H:%M:%S')
		if fileExt == "tcf" or fileExt == "cfg" or fileExt == "atj" and fileName != "workflowLib":
			toStr="// " + toStr 

		if verbosity > 0: Msg("fromStr = >" + fromStr + "<")
		if verbosity > 0: Msg("toStr = >" + toStr + "<")

		## Edit file
		sed(fullName, fromStr, toStr)
		Msg("New version: " + newVersion)


##======================================================================================================================
## Check in log
##======================================================================================================================
## 06-07-2018 @ 12:12:39 - 2.1.4 - dscudiero - Add code to detect "DO NOT AUTOVERSION"
## 06-14-2018 @ 09:51:55 - 2.1.4 - dscudiero - Add special processing for workflowLib.atj
## 06-14-2018 @ 09:57:29 - 2.1.4 - dscudiero - Cosmetic/minor change/Sync
## 06-14-2018 @ 10:00:17 - 2.1.4 - dscudiero - Cosmetic/minor change/Sync
## 06-14-2018 @ 10:17:55 - 2.1.4 - dscudiero - Added Special processing for workflowLib
## 06-14-2018 @ 10:19:49 - 2.1.4 - dscudiero - Cosmetic/minor change/Sync
## 06-14-2018 @ 12:44:11 - 2.1.4 - dscudiero - Cosmetic/minor change/Sync
