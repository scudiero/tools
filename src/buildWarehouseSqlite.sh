#!/bin/bash
#==================================================================================================
version=1.0.17 # -- dscudiero -- 02/13/2017 @ 16:03:50.17
#==================================================================================================
TrapSigs 'on'
imports='GetDefaultsData ParseArgs ParseArgsStd Hello Init Goodbye' #imports="$imports "
Import "$imports"
originalArgStr="$*";
scriptDescription="Build abbreviated warehouse sqlite file"

#==================================================================================================
# Dump specific warehouse tables to a sqlite database to use on the internal site
#==================================================================================================
#==================================================================================================
## Copyright ©2014 David Scudiero -- all rights reserved.
## 06-17-15 -- 	dgs - Initial coding
## 02-19-16 -- 	dgs - updated so the target sqlite file can be passed in
#==================================================================================================
#==================================================================================================
# Declare local variables and constants
#==================================================================================================

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
ParseArgsStd
Hello
tmpFile=$(MkTmpFile)
[[ $client != '' ]] && sqliteFile="$sqliteDbs/$client.sqlite" || sqliteFile="$sqliteDbs/warehouseLite.sqlite"

##==================================================================================================
## Main
##==================================================================================================

## Check enviroment
	if [[ ${myRhel:0:1} -lt 6 ]]; then printf "Sorry, this script can only be run on a server running Red Hat version 6 or greater.\n"; Goodbye -1; fi
	if [[ -f $sqliteFile ]]; then rm $sqliteFile; fi

## run mysqldump passing into awk
	[[ $useDevDB == true ]] && warehouseDb='dev' || warehouseDb='warehouse'
	[[ $mySqlConnectString == '' ]] && Msg "T Could not resolve MySql connection information"
	mySqlConnectString=$(sed "s/Read/Admin/" <<< $mySqlConnectString)
	mySqlDumpOpts="--compatible=ansi --skip-extended-insert --compact"
	mySqlDumpTables="clients sites"
	mysqldump  $mySqlDumpOpts $mySqlConnectString $mySqlDumpTables | \

awk '

BEGIN {
	FS=",$"
	print "PRAGMA synchronous = OFF;"
	print "PRAGMA journal_mode = MEMORY;"
	print "BEGIN TRANSACTION;"
}

# CREATE TRIGGER statements have funny commenting.  Remember we are in trigger.
/^\/\*.*CREATE.*TRIGGER/ {
	gsub( /^.*TRIGGER/, "CREATE TRIGGER" )
	print
	inTrigger = 1
	next
}

# The end of CREATE TRIGGER has a stray comment terminator
/END \*\/;;/ { gsub( /\*\//, "" ); print; inTrigger = 0; next }

# The rest of triggers just get passed through
inTrigger != 0 { print; next }

# Skip other comments
/^\/\*/ { next }

# Print all `INSERT` lines. The single quotes are protected by another single quote.
/INSERT/ {
	gsub( /\\\047/, "\047\047" )
	gsub(/\\n/, "\n")
	gsub(/\\r/, "\r")
	gsub(/\\"/, "\"")
	gsub(/\\\\/, "\\")
	gsub(/\\\032/, "\032")
	print
	next
}

# Print the `CREATE` line as is and capture the table name.
/^CREATE/ {
	if ( match( $0, /\"[^\"]+/ ) ) tableName = substr( $0, RSTART+1, RLENGTH-1 )
	print "DROP TABLE IF EXISTS \""tableName"\";"
	print
}

# Replace `FULLTEXT KEY` or any other `XXXXX KEY` except PRIMARY by `KEY`
/^  [^"]+KEY/ && !/^  PRIMARY KEY/ { gsub( /.+KEY/, "  KEY" ) }

# Get rid of field lengths in KEY lines
/ KEY/ { gsub(/\([0-9]+\)/, "") }

# Print all fields definition lines except the `KEY` lines.
/^  / && !/^(  KEY|\);)/ {
	gsub( /AUTO_INCREMENT|auto_increment/, "" )
	gsub( /(CHARACTER SET|character set) [^ ]+ /, "" )
	gsub( /DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP|default current_timestamp on update current_timestamp/, "" )
	gsub( /(COLLATE|collate) [^ ]+ /, "" )
	gsub(/(ENUM|enum)[^)]+\)/, "text ")
	gsub(/(SET|set)\([^)]+\)/, "text ")
	gsub(/UNSIGNED|unsigned/, "")
	if (prev) print prev ","
	prev = $1
}

# `KEY` lines are extracted from the `CREATE` block and stored in array for later print
# in a separate `CREATE KEY` command. The index name is prefixed by the table name to
# avoid a sqlite error for duplicate index name.
/^(  KEY|\);)/ {
	if (prev) print prev
	prev=""
	if ($0 == ");"){
		print
	} else {
		if ( match( $0, /\"[^"]+/ ) ) indexName = substr( $0, RSTART+1, RLENGTH-1 )
		if ( match( $0, /\([^()]+/ ) ) indexKey = substr( $0, RSTART+1, RLENGTH-1 )
		key[tableName]=key[tableName] "CREATE INDEX \"" tableName "_" indexName "\" ON \"" tableName "\" (" indexKey ");\n"
	}
}

# Print all `KEY` creation lines.
END {
	for (table in key) printf key[table]
	print "END TRANSACTION;"
}
' \
| sqlite3 $sqliteFile > $tmpFile

if [[ $(cat $tmpFile) != 'memory' ]]; then
	Msg2 $E "Errors returned from conversion:"
	cat $tmpFile
	Msg $T "Stopping"
fi
touch $sqliteDbs/warehouseLite.syncDate

[[ -f "$$tmpFile" ]] && rm "$$tmpFile"

#==================================================================================================
## Done
#==================================================================================================
#
Goodbye 0
## Wed May  4 08:28:52 CDT 2016 - dscudiero - Only pull clients and sites tables
## Wed May  4 08:31:34 CDT 2016 - dscudiero - Only pull clients and sites tables
## Fri May  6 09:27:06 CDT 2016 - dscudiero - Change default name of the file
## Mon May  9 09:07:07 CDT 2016 - dscudiero - Create syncdate file after extract
## Mon Feb 13 16:04:07 CST 2017 - dscudiero - make sure we are using our one tmpFile
