# Enable Application Gateway Ingress Controller with AKS Add-On

This article demonstrates how to:

* Create an AKS cluster with the AGIC (Application Gateway Ingress Controller) add-on enabled, and an Azure Container Registry (ACR) instance.
* Run your Java, Java EE, Jakarta EE, or MicroProfile application on the Open Liberty or WebSphere Liberty runtime.
* Build the application Docker image using Open Liberty container images.
* Deploy the containerized application to an AKS cluster using the Open Liberty Operator.

The Open Liberty Operator simplifies the deployment and management of applications running on Kubernetes clusters. With Open Liberty Operator, you can also perform more advanced operations, such as gathering traces and dumps.

For more details on Open Liberty, see [the Open Liberty project page](https://openliberty.io/). For more details on IBM WebSphere Liberty, see [the WebSphere Liberty product page](https://www.ibm.com/cloud/websphere-liberty).

[!INCLUDE [quickstarts-free-trial-note](../../includes/quickstarts-free-trial-note.md)]

[!INCLUDE [azure-cli-prepare-your-environment.md](../../includes/azure-cli-prepare-your-environment.md)]

* This article requires the latest version of Azure CLI. If using Azure Cloud Shell, the latest version is already installed.
* If running the commands in this guide locally (instead of Azure Cloud Shell):
  * Prepare a local machine with Unix-like operating system installed (for example, Ubuntu, macOS, Windows Subsystem for Linux).
  * Install a Java SE implementation (for example, [AdoptOpenJDK OpenJDK 8 LTS/OpenJ9](https://adoptopenjdk.net/?variant=openjdk8&jvmVariant=openj9)).
  * Install [Maven](https://maven.apache.org/download.cgi) 3.5.0 or higher.
  * Install [Docker](https://docs.docker.com/get-docker/) for your OS.
  * Install [`jq`](https://stedolan.github.io/jq/download/).

## Create a resource group

An Azure resource group is a logical group in which Azure resources are deployed and managed.  

Create a resource group called *java-liberty-project* using the [az group create](/cli/azure/group#az_group_create) command  in the *eastus* location. This resource group will be used later for creating the ACR instance and the AKS cluster.

```azurecli-interactive
RESOURCE_GROUP_NAME=java-liberty-project
az group create --name $RESOURCE_GROUP_NAME --location eastus
```

## Create an ACR instance

Use the [az acr create](/cli/azure/acr#az_acr_create) command to create the ACR instance. The following example creates an ACR instance named *youruniqueacrname*. Make sure *youruniqueacrname* is unique within Azure.

```azurecli-interactive
REGISTRY_NAME=youruniqueacrname
az acr create --resource-group $RESOURCE_GROUP_NAME --name $REGISTRY_NAME --sku Basic --admin-enabled
```

After a short time, you should see a JSON output that contains:

```output
  "provisioningState": "Succeeded",
  "publicNetworkAccess": "Enabled",
  "resourceGroup": "java-liberty-project",
```

### Connect to the ACR instance

You will need to sign in to the ACR instance before you can push an image to it. Run the following commands to verify the connection:

```azurecli-interactive
LOGIN_SERVER=$(az acr show -n $REGISTRY_NAME --query 'loginServer' -o tsv)
USER_NAME=$(az acr credential show -n $REGISTRY_NAME --query 'username' -o tsv)
PASSWORD=$(az acr credential show -n $REGISTRY_NAME --query 'passwords[0].value' -o tsv)

docker login $LOGIN_SERVER -u $USER_NAME -p $PASSWORD
```

You should see `Login Succeeded` at the end of command output if you have logged into the ACR instance successfully.

## Create an AKS cluster

Use the [az aks create](https://docs.microsoft.com/cli/azure/aks?view=azure-cli-latest#az-aks-enable-addons-examples) command to create an AKS cluster. The following example creates a cluster named *myAKSCluster* with one node, and enabled with AGIC addon. This will take several minutes to complete.

```azurecli-interactive
CLUSTER_NAME=myAKSCluster
az aks create --resource-group $RESOURCE_GROUP_NAME --name $CLUSTER_NAME --node-count 1 --generate-ssh-keys --enable-managed-identity --network-plugin azure --enable-addons ingress-appgw --appgw-name myApplicationGateway --appgw-subnet-cidr 10.225.0.0/16
```

After a few minutes, the command completes and returns JSON-formatted information about the cluster, including the following:

```output
  "nodeResourceGroup": "MC_java-liberty-project_myAKSCluster_eastus",
  "privateFqdn": null,
  "provisioningState": "Succeeded",
  "resourceGroup": "java-liberty-project",
```

### Add a user node pool to the AKS cluster

To run your application on a user node pool, you will need to add it beforehand. Run the following commands to add a user nood pool:

```azurecli-interactive
NODE_LABEL_KEY=sku
NODE_LABEL_VALUE=gpu
az aks nodepool add \
    --resource-group $RESOURCE_GROUP_NAME \
    --cluster-name $CLUSTER_NAME \
    --name labelnp \
    --node-count 1 \
    --labels ${NODE_LABEL_KEY}=${NODE_LABEL_VALUE}

# Optional: list node pools
az aks nodepool list -g $RESOURCE_GROUP_NAME --cluster-name $CLUSTER_NAME
```

### Connect to the AKS cluster

To manage a Kubernetes cluster, you use [kubectl](https://kubernetes.io/docs/reference/kubectl/overview/), the Kubernetes command-line client. If you use Azure Cloud Shell, `kubectl` is already installed. To install `kubectl` locally, use the [az aks install-cli](/cli/azure/aks#az_aks_install_cli) command:

```azurecli-interactive
az aks install-cli
```

To configure `kubectl` to connect to your Kubernetes cluster, use the [az aks get-credentials](/cli/azure/aks#az_aks_get_credentials) command. This command downloads credentials and configures the Kubernetes CLI to use them.

```azurecli-interactive
az aks get-credentials --resource-group $RESOURCE_GROUP_NAME --name $CLUSTER_NAME --overwrite-existing
```

To verify the connection to your cluster, use the [kubectl get]( https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#get) command to return a list of the cluster nodes.

```azurecli-interactive
kubectl get nodes
```

The following example output shows the single node created in the previous steps. Make sure that the status of the node is *Ready*:

```output
NAME                                STATUS   ROLES   AGE     VERSION
aks-labelnp-xxxxxxxx-yyyyyyyyyy     Ready    agent   76s     v1.20.9
aks-nodepool1-xxxxxxxx-yyyyyyyyyy   Ready    agent   76s     v1.20.9
```

## Install Open Liberty Operator

After creating and connecting to the cluster, install the [Open Liberty Operator](https://github.com/OpenLiberty/open-liberty-operator/tree/master/deploy/releases/0.8.2) by running the following commands.

```azurecli-interactive
OPERATOR_NAMESPACE=default
WATCH_NAMESPACE='""'

# Install Custom Resource Definitions (CRDs) for OpenLibertyApplication
kubectl apply -f https://raw.githubusercontent.com/OpenLiberty/open-liberty-operator/main/deploy/releases/0.8.2/kubectl/openliberty-app-crd.yaml

# Install cluster-level role-based access to watch all namespaces
curl -L https://raw.githubusercontent.com/OpenLiberty/open-liberty-operator/main/deploy/releases/0.8.2/kubectl/openliberty-app-rbac-watch-all.yaml \
    | sed -e "s/OPEN_LIBERTY_OPERATOR_NAMESPACE/${OPERATOR_NAMESPACE}/" \
    | kubectl apply -f -

# Install the operator on the user node pool
rm -rf openliberty-app-operator.yaml
wget https://raw.githubusercontent.com/OpenLiberty/open-liberty-operator/main/deploy/releases/0.8.2/kubectl/openliberty-app-operator.yaml -O openliberty-app-operator.yaml
cat <<EOF >>openliberty-app-operator.yaml
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: ${NODE_LABEL_KEY}
                operator: In
                values:
                - ${NODE_LABEL_VALUE}
EOF

cat openliberty-app-operator.yaml \
    | sed -e "s/OPEN_LIBERTY_WATCH_NAMESPACE/${WATCH_NAMESPACE}/" \
    | kubectl apply -n ${OPERATOR_NAMESPACE} -f -

rm -rf openliberty-app-operator.yaml
```

## Build application image

To deploy and run your Liberty application on the AKS cluster, containerize your application as a Docker image using [Open Liberty container images](https://github.com/OpenLiberty/ci.docker) or [WebSphere Liberty container images](https://github.com/WASdev/ci.docker).

1. Clone the sample code for this guide. The sample is on [GitHub](https://github.com/majguo/java-on-azure-samples).
1. Locate to your local clone and run `cd agic-aks` to change to its sub directory `agic-aks`.
1. Run `mvn clean package` to package the application.
1. Run `mvn liberty:dev` to test the application. You should see `The defaultServer server is ready to run a smarter planet.` in the command output if successful. Use `CTRL-C` to stop the application.
1. Retrieve values for properties `artifactId` and `version` defined in the `pom.xml`.

   ```azurecli-interactive
   artifactId=$(mvn -q -Dexec.executable=echo -Dexec.args='${project.artifactId}' --non-recursive exec:exec)
   version=$(mvn -q -Dexec.executable=echo -Dexec.args='${project.version}' --non-recursive exec:exec)
   ```

1. Run `cd target` to change directory to the build of the sample.
1. Run one of the following commands to build the application image and push it to the ACR instance.
   * Build with Open Liberty base image if you prefer to use Open Liberty as a lightweight open source Java™ runtime:

     ```azurecli-interactive
     # Build and tag application image. This will cause the ACR instance to pull the necessary Open Liberty base images.
     az acr build -t ${artifactId}:${version} -r $REGISTRY_NAME .
     ```

   * Build with WebSphere Liberty base image if you prefer to use a commercial version of Open Liberty:

     ```azurecli-interactive
     # Build and tag application image. This will cause the ACR instance to pull the necessary WebSphere Liberty base images.
     az acr build -t ${artifactId}:${version} -r $REGISTRY_NAME --file=Dockerfile-wlp .
     ```

## Deploy application on the AKS cluster

Follow steps below to deploy the Liberty application on the AKS cluster.

1. Create a namespace for the sample.

   ```azurecli-interactive
   APPLICATION_NAMESPACE=javaee-app-sample-namespace
   kubectl create namespace ${APPLICATION_NAMESPACE}
   ```

1. Create a pull secret so that the AKS cluster is authenticated to pull image from the ACR instance.

   ```azurecli-interactive
   PULL_SECRET_NAME=javaee-app-sample-pull-secret
   kubectl create secret docker-registry ${PULL_SECRET_NAME} \
      --docker-server=${LOGIN_SERVER} \
      --docker-username=${USER_NAME} \
      --docker-password=${PASSWORD} \
      --namespace=${APPLICATION_NAMESPACE}
   ```

1. Verify the current working directory is `agic-aks/target` of your local clone.
1. Run the following commands to deploy your Liberty application with 3 replicas to the AKS cluster. Command output is also shown inline.

   ```azurecli-interactive
   # Create OpenLibertyApplication "javaee-app-sample"
   APPLICATION_NAME=javaee-app-sample
   REPLICAS=3

   cat openlibertyapplication.yaml \
       | sed -e "s/\${APPLICATION_NAME}/${APPLICATION_NAME}/g" \
       | sed -e "s/\${APPLICATION_NAMESPACE}/${APPLICATION_NAMESPACE}/g" \
       | sed -e "s/\${REPLICAS}/${REPLICAS}/g" \
       | sed -e "s/\${LOGIN_SERVER}/${LOGIN_SERVER}/g" \
       | sed -e "s/\${PULL_SECRET_NAME}/${PULL_SECRET_NAME}/g" \
       | sed -e "s/\${NODE_LABEL_KEY}/${NODE_LABEL_KEY}/g" \
       | sed -e "s/\${NODE_LABEL_VALUE}/${NODE_LABEL_VALUE}/g" \
       | kubectl apply -f -

   openlibertyapplication.apps.openliberty.io/javaee-app-sample created

   # Check if OpenLibertyApplication instance is created
   kubectl get openlibertyapplication ${APPLICATION_NAME} -n ${APPLICATION_NAMESPACE}

   NAME                   IMAGE                                                   EXPOSED   RECONCILED   AGE
   javaee-app-sample      youruniqueacrname.azurecr.io/javaee-cafe:1.0.0          True         59s

   # Check if deployment created by Operator is ready
   kubectl get deployment ${APPLICATION_NAME} -n ${APPLICATION_NAMESPACE} --watch

   NAME                     READY   UP-TO-DATE   AVAILABLE   AGE
   javaee-app-sample        0/3     3            0           20s
   ```

1. Wait until you see `3/3` under the `READY` column and `3` under the `AVAILABLE` column, use `CTRL-C` to stop the `kubectl` watch process.

1. Run the following commands to deploy Ingress resource for routing client requests to your deployed application. Command output is also shown inline.

   ```azurecli-interactive
   # Create Ingress "javaee-app-sample-ingress"
   APPLICATION_INGRESS=javaee-app-sample-ingress

   cat appgw-cluster-ingress.yaml \
       | sed -e "s/\${APPLICATION_INGRESS}/${APPLICATION_INGRESS}/g" \
       | sed -e "s/\${APPLICATION_NAMESPACE}/${APPLICATION_NAMESPACE}/g" \
       | sed -e "s/\${APPLICATION_NAME}/${APPLICATION_NAME}/g" \
       | kubectl apply -f -

   ingress.networking.k8s.io/javaee-app-sample-ingress created

   # Check if Ingress instance is created
   kubectl get ingress ${APPLICATION_INGRESS} -n ${APPLICATION_NAMESPACE}

   NAME                        CLASS    HOSTS   ADDRESS        PORTS   AGE
   javaee-app-sample-ingress   <none>   *       20.62.178.13   80      17s
   ```

### Test the application

To get public IP address of the Ingress, use the [kubectl get ingress](https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#get) command with the `--watch` argument.

```azurecli-interactive
kubectl get ingress ${APPLICATION_INGRESS} -n ${APPLICATION_NAMESPACE} --watch

NAME                        CLASS    HOSTS   ADDRESS        PORTS   AGE
javaee-app-sample-ingress   <none>   *       20.62.178.13   80      5m49s
```

Once the *ADDRESS* represents to an actual public IP address, use `CTRL-C` to stop the `kubectl` watch process.

Open a web browser to the external IP address of your Ingress (`20.62.178.13` for the above example) to see the application home page. You should see the pod name of your application replicas displayed at the top-left of the page.

## Clean up the resources

To avoid Azure charges, you should clean up unnecessary resources.  When the cluster is no longer needed, use the [az group delete](/cli/azure/group#az_group_delete) command to remove the resource group, container service, container registry, and all related resources.

```azurecli-interactive
az group delete --name $RESOURCE_GROUP_NAME --yes --no-wait
```
