//==================================================================================================
// DO NOT AUTOVERSION
//==================================================================================================
// version="1.1.-1" // -- dscudiero -- Tue 06/18/2019 @ 08:27:23
//==================================================================================================
#include <stdlib.h>
#include <string>		// String utility library
#include <iostream>		// IO utility library
#include <regex>
#include <mysql.h>
#include <toolsUtils.h>

using namespace std;


std::vector<std::string> split2(const std::string& s, char delimiter) {
   std::vector<std::string> tokens;
   std::string token;
   std::istringstream tokenStream(s);
   while (std::getline(tokenStream, token, delimiter))
   {
      tokens.push_back(token);
   }
   return tokens;
}


//==================================================================================================
// MAIN
//==================================================================================================
int main(int argc, char *argv[]) {
	// Constants
		string dbHost="mdb1-host.inside.leepfrog.com";
		string dbName="courseleafdatawarehouse";
		string dbUser="leepfrogRead";
		string dbPw="v721-!PP9b";

	// Program varNames
		bool debug=true;
		string sqlStmt="";
		int verboseLevel=0;
		if (env("verboseLevel") != "")
			verboseLevel=atoi(env("verboseLevel").c_str());
		
	// Parse arguments
		string myName = argv[0];
		for(int i=1; i < argc; i++) {
			sqlStmt=sqlStmt + " " + argv[i];
		}
		sqlStmt=sqlStmt.substr(1);

		Debug(1,"\n*** Starting " + myName,verboseLevel);
		Dump(1,"\tsqlStmt",sqlStmt,verboseLevel);
		Dump(1,"\tOS",getOsName(),verboseLevel);

		// What kind of statement is, look at the first token




	return 0;

} // main

//=================================================================================================================
// Check-in log
//=================================================================================================================
// 06-25-2019 @ 08:48:34 - 1.1.-1 - dscudiero -  Update how escrowSites is called
