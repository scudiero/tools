#==================================================================================================
# Common imports
#==================================================================================================
#print('In framework.py at 0')
from __future__ import print_function

import os, sys, inspect, sys, traceback
from sys import version_info
import platform
import subprocess
import string
import webbrowser
import datetime
import logging

# if version_info.major == '2':
# 	import mysql.connector
# else:
# 	import pymysql

import tkinter as Tk

# import the library
from appJar import gui
# create a GUI variable called app
app = gui()
# add & configure widgets - widgets get a name, to help referencing them later
app.addLabel("title", "Welcome to appJar")
app.setLabelBg("title", "red")
# start the GUI
app.go()
