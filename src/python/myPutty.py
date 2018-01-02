# DO NOT AUTOVERSION
# version=1.0.0 # -- dscudiero -- Thu 10/05/2017 @ 11:47:41.64
#==================================================================================================
#==================================================================================================
import inspect, sys, traceback
import os
from pathlib import Path
import argparse
import re
import datetime, time
import string
from array import *

#==================================================================================================
# Constants / initial checks
#==================================================================================================
myName=os.path.basename(__file__)
userName=os.environ['USERNAME']
userProfile=os.environ['USERPROFILE']
puttyExe="C:\Program Files\PuTTY\putty.exe"
my_file = Path(puttyExe)
if not my_file.is_file():
    Msg("*Error* -- File '" + puttyExe + "' does not exist")
    Quit(-3)

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

#==================================================================================================
# Parse arguments
#==================================================================================================
#print(sys.argv[1:])
parser=argparse.ArgumentParser()
parser.add_argument("hostName", help="The host name of the server to connect to.")
parser.add_argument("command", nargs="?", help="The command to run on the supplied host")
parser.add_argument("-cf","--configFile", nargs="?", default=userProfile + "\\" + userName + ".cfg", help="The name of the config file (optiona)")
parser.add_argument("-v","--verbosity", default=0, action="count", help="Debug informaton, -vv for more info.")

args=parser.parse_args()

hostName=args.hostName
command=args.command
configFile=args.configFile
verbosity=args.verbosity
#Msg("verbosity = >" + str(verbosity) + "<")

## Debug stuff
if verbosity > 0:
	Msg("hostName = >" + hostName + "<")
	if command != None:
		Msg("command = >" + command + "<")
	if configFile != None:
		Msg("configFile = >" + configFile + "<")
	print("")

## Check to make sure the config file exists
my_file = Path(configFile)
if not my_file.is_file():
    Msg("*Error* -- File '" + configFile + "' does not exist")
    Quit(-3)

#==================================================================================================
# Main
#==================================================================================================
## Parse the config file
fh = open(configFile);
lines = []
for line in fh.readlines():
	#line = line.replace("\n","")
	#line = line.replace("\t","")
    lines.append( line.replace("\n","").replace("\t","") )
fh.close()
foundPasswordsSection=False
for line in lines:
	if line == "" or line[:1] == "#":
		continue
	#Msg(line)
	if line[:11] == "[passwords]":
		foundPasswordsSection=True
		continue
	if foundPasswordsSection == True and line[:1] == "[":
		break
	if foundPasswordsSection:
		#Msg(line)
		tmpArray=line.split("=")
		if tmpArray[0] == hostName + ".pw":
			password=tmpArray[1]

## If we found a password then fork off the putty session
if password == None:
	Msg("Could not look up password for host: " + hostName)
	Quit(-3)
if verbosity > 0:
	Msg("password = >" + password + "<")

puttyCmdArgs=userName + "@" + hostName + ".leepfrog.com -pw " + password + " -load " + hostName
if verbosity > 0:
	Msg("puttyCmdArgs = >" + puttyCmdArgs + "<")

os.spawnl(os.P_NOWAIT, puttyExe, puttyCmdArgs)

## Done
Quit()

