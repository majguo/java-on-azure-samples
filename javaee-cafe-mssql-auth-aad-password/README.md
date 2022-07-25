# Integrate Open Liberty with AzureSQL using Active Directory Password

This sample shows you how to integrate Open Liberty with AzureSQL using Active Directory Password.

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
   1. Sign into Azure portal > Type "Resource groups" in the search bar and click "Resource groups" displayed in the "Services" list. > Find your resource groups where the Azure SQL server and database were deployed. > Click to open.
      1. Click the SQL server instance > Click "Firewalls and virtual networks" under "Security" > Verify and make changes accordingly to make sure "Deny public network access" is not checked, "Minimum TLS Version" is "1.2", "Connection policy" is "Default", "Allow Azure services and resources to access this server" is "Yes", and IP address of your client is added to firewall rules.

## Run the sample application locally

Now you're ready to checkout and run the sample application of this repo to verify if the database connection between your Open Liberty application and the Azure SQL database works using `ActiveDirectoryPassword` authentication mode.

1. Check out [this repo](https://github.com/majguo/java-on-azure-samples) to a target directory.
1. Locate to that directory and then change to its sub-directory `javaee-cafe-mssql-auth-aad-password`.
1. Set environment variables for database connection with the values you wrote down before:

   ```bash
   export DB_SERVER_NAME=<server-name>.database.windows.net
   export DB_PORT_NUMBER=1433
   export DB_NAME=<database-name>
   export DB_USER=<azure-ad-admin-username>
   export DB_PASSWORD=<azure-ad-admin-pwd>
   ```

1. Package and run the application locally

   ```bash
   mvn clean package
   mvn liberty:dev -Ddb.server.name=${DB_SERVER_NAME} -Ddb.port.number=${DB_PORT_NUMBER} -Ddb.name=${DB_NAME} -Ddb.user=${DB_USER} -Ddb.password=${DB_PASSWORD}
   ```

   If the command terminal prompts the following similar error message:
   ```
   [INFO] Internal Exception: java.sql.SQLException: Cannot open server '<server-name>' requested by the login. Client with IP address '<ip-address>' is not allowed to access the server.  To enable access, use the Windows Azure Management Portal or run sp_set_firewall_rule on the master database to create a firewall rule for this IP address or address range.  It may take up to five minutes for this change to take effect. ClientConnectionId:810464ae-acb8-43e9-93d4-bf9b82be7695 DSRA0010E: SQL State = S0001, Error Code = 40,615
   ```
   
   You need to add your client IP address to the firewall of the Azure SQL server:
   1. Sign into Azure portal > Type "Resource groups" in the search bar and click "Resource groups" displayed in the "Services" list. > Find your resource groups where the Azure SQL server and database were deployed. > Click to open.
   1. Click the SQL server instance > Click "Firewalls and virtual networks" under "Security" > Add a new rule to allow your client IP address to access. > Click "Save", wait until completion.
   
   Then re-run the application:

   ```bash
   mvn liberty:dev -Ddb.server.name=${DB_SERVER_NAME} -Ddb.port.number=${DB_PORT_NUMBER} -Ddb.name=${DB_NAME} -Ddb.user=${DB_USER} -Ddb.password=${DB_PASSWORD}
   ```

   Open http://localhost:9080 in the browser and you should see a UI where you can view, create and delete the coffees. Press "Ctrl+C" to stop the application.

## Run the sample application in local Docker

To run the application in a clean enviroment, you can containerze the app and run it as a container if you have `Docker` installed locally.

1. Set environment variables for image name and tag:

   ```bash
   export IMAGE=javaee-cafe-mssql-auth-aad-password
   export TAG=1.0.0
   ```

1. Build the docker image:
   
   ```bash
   # If you want to build the application image from Open Liberty base image
   docker build -t ${IMAGE}:${TAG} --file=Dockerfile .
   
   # Alternatively uncomment the following line if you prefer to build the image from WebSphere Liberty base image
   # docker build -t ${IMAGE}:${TAG} --file=Dockerfile-wlp .
   ```

1. Run the image in the local Docker:
   
   ```bash
   docker run -it --rm -p 9080:9080 -e DB_SERVER_NAME=${DB_SERVER_NAME} -e DB_PORT_NUMBER=${DB_PORT_NUMBER} -e DB_NAME=${DB_NAME} -e DB_USER=${DB_USER} -e DB_PASSWORD=${DB_PASSWORD} ${IMAGE}:${TAG}
   ```

   Open http://localhost:9080 in the browser and you should see a UI where you can view, create and delete the coffees. Press "Ctrl+C" to stop the application.

## Run the sample application on the AKS cluster

First, create an Azure Container Registry (ACR) instance and push the application image.

```bash
# Create the resource group
RESOURCE_GROUP_NAME=open-liberty-azuresql-aad-password
az group create --name $RESOURCE_GROUP_NAME --location eastus

# Create the ACR instance
REGISTRY_NAME=youruniqueacrname
az acr create --resource-group $RESOURCE_GROUP_NAME --name $REGISTRY_NAME --sku Basic --admin-enabled
export LOGIN_SERVER=$(az acr show -n $REGISTRY_NAME --query 'loginServer' -o tsv)
USER_NAME=$(az acr credential show -n $REGISTRY_NAME --query 'username' -o tsv)
PASSWORD=$(az acr credential show -n $REGISTRY_NAME --query 'passwords[0].value' -o tsv)

# Login to the ACR and push the application image
docker login $LOGIN_SERVER -u $USER_NAME -p $PASSWORD
docker tag ${IMAGE}:${TAG} ${LOGIN_SERVER}/${IMAGE}:${TAG}
docker push ${LOGIN_SERVER}/${IMAGE}:${TAG}
```

Next, create an AKS cluster which attachs the created ACR instance:

```bash
# Create the AKS cluster
CLUSTER_NAME=myAKSCluster
az aks create --resource-group $RESOURCE_GROUP_NAME --name $CLUSTER_NAME --node-count 1 --generate-ssh-keys --enable-managed-identity --attach-acr $REGISTRY_NAME

# Connect to the AKS cluster:
az aks get-credentials --resource-group $RESOURCE_GROUP_NAME --name $CLUSTER_NAME --overwrite-existing
```

Then install Open Liberty Operator 0.8.2:

```
mkdir -p overlays/watch-all-namespaces
wget https://raw.githubusercontent.com/OpenLiberty/open-liberty-operator/main/deploy/releases/0.8.2/kustomize/overlays/watch-all-namespaces/olo-all-namespaces.yaml -q -P ./overlays/watch-all-namespaces
wget https://raw.githubusercontent.com/OpenLiberty/open-liberty-operator/main/deploy/releases/0.8.2/kustomize/overlays/watch-all-namespaces/cluster-roles.yaml -q -P ./overlays/watch-all-namespaces
wget https://raw.githubusercontent.com/OpenLiberty/open-liberty-operator/main/deploy/releases/0.8.2/kustomize/overlays/watch-all-namespaces/kustomization.yaml -q -P ./overlays/watch-all-namespaces
mkdir base
wget https://raw.githubusercontent.com/OpenLiberty/open-liberty-operator/main/deploy/releases/0.8.2/kustomize/base/kustomization.yaml -q -P ./base
wget https://raw.githubusercontent.com/OpenLiberty/open-liberty-operator/main/deploy/releases/0.8.2/kustomize/base/open-liberty-crd.yaml -q -P ./base
wget https://raw.githubusercontent.com/OpenLiberty/open-liberty-operator/main/deploy/releases/0.8.2/kustomize/base/open-liberty-operator.yaml -q -P ./base
kubectl apply -k overlays/watch-all-namespaces

rm -rf overlays
rm -rf base
```

Finally, deploy the sample application after creating a secret holding the database connection credentials:

```bash
# Create a namespace where the application will be located
export NAMESPACE=open-liberty-demo
kubectl create namespace ${NAMESPACE}

# Create secret "db-secret-mariadb"
envsubst < db-secret.yaml | kubectl apply -f -

# Create OpenLibertyApplication "javaee-cafe-mssql-auth-aad-password"
envsubst < openlibertyapplication.yaml | kubectl apply -f -

# Check if OpenLibertyApplication instance is created
kubectl get openlibertyapplication javaee-cafe-mssql-auth-aad-password -n ${NAMESPACE}

# Check if deployment created by Operator is ready
kubectl get deployment javaee-cafe-mssql-auth-aad-password -n ${NAMESPACE} --watch
```

Wait until you see `3/3` under the `READY` column and `3` under the `AVAILABLE` column, then press `CTRL-C` to stop the kubectl watch process.

When the application is running, a Kubernetes load balancer service exposes the application front end to the internet.

```bash
kubectl get service javaee-cafe-mssql-auth-aad-password -n ${NAMESPACE}
```

Once the `EXTERNAL-IP` address is an actual public IP address, copy its value and open it in the browser. You should see a UI where you can view, create and delete the coffees.

### Clean up the resources

To avoid Azure charges, you should clean up resources once they're not used any longer. Use the `az group delete` command to remove the resource group, container service, container registry, and all related resources.

```bash
az group delete --name $RESOURCE_GROUP_NAME --yes
```

## References

The sample refers to the following documentations:

* [Configure and manage Azure AD authentication with Azure SQL](https://docs.microsoft.com/azure/azure-sql/database/authentication-aad-configure?tabs=azure-powershell#create-contained-users-mapped-to-azure-ad-identities)
* [Connect using ActiveDirectoryPassword authentication mode](https://docs.microsoft.com/sql/connect/jdbc/connecting-using-azure-active-directory-authentication?view=sql-server-ver15#connect-using-activedirectorypassword-authentication-mode)
* [properties.microsoft.sqlserver](https://openliberty.io/docs/22.0.0.2/reference/config/dataSource.html#dataSource/properties.microsoft.sqlserver)
