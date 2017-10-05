#!/bin/python
# DO NOT AUTOVERSION
# version=1.3.0 # -- dscudiero -- Thu 10/05/2017 @ 11:47:41.64
#==================================================================================================
# Reads a xlsx spworkSheet and returns a single columns worth of data
# called as:
# 	getXlsx(workbookFile, workbookSheetName, sheetColumnName)
#
# 	workbookSheetName 	= a string that is contained in one of the workbook's sheet names
# 	sheetColumnName 	= a string that is contained in one of the sheet header in row 1 of the sheet
#
# 	e.g. workbookSheetName = 'workflow' matches sheet name 'WorkflowData'
# 	e.g. sheetColumnName = 'path' matches sheet column name 'Page Path'
#
#==================================================================================================
# 07/01/2015 - dgs - inital implementaton
# 08/03/2016 - dgs - Properly process date and float format cells
# 10/13/2016 - dgs - Updated to run on Python 3.x
#					 Removed dependence on framework.py
#==================================================================================================
import inspect, sys, traceback
import os
import argparse
import xlrd
import re
import datetime, time
import string
from array import *

#print(sys.argv[1:])

#==================================================================================================
# Constants
#==================================================================================================
myName = os.path.basename(__file__)

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
parser = argparse.ArgumentParser()
parser.add_argument('-wb', nargs='+')
parser.add_argument('-ws', nargs='+')
parser.add_argument('-delim', nargs=1)
parser.add_argument("-v","--verbosity", action="count", help="Debug informaton, -vv for more info.")

args = parser.parse_args()

workbookFile = args.wb[0]
workSheet = args.ws[0]
delim = args.delim
if delim == None:
	delim='|'
else:
	delim=args.delim[0]

verbosity = args.verbosity
if verbosity == None:
	verbosity=0

if verbosity > 0:
	Msg("workbookFile = >" + workbookFile + "<")
	Msg("target sheet = >" + workSheet + "<")
	Msg("field delim = >" + delim + "<")
	Msg("verbosity = >" + str(verbosity) + "<")

# xlrd cell_type map
xlrdCellTypeMap=["Empty string","Unicode String","Float","Date/Float","Boolean/Int","Int representing internal Excel codes","Empty string"]

#==================================================================================================
# Main
#==================================================================================================
if not os.path.isfile(workbookFile):
	Msg("*Fatal Error* -- Could not locate the workbook file:\n\t\t'" + workbookFile + "'")
	Quit(-1)

book = xlrd.open_workbook(workbookFile, encoding_override='cp1252')
if verbosity > 0:
	Msg("The number of worksheets is " + str(book.nsheets))
	Msg("\nSpecified 'workSheet' = >" + workSheet + "<")
#print "Worksheet name(s):", book.sheet_names()

## Get the list of sheets
sheets=''
for i in range(book.nsheets):
	sh = book.sheet_by_index(i)
	if verbosity > 0:
		Msg("\t sheet: " + str(sh.name) + ", visibility: " + str(sh.visibility) )
	if sheets == '':
		sheets=sh.name
	else:
		sheets=sheets+delim+sh.name

## If input sheet name is 'getsheets' then just return the list of sheets
if workSheet.lower() == 'getsheets':
	print(sheets.strip())
	Quit()

found=False
for i in range(book.nsheets):
	sh = book.sheet_by_index(i)
	if verbosity > 0:
		Msg("\t sheet: " + str(sh.name) + ", visibility: " + str(sh.visibility) )
	currentSheet=sh.name.lower()
	if currentSheet.find(workSheet.lower()) >= 0:
		found=True
		break

if found == False:
	Msg("*Fatal Error* -- Could not find worksheet, " + workSheet + ", in the workbook file:\n\t" + workbookFile + "\n\t\tAvaiable sheets are:\n\t" + sheets.replace('|',', '))
	Quit(-1)

## Parse the header row
if verbosity > 0:
	Msg("Processing Sheet = >'" + sh.name + "<")
	Msg("\tHeader row = >'" + str(sh.row(0)) + "<")

## Dump out the data rows
for rx in range(sh.nrows):
	outLine=''
	## Concatenate the data columns
	for cx in range(sh.ncols):
		cellType=sh.cell_type(rx,cx)
		cellData=sh.cell_value(rx,cx)
		#Msg('(' + str(rx+1) + ',' + str(cx+1) + ')\t>' + str(cellData) + '<')

		## Convert data if it is numeric
		if cellType == 2:
			cellData=str(float(cellData))
		elif cellType == 3:
		    year, month, day, hour, minute, second = xlrd.xldate_as_tuple(cellData,book.datemode)
		    cellData = str(datetime.datetime(year, month, day, hour, minute, second))
		elif cellType == 4 or cellType == 5:
			cellData=str(int(cellData))

		## try/catch to catch any non-printable chars
		try:
			if cx == 0:
				outLine+=str(cellData).strip()
			else:
				outLine+=delim
				## Strip out non-print chars
				outLine+=str(re.sub('[^\s!-~]', '', cellData))
				#Msg("Row: " + str(rx+1) + ", Col: " + str(cx+1) + " Type: " + xlrdCellTypeMap[cellType] + "(" + str(cellType) + ")" + " Data: >" + str(cellData) + "<" )
		except Exception as e:
			Msg("")
			Msg("Processing worksheet cell\n\tSheet: '" + sh.name + "', row: " + str(rx+1) + ", column: " + str(cx+1) + " \n\txlrd cell_type: " + xlrdCellTypeMap[cellType] + "(" + str(cellType) + ")" )
			Msg("\t*Fatal Error*")
			Msg("\t" + str(e))
			Quit(-1)

	## Print the line to stdout
	if outLine != '':
		print(outLine, file=sys.stdout)

## Done
Quit()

