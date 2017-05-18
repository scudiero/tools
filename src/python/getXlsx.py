#!/bin/python
# version=1.2.36 # -- dscudiero -- Thu 05/18/2017 @ 12:03:33.98
#==================================================================================================
# Reads a xlsx spreadsheet and returns a single columns worth of data
# called as:
# 	getXlsx(spreadsheetFile, workbookSheetName, sheetColumnName)
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
parser.add_argument("spreadsheetFile")
parser.add_argument("readSheet")
parser.add_argument("outputFieldDelim")
#parser.add_argument("-noH","--noHeader", action="store_true", help="Do not output the first row")
#parser.add_argument("-hs","--hiddenSheets", action="store_true", help="Include hidden sheets in the output")
#parser.add_argument("-hc","--hiddenColumns", action="store_true", help="Include hidden columns in the output")
parser.add_argument("-v","--verbosity", action="count", help="Debug informaton, -vv for more info.")

args = parser.parse_args()

spreadsheetFile = args.spreadsheetFile
readSheet = args.readSheet
outputFieldDelim = args.outputFieldDelim.lower()
verbosity = args.verbosity
if verbosity == None:
	verbosity=0

if verbosity > 0:
	Msg("verbosity = >" + str(verbosity) + "<")
	Msg("spreadsheetFile = >" + spreadsheetFile + "<")
	Msg("target sheet = >" + readSheet + "<")
	Msg("field outputFieldDelim = >" + outputFieldDelim + "<")
	#Msg("hiddenSheets = >" + str(hiddenSheets) + "<")
	#Msg("hiddenColumns = >" + str(hiddenColumns) + "<")
	#Msg("args.noHeader = >'" + str(args.noHeader) + "<")

# xlrd cell_type map
xlrdCellTypeMap=["Empty string","Unicode String","Float","Date/Float","Boolean/Int","Int representing internal Excel codes","Empty string"]

#==================================================================================================
# Main
#==================================================================================================
if not os.path.isfile(spreadsheetFile):
	Msg("*Fatal Error* -- Could not locate the workbook file:\n\t\t'" + spreadsheetFile + "'")
	Quit(-1)

book = xlrd.open_workbook(spreadsheetFile, encoding_override='cp1252')
if verbosity > 0:
	Msg("The number of worksheets is " + str(book.nsheets))
	Msg("\nSpecified 'readSheet' = >" + readSheet + "<")
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
		sheets=sheets+outputFieldDelim+sh.name

## If input sheet name is 'getsheets' then just return the list of sheets
if readSheet.lower() == 'getsheets':
	Msg(sheets.strip())
	Quit()

## Get the datemode for the spreadsheet


found=False
for i in range(book.nsheets):
	sh = book.sheet_by_index(i)
	if verbosity > 0:
		Msg("\t sheet: " + str(sh.name) + ", visibility: " + str(sh.visibility) )
	currentSheet=sh.name.lower()
	if currentSheet.find(readSheet.lower()) >= 0:
		found=True
		break

if found == False:
	Msg("*Fatal Error* -- Could not find worksheet, " + readSheet + ", in the workbook file:\n\t" + spreadsheetFile + "\n\t\tAvaiable sheets are:\n\t" + sheets.replace('|',', '))
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
				outLine+=outputFieldDelim
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

