#==================================================================================================
# Common imports
#==================================================================================================
#print('In framework.py at 0')
from __future__ import print_function

import os, sys, inspect, sys, traceback
from sys import version_info
import platform
import subprocess
import string, time
import webbrowser
import datetime
import logging

if version_info.major == '2':
	import mysql.connector
else:
	import pymysql

