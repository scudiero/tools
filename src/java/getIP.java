import java.net.*;
//import java.net.UnknownHostException;

/**
 * Simple Java program to find IP Address of localhost. This program uses
 * InetAddress from java.net package to find IP address.
 *
 */
public class getIP {
    public static void main(String args[]) throws UnknownHostException {
        InetAddress addr = InetAddress.getLocalHost();
        //Getting IPAddress of localhost - getHostAddress return IP Address
        // in textual format
        String ipAddress = addr.getHostAddress();
        System.out.println("IP address of localhost from Java Program: " + ipAddress);

        //Hostname
        String hostname = addr.getHostName();
        System.out.println("Name of hostname : " + hostname);
    }
}

/*
Output:
IP address of localhost from Java Program: 190.12.209.123
Name of hostname : PCLOND3433
*/
