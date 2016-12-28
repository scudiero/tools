//==================================================================================================
// veresultSetion="1.0.14" // -- dscudiero -- 12/28/2016 @ 12:31:30.53
//==================================================================================================
// XO NOT AUTOVEresultSetION
//==================================================================================================
// Run sql against the data warehouse.
//  1)  Eliminates the storage and retrieval of userid s and passwords from files
//  2)  Only allows specific actions
//  3)  Limits administrator actions to specific individuals/
//  4)  Returns query data in a '|' delimited list
//==================================================================================================
import org.apache.commons.cli.*;
import java.sql.*;
import java.util.logging.*;
import java.util.*;
import java.io.*;
import java.lang.Runtime;

public class runMySql {

    // Helper classes ==============================================================================
    public static class MyException extends Exception{
        String eId = null;
        String msgStr = null;
        MyException(int eid, String data) {
            eId=Integer.toString(eid);
            switch (eid) {
                case 1:
                    msgStr="Your userid does not have sufficient authority to perform this action:" +
                    "\n\t sql: '" + data + "'";
                    break;
                case 2:
                    msgStr="Invalid sql action requested:" +
                    "\n\t sql: '" + data + "'";
                    break;
                default:
                    msgStr="Unknow exception";
                    break;
            } // switch
        }
        public String toString(){
            return ("\n" + myName + ": *Error* (" + eId + ") -- " + msgStr + "\n");
        }
    }

    // Constants ===================================================================================
    public static final Boolean debug=false;
    public static final String myName="runMySql.java";
    public static final String port="3306";
    public static final String dbName="warehouse";
    public static final String host="10.1.88.25";
    public static final String readActions="select,execute,show,pragma";
    public static final String updateActions=readActions+",insert,update,delete";
    public static final String adminActions=updateActions+",create,drop,truncate";
    public static final String loggerName=myName + ".class.getName()";
    public static final String adminUseresultSet=",dscudiero,";

    // Subroutiens =================================================================================
    public static String GetUserName() {
        // Get the currently logged in user name
        String userName = null;
        try {
            Process p = Runtime.getRuntime().exec("/usr/bin/logname");
            int rc = p.waitFor();
            //System.out.println("rc: " + rc);
            BufferedReader buf = new BufferedReader(new InputStreamReader(p.getInputStream()));
            userName = buf.readLine();
        } catch (IOException e) {
          System.exit(-1);
        } catch (InterruptedException e) {
          System.exit(-1);
        }
        return userName;
    }

    // MAIN ========================================================================================
    public static void main(String[] args) throws Exception {
        if (debug) System.out.println("Num Args: " + args.length + "\n\t" + Arrays.toString(args));

        // Build the sql statement from the remaining arguments.
            String sqlAction=null;
            String sql="";
            // If no more arguments then pull the sql statement from the sqlStmt environment variable
            if (args.length == 0) {
                sql = System.getenv("sqlStmt");
                String tmpArr[] = sql.split(" ", 2);
                sqlAction=tmpArr[0].toLowerCase();
            // Otherwise loop through remaining arguments and build the sql
            } else {
                sqlAction=args[0].toLowerCase();
                for (int i = 0; i < args.length; i++) {
                    if (sql == "" ) { sql = args[i]; } else { sql = sql + " " + args[i]; }
                }
            }
            if (debug) { System.out.println("sql: " + sql);
                        System.out.println("sqlAction: " + sqlAction); }

        // Connection information
            Connection connection = null;
            Statement sqlStmt = null;
            ResultSet resultSet = null;
            ResultSetMetaData resultSetmd = null;

            String url = "jdbc:mysql://" + host + ":" + port + "/" + dbName;
            String user = null; String password = null;

        // Validate & run the sql
        try {
            // Read data from database
            if (readActions.indexOf(sqlAction) >= 0) {
                user = "leepfrogRead";
                password  =  "0scys,btdeL";
                connection = DriverManager.getConnection(url, user, password);
                sqlStmt = connection.createStatement();
                try {
                    resultSet = sqlStmt.executeQuery(sql);
                } catch (SQLException ex) {
                    Logger lgr = Logger.getLogger(loggerName);
                    lgr.log(Level.SEVERE, ex.getMessage(), ex);
                }

                resultSetmd = resultSet.getMetaData();
                int numCols = resultSetmd.getColumnCount();
                //Loop through results set and format a result string, print out the result string
                String outLine = null;
                for(int i = 1; i <= numCols; i++) { outLine=outLine + '|' + resultSetmd.getColumnName(i); }
                System.out.println(outLine);
                while (resultSet.next()) {
                    outLine = null;
                    for(int i = 1; i <= numCols; i++) { outLine=outLine + '|' + resultSet.getString(i); }
                    System.out.println(outLine);
                }

            // Update/Insert data into database
            } else if (updateActions.indexOf(sqlAction) >= 0) {
                user = "leepfrogUpdate";
                password  =  "0scys,btdeL";
                connection = DriverManager.getConnection(url, user, password);
                sqlStmt = connection.createStatement();
                try {
                    sqlStmt.executeUpdate(sql);
                } catch (SQLException ex) {
                    Logger lgr = Logger.getLogger(loggerName);
                    lgr.log(Level.SEVERE, ex.getMessage(), ex);
                }
            // Admin data base actions
            } else if (adminActions.indexOf(sqlAction) >= 0) {
                String userName=GetUserName();
                if (adminUseresultSet.indexOf(userName) < 0) throw new MyException(1,sql);
                user = "dscudiero";
                password = "m1chaels-";
                connection = DriverManager.getConnection(url, user, password);
                sqlStmt = connection.createStatement();
                try {
                    sqlStmt.executeUpdate(sql);
                } catch (SQLException ex) {
                    Logger lgr = Logger.getLogger(loggerName);
                    lgr.log(Level.SEVERE, ex.getMessage(), ex);
                }
            // Otherwise throw an exception
            } else {
                throw new MyException(2,sql);
            }
        // Overall catch block for main
        } catch (MyException e)  {
            System.out.println(e); System.exit(-1);
        }

        // Cleanup
        if (resultSet != null) { resultSet.close(); }
        if (sqlStmt != null) { sqlStmt.close(); }
        if (connection != null) { connection.close(); }

    } // Main
} // runMySql

//==================================================================================================
// check-in log
//==================================================================================================
// Wed Dec 28 14:18:53 CST 2016 - dscudiero - General syncing of dev to prod
