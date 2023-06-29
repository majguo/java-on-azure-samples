# Deploy and run a simple Quarkus app on Azure Spring Apps

This quick start shows you the instructions about deploying a fat-jar built from a simple Quarkus app to different tiers of Azure Spring Apps (ASA).

## Prepare the sample app

The [quarkus-quickstarts/getting-started](https://github.com/quarkusio/quarkus-quickstarts/tree/main/getting-started) is used as the sample in this article. 

```
git clone https://github.com/quarkusio/quarkus-quickstarts.git
```

Build a fat-jar from the sample app:

```
cd quarkus-quickstarts/getting-started
mvn clean install -Dquarkus.package.type=uber-jar
```

The relative path of generated fat-jar is `target/getting-started-1.0.0-SNAPSHOT-runner.jar`.

Run the sample app locally:

```
java -jar target/getting-started-1.0.0-SNAPSHOT-runner.jar
```

Open `http://localhost:8080` in your browser, you should see the similar home page as below.

![Quarkus getting-started sample app home page running locally](./media/quarkus-getting-started-home-page-local.png)

The source of home page is in `src/main/resources/META-INF/resources/index.html`, and packaged to `getting-started-1.0.0-SNAPSHOT-runner.jar/META-INF/resources/index.html`.

Press `Ctrl + C` to stop the sample once you complete the try and test.

## Deploy to ASA Standard consumption and dedicated plan

The port that liveness / readiness probes of the ASA Standard consumption and dedicated plan will detect is `8080`, which is the default http port for Quarkus app. Open the configuration file `src/main/resources/application.properties` and make sure it's in one of the following cases:

* No explicit configuration for `quarkus.http.port`, for example:
   
  ```
  # Quarkus Configuration file
  # key = value
  ```

* Or the `quarkus.http.port` is explicitely configured to `8080`, for example:  

  ```
  # Quarkus Configuration file
  # key = value
  quarkus.http.port=8080
  ```

Then re-build a fat-jar from the sample app.

```
mvn clean install -Dquarkus.package.type=uber-jar
```

You can also build a native executable:

```
mvn package -Dnative -Dquarkus.native.container-build
```

Then build a container that runs the Quarkus application in native mode:

```
docker build -t getting-started-native . -f-<<EOF
FROM registry.access.redhat.com/ubi8/ubi-minimal:8.3
WORKDIR /work/
RUN chown 1001 /work \
    && chmod "g+rwX" /work \
    && chown 1001:root /work
COPY --chown=1001:root target/*-runner /work/application

EXPOSE 8080
USER 1001

CMD ["./application", "-Dquarkus.http.host=0.0.0.0"]
EOF
```

Check if the container works as expected by running it locally:

```
docker run -i --rm -p 8080:8080 getting-started-native
```

Open `http://localhost:8080` in your browser, you should see the similar home page as above.
Press `Ctrl + C` to stop the sample once you complete the try and test.

Now push the image to a public repository in Docker Hub which can be deployed to the ASA app later.
Remember to replace placeholder `<DockerHub-account>` with a valid Docker Hub account before running the following commands.

```
docker tag getting-started-native <DockerHub-account>/getting-started-native
docker login
docker push <DockerHub-account>/getting-started-native
```

### Provision an ASA Standard consumption and dedicated plan service instance

Follow instructions from [Quickstart: Provision an Azure Spring Apps Standard consumption and dedicated plan service instance](https://learn.microsoft.com/en-us/azure/spring-apps/quickstart-provision-standard-consumption-service-instance?tabs=Azure-CLI) to provision an ASA Standard consumption and dedicated plan service instance . Here're commands I copied and executed: 

```
az extension add --upgrade --name containerapp
az provider register --namespace Microsoft.App
az provider register --namespace Microsoft.OperationalInsights

az extension add --upgrade --name spring
az provider register --namespace Microsoft.AppPlatform

RESOURCE_GROUP=asa-consumption-`date +%F`
LOCATION=eastus
AZURE_CONTAINER_APPS_ENVIRONMENT=`date +%F`
AZURE_SPRING_APPS_INSTANCE=asa-consumption-svc-`date +%F`
APP_NAME=quarkus-getting-started

az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION

az containerapp env create \
  --resource-group $RESOURCE_GROUP \
  --name $AZURE_CONTAINER_APPS_ENVIRONMENT \
  --location $LOCATION \
  --enable-workload-profiles

az containerapp env workload-profile set \
  --resource-group $RESOURCE_GROUP \
  --name $AZURE_CONTAINER_APPS_ENVIRONMENT \
  --workload-profile-name my-wlp \
  --workload-profile-type D4 \
  --min-nodes 1 \
  --max-nodes 2

MANAGED_ENV_RESOURCE_ID=$(az containerapp env show \
  --resource-group $RESOURCE_GROUP \
  --name $AZURE_CONTAINER_APPS_ENVIRONMENT \
  --query id \
  --output tsv)

az spring create \
  --resource-group $RESOURCE_GROUP \
  --name $AZURE_SPRING_APPS_INSTANCE \
  --managed-environment $MANAGED_ENV_RESOURCE_ID \
  --sku StandardGen2 \
  --location $LOCATION
  ```

### Deploy the fat-jar to the ASA Standard consumption and dedicated plan service instance

When the ASA Standard consumption and dedicated plan service instance is up, run the following commands to create an ASA app and then deploy the fat-jar.

```
az spring app create \
  --resource-group $RESOURCE_GROUP \
  --service $AZURE_SPRING_APPS_INSTANCE \
  --name $APP_NAME \
  --cpu 1000m --memory 2Gi \
  --workload-profile my-wlp \
  --assign-endpoint true

PATH_TO_FAT_JAR=target/getting-started-1.0.0-SNAPSHOT-runner.jar
az spring app deploy \
  --resource-group $RESOURCE_GROUP \
  --service $AZURE_SPRING_APPS_INSTANCE \
  --name $APP_NAME \
  --artifact-path ${PATH_TO_FAT_JAR} \
  --verbose
```

When the deployment completes, you can retrieve the url.

```
url=$(az spring app show \
    --resource-group $RESOURCE_GROUP \
    --service $AZURE_SPRING_APPS_INSTANCE \
    --name $APP_NAME \
    --query properties.url -o tsv)
echo ${url}
```

Copy the output and open it in your browser, you should see the similar home page.

![Quarkus getting-started sample app home page](./media/quarkus-getting-started-home-page.png)

You can try the other two REST APIs exposed by the sample app:

* REST API `/hello`:
  
  ```
  curl ${url}/hello
  ```

  You should see `hello` is returned.

* REST API `/hello/greeting/{name}`:

  ```
  curl ${url}/hello/greeting/quarkus
  ```

  You should see `hello quarkus` is returned.

Press `Ctrl + C` to stop the sample once you complete the try and test.

### Deploy the custom image to the ASA Standard consumption and dedicated plan service instance

We can also deploy the custom image containing the native executable to the ASA Standard consumption and dedicated plan service instance. 
Remember to replace placeholder `<DockerHub-account>` with a valid Docker Hub account before running the following commands.

```
az spring app create \
  --resource-group $RESOURCE_GROUP \
  --service $AZURE_SPRING_APPS_INSTANCE \
  --name $APP_NAME-native \
  --cpu 500m --memory 1Gi \
  --workload-profile my-wlp \
  --assign-endpoint true

az spring app deploy \
  --resource-group $RESOURCE_GROUP \
  --service $AZURE_SPRING_APPS_INSTANCE \
  --name $APP_NAME-native \
  --container-image <DockerHub-account>/getting-started-native \
  --verbose
```

When the deployment completes, you can retrieve the url.

```
url=$(az spring app show \
    --resource-group $RESOURCE_GROUP \
    --service $AZURE_SPRING_APPS_INSTANCE \
    --name $APP_NAME-native \
    --query properties.url -o tsv)
echo ${url}
```

Copy the output and open it in your browser, you should see the similar home page above.

![Quarkus getting-started sample app home page](./media/quarkus-getting-started-home-page.png)

You can try the other two REST APIs exposed by the sample app:

* REST API `/hello`:
  
  ```
  curl ${url}/hello
  ```

  You should see `hello` is returned.

* REST API `/hello/greeting/{name}`:

  ```
  curl ${url}/hello/greeting/quarkus
  ```

  You should see `hello quarkus` is returned.

Press `Ctrl + C` to stop the sample once you complete the try and test.

### Clear up the resources

Run the following command to clear up the resources once they're no longer needed.

```
az group delete \
  --name $RESOURCE_GROUP \
  --yes --no-wait
```

## Deploy to ASA Standard/Basic tier

Because the port that liveness / readiness probes of the Standard/Basic tier ASA will detect is `1025`, you need to manaully configure it in the sample project. Open the configuration file `src/main/resources/application.properties` and make sure the `quarkus.http.port` is explicitely configured to `1025`, for example:  

```
# Quarkus Configuration file
# key = value
quarkus.http.port=1025
```

Then re-build a fat-jar from the sample app.

```
mvn clean install -Dquarkus.package.type=uber-jar
```

### Provision a Standard/Basic tier ASA instance 

Follow instructions from [How to Deploy Spring Boot applications from Azure CLI](https://learn.microsoft.com/en-us/azure/spring-apps/how-to-launch-from-source) to provision a Standard or Basic tier ASA instance. Here're commands I copied and executed: 

* For Standard tier

  ```
  RESOURCE_GROUP_NAME=asa-standard-`date +%F`
  SERVICE_INSTANCE_NAME=asa-standard-service-`date +%F`
  APP_NAME=quarkus-getting-started

  az extension add --upgrade --name spring
  az group create --location eastus --name ${RESOURCE_GROUP_NAME}

  az spring create \
    --resource-group ${RESOURCE_GROUP_NAME} \
    --name ${SERVICE_INSTANCE_NAME} \
    --sku Standard
 
  az spring app create \
    --resource-group ${RESOURCE_GROUP_NAME} \
    --service ${SERVICE_INSTANCE_NAME} \
    --name ${APP_NAME} \
    --assign-endpoint true
  ``` 

* For Basic tier:

  ```
  RESOURCE_GROUP_NAME=asa-basic-`date +%F`
  SERVICE_INSTANCE_NAME=asa-basic-service-`date +%F`
  APP_NAME=quarkus-getting-started

  az extension add --upgrade --name spring
  az group create --location eastus --name ${RESOURCE_GROUP_NAME}
 
  az group create --location eastus --name ${RESOURCE_GROUP_NAME}
  az spring create \
    --resource-group ${RESOURCE_GROUP_NAME} \
    --name ${SERVICE_INSTANCE_NAME} \
    --sku Basic
 
  az spring app create \
    --resource-group ${RESOURCE_GROUP_NAME} \
    --service ${SERVICE_INSTANCE_NAME} \
    --name ${APP_NAME} \
    --assign-endpoint true
  ```

### Deploy the fat-jar to the Standard/Basic tier ASA instance 

When the app is running, run the following commands to deploy the fat-jar to the Standard/Basic tier ASA instance.

```
PATH_TO_FAT_JAR=target/getting-started-1.0.0-SNAPSHOT-runner.jar
az spring app deploy \
    --resource-group ${RESOURCE_GROUP_NAME} \
    --service ${SERVICE_INSTANCE_NAME} \
    --name ${APP_NAME} \
    --artifact-path ${PATH_TO_FAT_JAR} \
    --verbose
```

When the deployment completes, you can retrieve the url.

```
url=$(az spring app show \
    --resource-group ${RESOURCE_GROUP_NAME} \
    --service ${SERVICE_INSTANCE_NAME} \
    --name ${APP_NAME} \
    --query properties.url -o tsv)
echo ${url}
```

Copy the output and open it in your browser, you should see the similar home page.

![Quarkus getting-started sample app home page](./media/quarkus-getting-started-home-page.png)

You can try the other two REST APIs exposed by the sample app:

* REST API `/hello`:
  
  ```
  curl ${url}/hello
  ```

  You should see `hello` is returned.

* REST API `/hello/greeting/{name}`:

  ```
  curl ${url}/hello/greeting/quarkus
  ```

  You should see `hello quarkus` is returned.

### Clear up the resources

Run the following command to clear up the resources once they're no longer needed.

```
az group delete \
    --name ${RESOURCE_GROUP_NAME} \
    --yes --no-wait
```

## Deploy to ASA Enterprise tier

The port that liveness / readiness probes of the Enterprise tier ASA will detect is `8080`, which is the default http port for Quarkus app. Open the configuration file `src/main/resources/application.properties` and make sure it's in one of the following cases:

* No explicit configuration for `quarkus.http.port`, for example:
   
  ```
  # Quarkus Configuration file
  # key = value
  ```

* Or the `quarkus.http.port` is explicitely configured to `8080`, for example:  

  ```
  # Quarkus Configuration file
  # key = value
  quarkus.http.port=8080
  ```

Then re-build a fat-jar from the sample app.

```
mvn clean install -Dquarkus.package.type=uber-jar
```

### Provision an Enterprise tier ASA instance 

Follow instructions from [Quickstart: Build and deploy apps to Azure Spring Apps using the Enterprise tier - Provision a service instance](https://learn.microsoft.com/en-us/azure/spring-apps/quickstart-deploy-apps-enterprise?tabs=azure-portal#provision-a-service-instance) to provision an Enterprise tier ASA instance, but just create one application for this article. Here're commands I copied and executed: 

```
az extension add --upgrade --name spring
az extension remove --name spring-cloud

az provider register --namespace Microsoft.SaaS
az term accept \
    --publisher vmware-inc \
    --product azure-spring-cloud-vmware-tanzu-2 \
    --plan asa-ent-hr-mtr

RESOURCE_GROUP_NAME=asa-enterprise-`date +%F`
az group create \
    --name ${RESOURCE_GROUP_NAME} \
    --location eastus

SERVICE_INSTANCE_NAME=asa-enterprise-service-`date +%F`
az spring create \
    --resource-group ${RESOURCE_GROUP_NAME} \
    --name ${SERVICE_INSTANCE_NAME} \
    --sku Enterprise \
    --enable-application-configuration-service \
    --enable-service-registry \
    --enable-gateway \
    --enable-api-portal

WORKSPACE_NAME=log-analytis-workspace-`date +%F`
az monitor log-analytics workspace create \
    --resource-group ${RESOURCE_GROUP_NAME} \
    --workspace-name ${WORKSPACE_NAME} \
    --location eastus

LOG_ANALYTICS_RESOURCE_ID=$(az monitor log-analytics workspace show \
    --resource-group ${RESOURCE_GROUP_NAME} \
    --workspace-name ${WORKSPACE_NAME} \
    --query id \
    --output tsv)

AZURE_SPRING_APPS_RESOURCE_ID=$(az spring show \
    --resource-group ${RESOURCE_GROUP_NAME} \
    --name ${SERVICE_INSTANCE_NAME} \
    --query id \
    --output tsv)

az monitor diagnostic-settings create \
    --name "send-logs-and-metrics-to-log-analytics" \
    --resource ${AZURE_SPRING_APPS_RESOURCE_ID} \
    --workspace ${LOG_ANALYTICS_RESOURCE_ID} \
    --logs '[
         {
           "category": "ApplicationConsole",
           "enabled": true,
           "retentionPolicy": {
             "enabled": false,
             "days": 0
           }
         },
         {
            "category": "SystemLogs",
            "enabled": true,
            "retentionPolicy": {
              "enabled": false,
              "days": 0
            }
          },
         {
            "category": "IngressLogs",
            "enabled": true,
            "retentionPolicy": {
              "enabled": false,
              "days": 0
             }
           }
       ]' \
       --metrics '[
         {
           "category": "AllMetrics",
           "enabled": true,
           "retentionPolicy": {
             "enabled": false,
             "days": 0
           }
         }
       ]'

APP_NAME=quarkus-getting-started
az spring app create \
    --resource-group ${RESOURCE_GROUP_NAME} \
    --service ${SERVICE_INSTANCE_NAME} \
    --name ${APP_NAME} \
    --assign-endpoint true
```

### Deploy the fat-jar to the Enterprise tier ASA instance 

When the app is running, run the following commands to deploy the fat-jar to the Enterprise tier ASA instance.

```
PATH_TO_FAT_JAR=target/getting-started-1.0.0-SNAPSHOT-runner.jar
az spring app deploy \
    --resource-group ${RESOURCE_GROUP_NAME} \
    --service ${SERVICE_INSTANCE_NAME} \
    --name ${APP_NAME} \
    --artifact-path ${PATH_TO_FAT_JAR} \
    --verbose
```

When the deployment completes, you can retrieve the url.

```
url=$(az spring app show \
    --resource-group ${RESOURCE_GROUP_NAME} \
    --service ${SERVICE_INSTANCE_NAME} \
    --name ${APP_NAME} \
    --query properties.url -o tsv)
echo ${url}
```

Copy the output and open it in your browser, you should see the similar home page.

![Quarkus getting-started sample app home page](./media/quarkus-getting-started-home-page.png)

You can try the other two REST APIs exposed by the sample app:

* REST API `/hello`:
  
  ```
  curl ${url}/hello
  ```

  You should see `hello` is returned.

* REST API `/hello/greeting/{name}`:

  ```
  curl ${url}/hello/greeting/quarkus
  ```

  You should see `hello quarkus` is returned.

### Clear up the resources

Run the following command to clear up the resources once they're no longer needed.

```
az group delete \
    --name ${RESOURCE_GROUP_NAME} \
    --yes --no-wait
```
