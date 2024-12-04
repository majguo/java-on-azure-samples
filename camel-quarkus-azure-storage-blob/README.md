# Connect to Azure Storage Blob using Microsoft Entra ID

This is a simple guide on how to connect to Azure Storage Blob using Microsoft Entra ID in a sample Quarkus application using `camel-quarkus-azure-storage-blob` extension.

The [sample app](https://github.com/majguo/java-on-azure-samples/blob/main/camel-quarkus-azure-storage-blob/src/main/java/com/example/camel/quarkus/azure/storage/blob/Routes.java) outputs the content of a blob in an Azure Storage Account container to the console:

```java
@ApplicationScoped
public class Routes extends RouteBuilder {

    private static final Logger LOG = Logger.getLogger(Routes.class);

    @ConfigProperty(name = "azure.storage.blob.endpoint")
    String endpoint;

    @ConfigProperty(name = "account.name")
    String accountName;

    @ConfigProperty(name = "container.name")
    String containerName;

    @ConfigProperty(name = "blob.name")
    String blobName;

    @Override
    public void configure() {
        /**
         *  See references:
         *  - https://camel.apache.org/components/4.8.x/azure-storage-blob-component.html#_advanced_azure_storage_blob_configuration
         *  - https://learn.microsoft.com/azure/developer/java/sdk/authentication/azure-hosted-apps#defaultazurecredential
         */
        BlobServiceClient client = new BlobServiceClientBuilder()
                .endpoint(endpoint)
                .credential(new DefaultAzureCredentialBuilder().build())
                .buildClient();
        getContext().getRegistry().bind("client", client);

        fromF("azure-storage-blob://%s/%s?blobName=%s&serviceClient=#client", accountName, containerName, blobName)
                .process(exchange -> {
                    InputStream is = exchange.getMessage().getBody(InputStream.class);
                    LOG.infof("Downloaded blob %s: %s", blobName, IOUtils.toString(is, StandardCharsets.UTF_8));
                })
                .end();
    }
}
```

It creates a `BlobServiceClient` with the `DefaultAzureCredentialBuilder` beforehand, and then regiter to the Camel context so that the camel component `azure-storage-blob` can use it to authenticate to Azure Storage Blob.

The invoking of `new DefaultAzureCredentialBuilder().build()` creates a `DefaultAzureCredential` object, which implements `ChainedTokenCredential` including `ManagedIdentityCredential`, `SharedTokenCacheCredential`, `IntelliJCredential`, `AzureCliCredential`, `WorkloadIdentityCredential`, etc.
The `DefaultAzureCredential` tries each credential in order until one of them successfully acquires a token.

Using Microsoft Entra ID, the sample app leverages the `AzureCliCredential` locally and `WorkloadIdentityCredential` on Azure Kubernetes Service (AKS) to authenticate to Azure Storage Blob.

## Prerequisites

You need the followings to run through this guide:

- Azure subscription. If you don't have an Azure subscription, create a [free account](https://azure.microsoft.com/free/) before you begin.
- Azure CLI. If you don't have the Azure CLI installed, see [Install the Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli?view=azure-cli-latest).
- kubectl. If you don't have `kubectl` installed, see [Install kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/).
- Java 17+ installed, e.g., [Microsoft Build of OpenJDK](https://docs.microsoft.com/java/openjdk/download).
- Apache Maven 3.9.8+ installed, e.g., [Apache Maven](https://maven.apache.org/download.cgi).
- Docker installed, e.g., [Docker Desktop](https://www.docker.com/products/docker-desktop).

## Set up Azure resources

You run the sample app both locally and in Azure Kubernetes Service (AKS) later in this guide. You need to set up the following Azure resources:

- Azure Resource Group
- Azure Storage Account
- Azure Container Registry
- Azure Kubernetes Service (AKS)
- User-assigned managed identity

Define variables used across the guide. Replace `<your unique value>` with your unique value (e.g., `mjg120424`), update the `LOCATION` if needed, and run the following commands:

```bash
UNIQUE_VALUE=<your unique value>
RESOURCE_GROUP_NAME=${UNIQUE_VALUE}rg
LOCATION=eastus2
STORAGE_ACCOUNT_NAME=${UNIQUE_VALUE}sa
STORAGE_ACCOUNT_CONTAINER_NAME=mycontainer
STORAGE_ACCOUNT_BLOB_NAME=myblob
REGISTRY_NAME=${UNIQUE_VALUE}acr
IDENTITY_NAME=${UNIQUE_VALUE}mi
CLUSTER_NAME=${UNIQUE_VALUE}aks
```

Create an Azure Resource Group for hosting the resources:

```bash
az group create \
    --name $RESOURCE_GROUP_NAME \
    --location $LOCATION
```

### Set up Azure Storage Account

Create an Azure Storage Account:

```bash
az storage account create \
    --resource-group $RESOURCE_GROUP_NAME \
    --name $STORAGE_ACCOUNT_NAME \
    --sku Standard_LRS
```

Retrieve its resource ID:

```bash
STORAGE_ACCOUNT_RESOURCE_ID=$(az storage account show \
    --resource-group $RESOURCE_GROUP_NAME \
    --name $STORAGE_ACCOUNT_NAME \
    --query 'id' \
    --output tsv)
```

Retrieve its blob endpoint:

```bash
STORAGE_ACCOUNT_BLOB_ENDPOINT=$(az storage account show \
    --resource-group $RESOURCE_GROUP_NAME \
    --name $STORAGE_ACCOUNT_NAME \
    --query 'primaryEndpoints.blob' \
    --output tsv)

```

Create a container in the Azure Storage Account:

```bash
az storage container create \
    --name $STORAGE_ACCOUNT_CONTAINER_NAME \
    --account-name $STORAGE_ACCOUNT_NAME
```

Upload a sample blob to the container:

```bash
echo -n "Demo for connecting to Azure Storage Blob using Microsoft Entra ID" > camel-quarkus-azure-storage-blob-sample-blob.txt
az storage blob upload \
    --container-name $STORAGE_ACCOUNT_CONTAINER_NAME \
    --file camel-quarkus-azure-storage-blob-sample-blob.txt \
    --name $STORAGE_ACCOUNT_BLOB_NAME \
    --account-name $STORAGE_ACCOUNT_NAME
rm -rf camel-quarkus-azure-storage-blob-sample-blob.txt
```

### Set up Azure Container Registry

Create an Azure Container Registry:

```bash
az acr create \
    --resource-group $RESOURCE_GROUP_NAME \
    --name $REGISTRY_NAME \
    --sku Basic
```

Retrieve its login server:

```bash
LOGIN_SERVER=$(az acr show \
    --name $REGISTRY_NAME \
    --query 'loginServer' \
    --output tsv)
```

Sign in to the Azure Container Registry:

```bash
az acr login \
    --name $REGISTRY_NAME
```

### Set up user-assigned managed identity

Create a user-assigned managed identity, which the AKS cluster uses to connect to Azure Storage Blob:

```bash
az identity create \
    --resource-group ${RESOURCE_GROUP_NAME} \
    --name ${IDENTITY_NAME}
```

Retrieve its resource ID:

```bash
IDENTITY_RESOURCE_ID=$(az identity show \
    --resource-group ${RESOURCE_GROUP_NAME} \
    --name ${IDENTITY_NAME} \
    --query 'id' \
    --output tsv)
```

Retrieve its client ID:

```bash
IDENTITY_CLIENT_ID=$(az identity show \
    --resource-group ${RESOURCE_GROUP_NAME} \
    --name ${IDENTITY_NAME} \
    --query 'clientId' \
    --output tsv)
```

### Set up Azure Kubernetes Service

Create an Azure Kubernetes Service:

```bash
az aks create \
    --resource-group $RESOURCE_GROUP_NAME \
    --name $CLUSTER_NAME \
    --node-count 1 \
    --generate-ssh-keys \
    --enable-managed-identity
```

Retrieve its resource ID:

```bash
AKS_CLUSTER_RESOURCE_ID=$(az aks show \
    --resource-group $RESOURCE_GROUP_NAME \
    --name $CLUSTER_NAME \
    --query 'id' \
    --output tsv)
```

Connect to the AKS cluster:

```bash
az aks get-credentials \
    --resource-group $RESOURCE_GROUP_NAME \
    --name $CLUSTER_NAME \
    --overwrite-existing \
    --admin
```

Attach the container registry to the AKS so that the AKS can pull images from the registry:

```bash
az aks update \
    --resource-group $RESOURCE_GROUP_NAME \
    --name $CLUSTER_NAME \
    --attach-acr $REGISTRY_NAME
```

Connect to Azure Storage Blob in AKS cluster with Service Connector using Workload Identity:

```bash
CONNECTION_NAME=aksstorageaccountconn
az aks connection create storage-blob \
    --connection $CONNECTION_NAME \
    --source-id $AKS_CLUSTER_RESOURCE_ID \
    --target-id $STORAGE_ACCOUNT_RESOURCE_ID/blobServices/default \
    --workload-identity $IDENTITY_RESOURCE_ID
```

Define two environment variables that the sample app uses to connect to Azure Storage Blob in AKS later:

```bash
export SERVICE_CONNECTOR_SERVICE_ACCOUNT_NAME=sc-account-${IDENTITY_CLIENT_ID}
export SERVICE_CONNECTOR_SECRET_NAME=sc-${CONNECTION_NAME}-secret

echo "service connector service account name: $SERVICE_CONNECTOR_SERVICE_ACCOUNT_NAME"
echo "service connector secret name: $SERVICE_CONNECTOR_SECRET_NAME"
```

> **Note**: The values of `SERVICE_CONNECTOR_SERVICE_ACCOUNT_NAME` and `SERVICE_CONNECTOR_SECRET_NAME` are derived from the output of the `az aks connection show --connection $CONNECTION_NAME -g $RESOURCE_GROUP_NAME -n $CLUSTER_NAME --query 'kubernetesResourceName'` command. You should double-check the output of the command and update the environment variables if needed. You may also check the service account name and secret name in the Azure portal:
> 1. Navigate to the Azure portal.
> 1. Go to the Azure Kubernetes Service resource.
> 1. Select **Settings** > **Service Connector**.
> 1. Check the service connector you created earlier.
> 1. Select **Yaml snippet** from the toolbar.
> 1. Find out the service account name and secret name from the highlighted YAML snippet with keywords **serviceAccountName** and **secretRef**.

## Build and deploy the sample app

Clone the repo and navigate to the sample app `camel-quarkus-azure-storage-blob` this guide uses:

```bash
git clone https://github.com/majguo/java-on-azure-samples.git
cd java-on-azure-samples/camel-quarkus-azure-storage-blob
```

### Run the sample app locally

When running the sample app locally, the current signed-in user is the Microsoft Entra ID that authenticates to Azure Storage Blob. 
Therefore, you need to assign the signed-in user the `Storage Blob Data Contributor` role to the Azure Storage Account.

```bash
az role assignment create \
    --assignee $(az ad signed-in-user show --query 'id' --output tsv) \
    --role "Storage Blob Data Contributor" \
    --scope $STORAGE_ACCOUNT_RESOURCE_ID
```

Re-sign in to Azure CLI to make the role assignment effective:

```bash
az login
```

Define the following environment variables that the sample app uses to connect to Azure Storage Blob locally:

```bash
export AZURE_STORAGE_BLOB_ENDPOINT=$STORAGE_ACCOUNT_BLOB_ENDPOINT
export ACCOUNT_NAME=$STORAGE_ACCOUNT_NAME
export CONTAINER_NAME=$STORAGE_ACCOUNT_CONTAINER_NAME
export BLOB_NAME=$STORAGE_ACCOUNT_BLOB_NAME
```

Build and run the sample app locally in JVM mode:

```bash
mvn clean package
java -jar ./target/quarkus-app/quarkus-run.jar
```

You should see the similar output which indicates the sample app successfully authenticates to Azure Storage Blob with your Microsoft Entra ID using `AzureCliCredential` locally:

```output
2024-12-04 13:37:25,982 INFO  [org.apa.cam.qua.cor.CamelBootstrapRecorder] (main) Apache Camel Quarkus 3.16.0 is starting
2024-12-04 13:37:26,004 INFO  [org.apa.cam.mai.MainSupport] (main) Apache Camel (Main) 4.8.1 is starting
2024-12-04 13:37:26,059 INFO  [org.apa.cam.mai.BaseMainSupport] (main) Auto-configuration summary
2024-12-04 13:37:26,060 INFO  [org.apa.cam.mai.BaseMainSupport] (main)     [MicroProfilePropertiesSource] camel.context.name = camel-quarkus-azure-storage-blob
2024-12-04 13:37:26,562 INFO  [org.apa.cam.sup.LifecycleStrategySupport] (main) Autowired property: serviceClient on component: azure-storage-blob as exactly one instance of type: com.azure.storage.blob.BlobServiceClient (com.azure.storage.blob.BlobServiceClient) found in the registry
2024-12-04 13:37:26,599 INFO  [org.apa.cam.imp.eng.AbstractCamelContext] (main) Apache Camel 4.8.1 (camel-quarkus-azure-storage-blob) is starting
2024-12-04 13:37:26,613 INFO  [org.apa.cam.imp.eng.AbstractCamelContext] (main) Routes startup (total:1)
2024-12-04 13:37:26,613 INFO  [org.apa.cam.imp.eng.AbstractCamelContext] (main)     Started route1 (azure-storage-blob://mjg120424sa/mycontainer)
2024-12-04 13:37:26,614 INFO  [org.apa.cam.imp.eng.AbstractCamelContext] (main) Apache Camel 4.8.1 (camel-quarkus-azure-storage-blob) started in 13ms (build:0ms init:0ms start:13ms)
2024-12-04 13:37:26,618 INFO  [io.quarkus] (main) camel-quarkus-azure-storage-blob 1.0.0-SNAPSHOT on JVM (powered by Quarkus 3.17.2) started in 1.535s.
2024-12-04 13:37:26,619 INFO  [io.quarkus] (main) Profile prod activated.
2024-12-04 13:37:26,620 INFO  [io.quarkus] (main) Installed features: [camel-azure-storage-blob, camel-core, cdi, smallrye-context-propagation, vertx]
2024-12-04 13:37:27,793 INFO  [com.azu.ide.ChainedTokenCredential] (Camel (camel-1) thread #1 - azure-storage-blob://mjg120424sa/mycontainer) Azure Identity => Attempted credential EnvironmentCredential is unavailable.
2024-12-04 13:37:27,794 INFO  [com.azu.ide.ChainedTokenCredential] (Camel (camel-1) thread #1 - azure-storage-blob://mjg120424sa/mycontainer) Azure Identity => Attempted credential WorkloadIdentityCredential is unavailable.
2024-12-04 13:37:28,889 WARN  [com.mic.aad.msa.ConfidentialClientApplication] (ForkJoinPool.commonPool-worker-1) [Correlation ID: 4f304040-dab3-46de-9fed-41ca029e65ba] Execution of class com.microsoft.aad.msal4j.AcquireTokenByClientCredentialSupplier failed: java.util.concurrent.ExecutionException: com.azure.identity.CredentialUnavailableException: ManagedIdentityCredential authentication unavailable. Connection to IMDS endpoint cannot be established, Connect timed out.
2024-12-04 13:37:28,890 INFO  [com.azu.ide.ChainedTokenCredential] (ForkJoinPool.commonPool-worker-1) Azure Identity => Attempted credential ManagedIdentityCredential is unavailable.
2024-12-04 13:37:28,896 INFO  [com.azu.ide.ChainedTokenCredential] (ForkJoinPool.commonPool-worker-1) Azure Identity => Attempted credential SharedTokenCacheCredential is unavailable.
2024-12-04 13:37:28,938 INFO  [com.azu.ide.ChainedTokenCredential] (ForkJoinPool.commonPool-worker-1) Azure Identity => Attempted credential IntelliJCredential is unavailable.
2024-12-04 13:37:30,482 INFO  [com.azu.ide.ChainedTokenCredential] (ForkJoinPool.commonPool-worker-1) Azure Identity => Attempted credential AzureCliCredential returns a token
2024-12-04 13:37:30,494 INFO  [com.azu.cor.imp.AccessTokenCache] (ForkJoinPool.commonPool-worker-1) {"az.sdk.message":"Acquired a new access token."}
2024-12-04 13:37:32,547 INFO  [com.exa.cam.qua.azu.sto.blo.Routes] (Camel (camel-1) thread #1 - azure-storage-blob://mjg120424sa/mycontainer) Downloaded blob myblob: Demo for connecting to Azure Storage Blob using Microsoft Entra ID
2024-12-04 13:37:33,374 INFO  [com.exa.cam.qua.azu.sto.blo.Routes] (Camel (camel-1) thread #1 - azure-storage-blob://mjg120424sa/mycontainer) Downloaded blob myblob: Demo for connecting to Azure Storage Blob using Microsoft Entra ID
2024-12-04 13:37:34,192 INFO  [com.exa.cam.qua.azu.sto.blo.Routes] (Camel (camel-1) thread #1 - azure-storage-blob://mjg120424sa/mycontainer) Downloaded blob myblob: Demo for connecting to Azure Storage Blob using Microsoft Entra ID
2024-12-04 13:37:35,006 INFO  [com.exa.cam.qua.azu.sto.blo.Routes] (Camel (camel-1) thread #1 - azure-storage-blob://mjg120424sa/mycontainer) Downloaded blob myblob: Demo for connecting to Azure Storage Blob using Microsoft Entra ID
2024-12-04 13:37:35,823 INFO  [com.exa.cam.qua.azu.sto.blo.Routes] (Camel (camel-1) thread #1 - azure-storage-blob://mjg120424sa/mycontainer) Downloaded blob myblob: Demo for connecting to Azure Storage Blob using Microsoft Entra ID
```

Press `Ctrl+C` to stop the sample app.

### Run the sample app in Azure Kubernetes Service

When running the sample app in AKS, the user-assigned managed identity authenticates to Azure Storage Blob using Microsoft Entra Workload ID.
You have already set up the connection from the AKS cluster to Azure Storage Blob with Service Connector using Workload Identity.

Define environment variable `DEMO_IMAGE_TAG` that specifies the image tag of the sample app. It's also used when deploying the sample app to the AKS cluster later.

```bash
export DEMO_IMAGE_TAG=${LOGIN_SERVER}/camel-quarkus-azure-storage-blob:1.0
```

Build the sample app image using extension `quarkus-container-image-jib`, and push the image to the Azure Container Registry:

```bash
mvn clean package -Dquarkus.container-image.build=true -Dquarkus.container-image.image=${DEMO_IMAGE_TAG}
docker push $DEMO_IMAGE_TAG
```

Apply the following Kubernetes manifest to deploy the sample app to the AKS cluster. The manifest uses the pre-defined environment variables `SERVICE_CONNECTOR_SERVICE_ACCOUNT_NAME`, `SERVICE_CONNECTOR_SECRET_NAME`, `AZURE_STORAGE_BLOB_ENDPOINT`, `ACCOUNT_NAME`, `CONTAINER_NAME`, `BLOB_NAME`, and `DEMO_IMAGE_TAG`.

```bash
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: camel-quarkus-azure-storage-blob
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: camel-quarkus-azure-storage-blob
  template:
    metadata:
      labels:
        app.kubernetes.io/name: camel-quarkus-azure-storage-blob
        azure.workload.identity/use: "true"
    spec:
      serviceAccountName: ${SERVICE_CONNECTOR_SERVICE_ACCOUNT_NAME}
      containers:
        - env:
            - name: AZURE_CLIENT_ID
              valueFrom:
                secretKeyRef:
                  key: AZURE_STORAGEBLOB_CLIENTID
                  name: ${SERVICE_CONNECTOR_SECRET_NAME}
            - name: AZURE_STORAGE_BLOB_ENDPOINT
              value: ${AZURE_STORAGE_BLOB_ENDPOINT}
            - name: ACCOUNT_NAME
              value: ${ACCOUNT_NAME}
            - name: CONTAINER_NAME
              value: ${CONTAINER_NAME}
            - name: BLOB_NAME
              value: ${BLOB_NAME}
          image: ${DEMO_IMAGE_TAG}
          imagePullPolicy: Always
          name: camel-quarkus-azure-storage-blob
EOF
```

Verify that the deployment succeeded:

```bash
kubectl get deployment camel-quarkus-azure-storage-blob
```

You should see the similar output:

```output
NAME                               READY   UP-TO-DATE   AVAILABLE   AGE
camel-quarkus-azure-storage-blob   1/1     1            1           20s
```

Retrieve the pod name:

```bash
POD_NAME=$(kubectl get pod -l app.kubernetes.io/name=camel-quarkus-azure-storage-blob -o jsonpath='{.items[0].metadata.name}')
```

Stream the logs from the pod:

```bash
kubectl logs -f $POD_NAME
```

Press `Ctrl+C` to stop streaming the logs.

You should see the similar output which indicates the sample app successfully authenticates to Azure Storage Blob with the user-assigned managed identity using `WorkloadIdentityCredential` on AKS:

```output
2024-12-04 05:51:19,578 INFO  [org.apa.cam.qua.cor.CamelBootstrapRecorder] (main) Apache Camel Quarkus 3.16.0 is starting
2024-12-04 05:51:19,581 INFO  [org.apa.cam.mai.MainSupport] (main) Apache Camel (Main) 4.8.1 is starting
2024-12-04 05:51:19,634 INFO  [org.apa.cam.mai.BaseMainSupport] (main) Auto-configuration summary
2024-12-04 05:51:19,634 INFO  [org.apa.cam.mai.BaseMainSupport] (main)     [MicroProfilePropertiesSource] camel.context.name = camel-quarkus-azure-storage-blob
2024-12-04 05:51:20,213 INFO  [org.apa.cam.sup.LifecycleStrategySupport] (main) Autowired property: serviceClient on component: azure-storage-blob as exactly one instance of type: com.azure.storage.blob.BlobServiceClient (com.azure.storage.blob.BlobServiceClient) found in the registry
2024-12-04 05:51:20,245 INFO  [org.apa.cam.imp.eng.AbstractCamelContext] (main) Apache Camel 4.8.1 (camel-quarkus-azure-storage-blob) is starting
2024-12-04 05:51:20,257 INFO  [org.apa.cam.imp.eng.AbstractCamelContext] (main) Routes startup (total:1)
2024-12-04 05:51:20,257 INFO  [org.apa.cam.imp.eng.AbstractCamelContext] (main)     Started route1 (azure-storage-blob://mjg120424sa/mycontainer)
2024-12-04 05:51:20,257 INFO  [org.apa.cam.imp.eng.AbstractCamelContext] (main) Apache Camel 4.8.1 (camel-quarkus-azure-storage-blob) started in 11ms (build:0ms init:0ms start:11ms)
2024-12-04 05:51:20,263 INFO  [io.quarkus] (main) camel-quarkus-azure-storage-blob 1.0.0-SNAPSHOT on JVM (powered by Quarkus 3.17.2) started in 1.691s.
2024-12-04 05:51:20,264 INFO  [io.quarkus] (main) Profile prod activated.
2024-12-04 05:51:20,266 INFO  [io.quarkus] (main) Installed features: [camel-azure-storage-blob, camel-core, cdi, smallrye-context-propagation, vertx]
2024-12-04 05:51:21,436 INFO  [com.azu.ide.ChainedTokenCredential] (Camel (camel-1) thread #1 - azure-storage-blob://mjg120424sa/mycontainer) Azure Identity => Attempted credential EnvironmentCredential is unavailable.
2024-12-04 05:51:22,831 INFO  [com.azu.ide.ChainedTokenCredential] (Thread-4) Azure Identity => Attempted credential WorkloadIdentityCredential returns a token
2024-12-04 05:51:22,869 INFO  [com.azu.cor.imp.AccessTokenCache] (Thread-4) {"az.sdk.message":"Acquired a new access token."}
2024-12-04 05:51:23,068 INFO  [com.exa.cam.qua.azu.sto.blo.Routes] (Camel (camel-1) thread #1 - azure-storage-blob://mjg120424sa/mycontainer) Downloaded blob myblob: Demo for connecting to Azure Storage Blob using Microsoft Entra ID
2024-12-04 05:51:23,587 INFO  [com.exa.cam.qua.azu.sto.blo.Routes] (Camel (camel-1) thread #1 - azure-storage-blob://mjg120424sa/mycontainer) Downloaded blob myblob: Demo for connecting to Azure Storage Blob using Microsoft Entra ID
2024-12-04 05:51:24,099 INFO  [com.exa.cam.qua.azu.sto.blo.Routes] (Camel (camel-1) thread #1 - azure-storage-blob://mjg120424sa/mycontainer) Downloaded blob myblob: Demo for connecting to Azure Storage Blob using Microsoft Entra ID
2024-12-04 05:51:24,616 INFO  [com.exa.cam.qua.azu.sto.blo.Routes] (Camel (camel-1) thread #1 - azure-storage-blob://mjg120424sa/mycontainer) Downloaded blob myblob: Demo for connecting to Azure Storage Blob using Microsoft Entra ID
2024-12-04 05:51:25,129 INFO  [com.exa.cam.qua.azu.sto.blo.Routes] (Camel (camel-1) thread #1 - azure-storage-blob://mjg120424sa/mycontainer) Downloaded blob myblob: Demo for connecting to Azure Storage Blob using Microsoft Entra ID
```

## Clean up resources

Once you finish the guide, clean up the resources to avoid unexpected charges:

```bash
az group delete \
    --name $RESOURCE_GROUP_NAME \
    --yes --no-wait
```

You can also delete the app image from your local Docker:

```bash
docker rmi $DEMO_IMAGE_TAG
```

## References

Learn more about the topics covered in this guide:

- [Microsoft Entra ID](https://www.microsoft.com/en-us/security/business/identity-access/microsoft-entra-id)
- [Microsoft Entra Workload ID](https://www.microsoft.com/en-us/security/business/identity-access/microsoft-entra-workload-id)
- [Authenticate Azure-hosted Java applications using DefaultAzureCredential](https://learn.microsoft.com/azure/developer/java/sdk/authentication/azure-hosted-apps#defaultazurecredential)
- [Tutorial: Connect to Azure storage account in Azure Kubernetes Service (AKS) with Service Connector using workload identity](https://learn.microsoft.com/azure/service-connector/tutorial-python-aks-storage-workload-identity?tabs=azure-cli)
- [Apache Camel Azure Storage Blob Service advanced configuration](https://camel.apache.org/components/4.8.x/azure-storage-blob-component.html#_advanced_azure_storage_blob_configuration)
- [Apache Camel Quarkus Examples](https://github.com/apache/camel-quarkus-examples)
