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

## Deploy to ASA Standard consumption and dedicated plan

Because the port that liveness / readiness probes of the ASA Standard consumption and dedicated plan will detect is `1025`, you need to manaully configure it in the sample project. Open the configuration file `src/main/resources/application.properties` and make sure the `quarkus.http.port` is explicitely configured to `1025`, for example:  

```
# Quarkus Configuration file
# key = value
quarkus.http.port=1025
```

Then re-build a fat-jar from the sample app.

```
mvn clean install -Dquarkus.package.type=uber-jar
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

az spring app create \
  --resource-group $RESOURCE_GROUP \
  --service $AZURE_SPRING_APPS_INSTANCE \
  --name $APP_NAME \
  --assign-endpoint true
  ```

### Deploy the fat-jar to the ASA Standard consumption and dedicated plan service instance

When the app is running, run the following commands to deploy the fat-jar to the ASA Standard consumption and dedicated plan service instance.

```
PATH_TO_FAT_JAR=target/getting-started-1.0.0-SNAPSHOT-runner.jar
az spring app deploy \
  --resource-group $RESOURCE_GROUP \
  --service $AZURE_SPRING_APPS_INSTANCE \
  --name $APP_NAME \
  --artifact-path ${PATH_TO_FAT_JAR} \
  --verbose
```

However, the command failed with the following similar output:

```
Seems you do not import spring actuator, thus metrics are not enabled, please refer to https://aka.ms/ascdependencies for more details
This command usually takes minutes to run. Add '--verbose' parameter if needed.
[1/3] Requesting for upload URL.
[2/3] Uploading package to blob.
......
[3/3] Updating deployment in app "quarkus-getting-started" (this operation can take a while to complete)
Application logs:
Your application failed to start, please check the logs of your application.
```

Run the following command to check the logs:

```
az spring app logs -f \
  --resource-group $RESOURCE_GROUP \
  --service $AZURE_SPRING_APPS_INSTANCE \
  --name $APP_NAME
```

The log hasn't shown the startup information for a typical Quarkus application:

```
2023-06-25T06:50:11.79683  Connecting to the container 'main'...
2023-06-25T06:50:11.90532  Successfully Connected to container: 'main' [Revision: 'quarkus-getting-started--default-d7uak9a', Replica: 'quarkus-getting-started--default-d7uak9a-84755cfd4b-g9zrm']

  .   ____          _            __ _ _
 /\\ / ___'_ __ _ _(_)_ __  __ _ \ \ \ \
( ( )\___ | '_ | '_| | '_ \/ _` | \ \ \ \
 \\/  ___)| |_)| | | | | || (_| |  ) ) ) )
  '  |____| .__|_| |_|_| |_\__, | / / / /
 =========|_|==============|___/=/_/_/_/
 :: Spring Boot ::                (v2.7.6)

2023-06-25 06:42:48.619  INFO 1 --- [           main] hello.Application                        : Starting Application v1.0.0 using Java 11.0.18 on ef4ef8ca8f464a7bb48b96b2f9f44cdb with PID 1 (/app.jar started by cnb in /)
2023-06-25 06:42:48.626  INFO 1 --- [           main] hello.Application                        : No active profile set, falling back to 1 default profile: "default"
2023-06-25 06:42:52.176  INFO 1 --- [           main] o.s.cloud.context.scope.GenericScope     : BeanFactory id=56a0afe6-5735-31dd-a4aa-f431951c6211
2023-06-25 06:42:53.235  INFO 1 --- [           main] o.s.b.w.embedded.tomcat.TomcatWebServer  : Tomcat initialized with port(s): 8080 (http)
2023-06-25 06:42:53.279  INFO 1 --- [           main] o.apache.catalina.core.StandardService   : Starting service [Tomcat]
2023-06-25 06:42:53.280  INFO 1 --- [           main] org.apache.catalina.core.StandardEngine  : Starting Servlet engine: [Apache Tomcat/9.0.69]
2023-06-25 06:42:53.505  INFO 1 --- [           main] o.a.c.c.C.[Tomcat].[localhost].[/]       : Initializing Spring embedded WebApplicationContext
2023-06-25 06:42:53.506  INFO 1 --- [           main] w.s.c.ServletWebServerApplicationContext : Root WebApplicationContext: initialization completed in 4692 ms
2023-06-25 06:42:55.412  INFO 1 --- [           main] o.s.b.a.w.s.WelcomePageHandlerMapping    : Adding welcome page: class path resource [static/index.html]
2023-06-25 06:42:56.510  INFO 1 --- [           main] o.s.b.a.e.web.EndpointLinksResolver      : Exposing 2 endpoint(s) beneath base path '/actuator'
2023-06-25 06:42:56.698  INFO 1 --- [           main] o.s.b.w.embedded.tomcat.TomcatWebServer  : Tomcat started on port(s): 8080 (http) with context path ''
2023-06-25 06:42:56.802  INFO 1 --- [           main] hello.Application                        : Started Application in 10.29 seconds (JVM running for 11.844)
```

### Deploy to the Azure Container App Environment

For further triage, it's also verified that the fat-jar can work with the Azure Container App (ACA) environment created before.

First, build a docker image.

```
docker build -t getting-started . -f-<<EOF
FROM adoptopenjdk:11-jre-hotspot
WORKDIR /work/
RUN chown 1001 /work \
    && chmod "g+rwX" /work \
    && chown 1001:root /work
COPY --chown=1001:root target/getting-started-1.0.0-SNAPSHOT-runner.jar /work/runner.jar

EXPOSE 1025
USER 1001

ENTRYPOINT ["sh", "-c"]
CMD ["exec java -jar runner.jar -Dquarkus.http.host=0.0.0.0 -Djava.util.logging.manager=org.jboss.logmanager.LogManager"]
EOF
```

You can run it as a docker container locally and visit the app home page by opening `http://localhost:1025` in your browser, you should see the similar home page as before.

```
docker run -i --rm -p 1025:1025 getting-started
```

Then push the image to a public repository in Docker Hub and spin up an ACA instance.
Remember to replace placeholder `<DockerHub-account>` with a valid Docker Hub account before running the following commands.

```
docker tag getting-started <DockerHub-account>/getting-started
docker login
docker push <DockerHub-account>/getting-started

ACA_NAME=quarkus-getting-started-aca
az containerapp up \
  --name $ACA_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --environment $MANAGED_ENV_RESOURCE_ID \
  --image <DockerHub-account>/getting-started \
  --target-port 1025 \
  --ingress external
```

Once the ACA instance is up and running, retrieve its endpoint.

```
echo https://$(az containerapp show \
  --name $ACA_NAME \
  --resource-group $RESOURCE_GROUP \
  --query properties.configuration.ingress.fqdn \
  -o tsv)
```

Copy the output and open it in your browser, you should see the similar home page as before.

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
