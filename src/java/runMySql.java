//==================================================================================================
// DO NOT AUTOVERSION
//==================================================================================================
//import org.apache.commons.cli.*;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.logging.Level;
import java.util.logging.Logger;
import java.util.*;
import java.io.*;
import java.lang.Runtime;

public class runMySql {
//==================================================================================================
//String version="1.0.9" // -- dscudiero -- 10/21/2016 @ 14:40:50.51
//==================================================================================================

    // Helper classes ==============================================================================
    public static class MyException extends Exception{
        String eId = null;
        String msgStr = null;
        MyException(int eid, String data) {
            eId=Integer.toString(eid);
            switch (eid) {
                case 1:
                    msgStr="Your userid does not have sufficient authority to perform this action:" +
                    "\n\t'" + data;
                    break;
                case 2:
                    msgStr="Invalid sql action requested:" +
                    "\n\t'" + data;
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
    public static final Boolean debug=true;
    public static final String myName="runMySql.java";
    public static final String port="3306";
    public static final String dbName="warehouse";
    public static final String host="10.1.88.25";
    public static final String readActions="select,execute,show,pragma";
    public static final String updateActions=readActions+",insert,update,delete";
    public static final String adminActions=updateActions+",create,drop,truncate";
    public static final String loggerName=myName + ".class.getName()";
    public static final String adminUsers=",dscudiero,";


    // Subroutiens =================================================================================
    public static String GetUserName() {
        // Get the currently logged in user name
        String userName = null;
        try {
            Process p = Runtime.getRuntime().exec("/usr/bin/logname");
            int rc = p.waitFor();
            System.out.println("rc: " + rc);
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

        // Build the sql statement from the remaining args.
            String sqlAction=null;
            String sqlStmt="";
            if (args.length == 0) {
                sqlStmt = System.getenv("sqlStmt");
                String tmpArr[] = sqlStmt.split(" ", 2);
                sqlAction=tmpArr[0].toLowerCase();
            } else {
                sqlAction=args[0].toLowerCase();
                for (int i = 0; i < args.length; i++) {
                    sqlStmt = sqlStmt + " " + args[i];
                }
            }
            if (debug) { System.out.println("sqlStmt: " + sqlStmt);
                        System.out.println("sqlAction: " + sqlAction); }

        // Connection information
            Connection con = null;
            Statement st = null;
            ResultSet rs = null;
            ResultSetMetaData rsmd = null;

            String url = "jdbc:mysql://" + host + ":" + port + "/" + dbName;
            String user = null; String password = null;



        // Validate sql
        try {
            if (adminActions.indexOf(sqlAction) >= 0) {
                String userName=GetUserName();
                if (adminUsers.indexOf(userName) < 0) throw new MyException(1,sqlStmt);
                user = "dscudiero";
                password = "m1chaels-";
            } else if (updateActions.indexOf(sqlAction) >= 0) {
                user = "leepfrogUpdate";
                password  =  "0scys,btdeL";
            } else {
                user = "leepfrogRead";
                password  =  "0scys,btdeL";
            }
        } catch (MyException e)  {
            System.out.println(e); System.exit(-1);
        }

        // Run the sql
        try {
            con = DriverManager.getConnection(url, user, password);
            st = con.createStatement();
            if (adminActions.indexOf(sqlAction) >= 0) {
                rs = st.executeQuery(sqlStmt);
            } else if (updateActions.indexOf(sqlAction) >= 0) {
                rs = st.executeUpdate(sqlStmt);
            } else {
                rs = st.executeQuery(sqlStmt);
            }
            rsmd = rs.getMetaData();
            int numCols = rsmd.getColumnCount();

            //Loop through results set and format a result string, print out the result string
            String outLine = null;
            for(int i = 1; i <= numCols; i++) { outLine=outLine + '|' + rsmd.getColumnName(i); }
            System.out.println(outLine);
            while (rs.next()) {
                outLine = null;
                for(int i = 1; i <= numCols; i++) {
                    outLine=outLine + '|' + rs.getString(i);
                }
                System.out.println(outLine);
            }
        } catch (SQLException ex) {
            //Logger lgr = Logger.getLogger(runMySql.class.getName());
            Logger lgr = Logger.getLogger(loggerName);
            lgr.log(Level.SEVERE, ex.getMessage(), ex);
        } finally {
            try {
                if (rs != null) { rs.close(); }
                if (st != null) { st.close(); }
                if (con != null) { con.close(); }
            } catch (SQLException ex) {
                Logger lgr = Logger.getLogger(loggerName);
                lgr.log(Level.SEVERE, ex.getMessage(), ex);
            }
        } // finally
    } // catch
} // runMySql