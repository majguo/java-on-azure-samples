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

#### HTTP Request to / failed

Copy the output and open it in your browser. However, the expected home page is not displayed. Instead, you will see `Internal Server Error`.

Run the command below to retrieve the log:

```
az spring app logs -f \
    --resource-group ${RESOURCE_GROUP_NAME} \
    --service ${SERVICE_INSTANCE_NAME} \
    --name ${APP_NAME}
```

You will see the similar output:

```
BUILD_IN_EUREKA_CLIENT_SERVICEURL_DEFAULTZONE=https://asa-standard-service-2023-05-15.svc.azuremicroservices.io/eureka/eureka
BUILD_IN_SPRING_CLOUD_CONFIG_URI=https://asa-standard-service-2023-05-15.svc.azuremicroservices.io/config
BUILD_IN_SPRING_CLOUD_CONFIG_FAILFAST=true
OpenJDK 64-Bit Server VM warning: Sharing is only supported for boot loader classes because bootstrap classpath has been appended
2023-05-14 23:47:11.702Z INFO  c.m.applicationinsights.agent - Application Insights Java Agent 3.4.10 started successfully (PID 1, JVM running for 11.828 s)
2023-05-14 23:47:11.711Z INFO  c.m.applicationinsights.agent - Java version: 11.0.18, vendor: Microsoft, home: /usr/lib/jvm/msopenjdk-11
May 14, 2023 11:47:21 PM io.quarkus.bootstrap.runner.Timing printStartupTime
INFO: getting-started 1.0.0-SNAPSHOT on JVM (powered by Quarkus 3.0.2.Final) started in 7.791s. Listening on: http://0.0.0.0:1025
May 14, 2023 11:47:21 PM io.quarkus.bootstrap.runner.Timing printStartupTime
INFO: Profile prod activated.
May 14, 2023 11:47:21 PM io.quarkus.bootstrap.runner.Timing printStartupTime
INFO: Installed features: [cdi, resteasy-reactive, smallrye-context-propagation, vertx]
May 14, 2023 11:48:21 PM io.quarkus.vertx.http.runtime.QuarkusErrorHandler handle
ERROR: HTTP Request to / failed, error id: fe886747-8a88-4c0b-83f0-fb4e978b0ece-1
java.lang.StringIndexOutOfBoundsException: begin 5, end 3, length 67
        at java.base/java.lang.String.checkBoundsBeginEnd(String.java:3319)
        at java.base/java.lang.String.substring(String.java:1874)
        at io.vertx.core.file.impl.FileResolverImpl.unpackFromJarURL(FileResolverImpl.java:291)
        at io.vertx.core.file.impl.FileResolverImpl.unpackUrlResource(FileResolverImpl.java:239)
        at io.vertx.core.file.impl.FileResolverImpl.resolveFile(FileResolverImpl.java:162)
        at io.vertx.core.impl.VertxImpl.resolveFile(VertxImpl.java:829)
        at io.vertx.core.file.impl.FileSystemImpl$20.perform(FileSystemImpl.java:1135)
        at io.vertx.core.file.impl.FileSystemImpl$20.perform(FileSystemImpl.java:1133)
        at io.vertx.core.file.impl.FileSystemImpl$BlockingAction.handle(FileSystemImpl.java:1174)
        at io.vertx.core.file.impl.FileSystemImpl$BlockingAction.handle(FileSystemImpl.java:1156)
        at io.vertx.core.impl.ContextBase.lambda$null$0(ContextBase.java:137)
        at io.vertx.core.impl.ContextInternal.dispatch(ContextInternal.java:264)
        at io.vertx.core.impl.ContextBase.lambda$executeBlocking$1(ContextBase.java:135)
        at io.vertx.core.impl.TaskQueue.run(TaskQueue.java:76)
        at org.jboss.threads.ContextHandler$1.runWith(ContextHandler.java:18)
        at org.jboss.threads.EnhancedQueueExecutor$Task.run(EnhancedQueueExecutor.java:2513)
        at org.jboss.threads.EnhancedQueueExecutor$ThreadBody.run(EnhancedQueueExecutor.java:1512)
        at org.jboss.threads.DelegatingRunnable.run(DelegatingRunnable.java:29)
        at org.jboss.threads.ThreadLocalResettingRunnable.run(ThreadLocalResettingRunnable.java:29)
        at io.netty.util.concurrent.FastThreadLocalRunnable.run(FastThreadLocalRunnable.java:30)
        at java.base/java.lang.Thread.run(Thread.java:829)
```

Since the same issue doesn't happen for the Enterprise tier, there must be something different between Enterprise and Standard / Basic tier, which may be worth to be investigated further.  

**NOTE** Jeff Huang has already identified the root cause of the issue and pushed a fix. The fix will be rolled out to the production environment (~ 2 weeks) per ASA release process. Will retry and update the doc once the fix goes live.

#### HTTP Request to /hello and /hello/greeting/{name} works

Fortunately, you can try the other two REST APIs exposed by the sample app which are working as expected:

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
