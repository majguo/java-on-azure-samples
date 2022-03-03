package com.example.sql;

import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.Statement;

import com.microsoft.sqlserver.jdbc.SQLServerDataSource;

public class App {

    public static void main(String[] args) throws Exception {

        SQLServerDataSource ds = new SQLServerDataSource();
        ds.setServerName(System.getenv("DB_SERVER_NAME")); // Replace with your server name
        ds.setDatabaseName(System.getenv("DB_NAME")); // Replace with your database
        ds.setUser(System.getenv("DB_USER")); // Replace with your user name
        ds.setPassword(System.getenv("DB_PASSWORD")); // Replace with your password
        ds.setAuthentication("ActiveDirectoryPassword");

        try (Connection connection = ds.getConnection();
                Statement stmt = connection.createStatement();
                ResultSet rs = stmt.executeQuery("SELECT SUSER_SNAME()")) {
            if (rs.next()) {
                System.out.println("You have successfully logged on as: " + rs.getString(1));
            }
        }
    }
}
