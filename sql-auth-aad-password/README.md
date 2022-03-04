# Connect to Azure SQL with authentication "ActiveDirectoryPassword"

This sample shows you how to develop Java application that authenciates to the Azure SQL database with Azure Active Directory, using `ActiveDirectoryPassword` authentication mode.

## Prerequisites

To successfully complete the sample, you need to have an Azure AD instance, and an Azure SQL database with an Azure AD administrator.

1. Reference to [Create and populate an Azure AD instance](https://docs.microsoft.com/azure/azure-sql/database/authentication-aad-configure?tabs=azure-powershell#create-and-populate-an-azure-ad-instance) to create an Azure AD instance and populate it with users if you don't have an Azure AD instance yet. Write down passwords for Azure AD users.
1. If you don't have an Azure SQL instance, follow steps below to create one:
   1. Sign into Azure portal > Type "Azure SQL" in the search bar and click "Azure SQL" displayed in the "Services" list.
   1. Click "Create" > Click "Create" for "SQL databases" with resource type as "Single database".
   1. In the "Basics" tab
      1. Specify resource group name to create a new resource group.
      1. Specify and write down the value for "Database name".
      1. Click "Create new" for "Server"
         1. Specify the value for "Server name" and write down the fully qualified name in the format of `<server-name>.database.windows.net`.
         1. Select "Use only Azure Active Directory (Azure AD) authentication" as "Authentication method".
         1. Click "Set admin" to set Azure AD admin
            1. Select one AD user. Wrrite down the Azure AD user name.
            1. Click "Select".
         1. Click "OK".
       1. Click "Next : Networking >"
     1. In the "Networking" tab
        1. Select "Public endpoint" for "Network connectivity".
        1. Toggle "Yes" for "Allow Azure services and resources to access this server".
        1. Toggle "Yes" for "Add current client IP address".
        1. Check "Default" is selected for "Connection policy".
        1. Check "TLS 1.2" is selected for "Minimum TLS version".
     1. Click "Next : Security >"
        1.  Select "Not now" for "Enable Microsoft Defender for SQL".
     1. Click "Review + create".
     1. Click "Create"
     1. Wait until the deployment completes.
1. If you already have an Azure SQL instance but it hasn't been configured with required settings:
   1. Refernece to [Provision Azure AD admin (SQL Database)](https://docs.microsoft.com/azure/azure-sql/database/authentication-aad-configure?tabs=azure-powershell#provision-azure-ad-admin-sql-database) to provision an Azure Active Directory administrator for your existing Azure SQL instance.
   1. Sign into Azure portal > Type "Resrouce groups" in the search bar and click "Resrouce groups" displayed in the "Services" list. > Find your resource groups where the Azure SQL server and database were deployed. > Click to open.
      1. Click the SQL server instance > Click "Firewalls and virtual networks" under "Security" > Verify and make changes accordingly to make sure "Deny public network access" is not checked, "Minimum TLS Version" is "1.2", "Connection policy" is "Default", "Allow Azure services and resources to access this server" is "Yes", and IP address of your client is added to firewall rules.

## Run the sample application locally

Now you're ready to checkout and run the sample application of this repo to verify if the connection initiated by your application to the Azure SQL database can be successfully authenticated using `ActiveDirectoryPassword` authentication mode.

1. Check out [this repo](https://github.com/majguo/java-on-azure-samples) to a target directory.
1. Locate to that directory and then change to its sub-directory `sql-auth-aad-password`.
1. Set environment variables for database connection with the values you wrote down before:

   ```bash
   export DB_SERVER_NAME=<server-name>.database.windows.net
   export DB_NAME=<database-name>
   export DB_USER=<azure-ad-admin-username>
   export DB_PASSWORD=<azure-ad-admin-pwd>
   ```
1. Compile and exeuctue the application

   ```bash
   mvn compile exec:java -Dexec.mainClass="com.example.sql.AADUserPassword"
   ```

   You should see the similar message output in the console: "You have successfully logged on as: `<azure-ad-admin-username>`".

## Run the containerized sample application

To run the application in a clean enviroment, you can containerze the app and run it as a container if you have `Docker` installed locally.

1. Compile and package the app into an executable jar with all dependencies
   
   ```bash
   mvn clean compile assembly:single
   ```

1. Verify if the executable jar works

   ```bash
   cd target && java -jar sql-auth-aad-password-1.0-SNAPSHOT-jar-with-dependencies.jar && cd ..
   ```

   You should see the similar message output in the console: "You have successfully logged on as: `<azure-ad-admin-username>`".

1. Build the image.

   ```bash
   docker build -t sql-auth-aad-password:1.0 .
   ```

1. Run the image as a container. You should replace placeholders for database connection with the values you wrote down before. 

   ```bash
   docker run --rm -e DB_SERVER_NAME=<server-name>.database.windows.net -e DB_NAME=<database-name>-e DB_USER=<azure-ad-admin-username> -e DB_PASSWORD=<azure-ad-admin-pwd> sql-auth-aad-password:1.0
   ```

   You should see the similar message output in the console: "You have successfully logged on as: `<azure-ad-admin-username>`".
## References

The sample refers to the following documentations:

* [Connect using ActiveDirectoryPassword authentication mode](https://docs.microsoft.com/sql/connect/jdbc/connecting-using-azure-active-directory-authentication?view=sql-server-ver15#connect-using-activedirectorypassword-authentication-mode)
* [Configure and manage Azure AD authentication with Azure SQL](https://docs.microsoft.com/azure/azure-sql/database/authentication-aad-configure?tabs=azure-powershell#create-contained-users-mapped-to-azure-ad-identities)


More related references:

* [Use Azure Active Directory authentication](https://docs.microsoft.com/azure/azure-sql/database/authentication-aad-overview)
* [Azure SQL Database and Azure Synapse Analytics connectivity architecture](https://docs.microsoft.com/azure/azure-sql/database/connectivity-architecture)
* [PKIX path building failed - unable to find valid certification path to requested target](https://techcommunity.microsoft.com/t5/azure-database-support-blog/pkix-path-building-failed-unable-to-find-valid-certification/ba-p/2591304)
  * Download and import certificates from [PKI Repository (TLS) - Microsoft DSRE](https://www.microsoft.com/pki/mscorp/cps/default.htm)
* [Configuring the client for encryption](https://docs.microsoft.com/sql/connect/jdbc/configuring-the-client-for-ssl-encryption?view=sql-server-ver15)
