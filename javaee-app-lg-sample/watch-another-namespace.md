# Watch Another Namespace

The guidance decribes the steps on how to install Open Liberty Operator v0.8.0 using kubectl and make it watch **another namespace** on events including if there're any resources with type as Open Liberty Operatro supported CRDs created, updated or deleted. Besides, it also includes the instructions on how to create a user node pool, where you can install the Open Liberty Operator and sample application using `nodeAffinity`, as well as how to evenly distribute pods to nodes in different zones for high availability using `podAntiAffinity`.

## Create an AKS cluster 1.22.6 and add a user node pool with 3 nodes

Follow steps below to create an AKS cluster with specified version 1.22.6, and add a user node pool later.

```azurecli-interactive
# Create resource group
# Replace <prefix> with the one you prefer 
RESOURCE_GROUP_NAME=<prefix>-aks-1.22.6
az group create --name $RESOURCE_GROUP_NAME --location eastus

# Create AKS cluster
CLUSTER_NAME=aksCluster
az aks create --resource-group $RESOURCE_GROUP_NAME --name $CLUSTER_NAME --kubernetes-version 1.22.6 --node-count 1 --generate-ssh-keys --enable-managed-identity --zones 1 2 3

# Create a user node pool
NODE_LABEL_KEY=stage
NODE_LABEL_VALUE=dev

az aks nodepool add \
    --resource-group $RESOURCE_GROUP_NAME \
    --cluster-name $CLUSTER_NAME \
    --name devnp \
    --node-count 3 \
    --labels ${NODE_LABEL_KEY}=${NODE_LABEL_VALUE} \
    --zones 1 2 3

# Connect to the AKS cluster
az aks get-credentials --resource-group $RESOURCE_GROUP_NAME --name $CLUSTER_NAME --overwrite-existing
```

## Install Open Liberty Operator v0.8.0 using kubectl on the user node pool

You're going to install the Operator in `default` namespace on the user node pool, and make it watch another namespace `app-namespace`. Follow steps below to complete the installation:

```azurecli-interactive
# Create namespace for deploying sample app
APP_NAMESPACE=app-namespace
kubectl create namespace $APP_NAMESPACE

# Install Custom Resource Definitions (CRDs) for OpenLibertyApplication
kubectl apply -f https://raw.githubusercontent.com/OpenLiberty/open-liberty-operator/main/deploy/releases/0.8.0/kubectl/openliberty-app-crd.yaml

# Install role with access to another namespace
OPERATOR_NAMESPACE=default
WATCH_NAMESPACE=${APP_NAMESPACE}
curl -L https://raw.githubusercontent.com/OpenLiberty/open-liberty-operator/main/deploy/releases/0.8.0/kubectl/openliberty-app-rbac-watch-another.yaml \
    | sed -e "s/OPEN_LIBERTY_OPERATOR_NAMESPACE/${OPERATOR_NAMESPACE}/" \
    | sed -e "s/OPEN_LIBERTY_WATCH_NAMESPACE/${WATCH_NAMESPACE}/" \
    | kubectl apply -f -

# Install the operator on the user node pool
rm -rf openliberty-app-operator.yaml
wget https://raw.githubusercontent.com/OpenLiberty/open-liberty-operator/main/deploy/releases/0.8.0/kubectl/openliberty-app-operator.yaml -O openliberty-app-operator.yaml
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

## Deploy a sample `OpenLibertyApplication` app on the user node pool

To test if the Open Liberty Operator works, you're going to deploy an `OpenLibertyApplication` sample to the user node pool. Follow steps below to complete the deployment.

```azurecli-interactive
# Deploy sample application
cat <<EOF | kubectl apply -f -
apiVersion: apps.openliberty.io/v1beta2
kind: OpenLibertyApplication
metadata:
  name: lg-sample
  namespace: ${APP_NAMESPACE}
  labels:
    app: demo
spec:
  replicas: 3
  applicationImage: docker.io/majguo/javaee-cafe:1.0.25
  pullPolicy: Always
  service:
    type: LoadBalancer
    targetPort: 9080
    port: 80
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: ${NODE_LABEL_KEY}
            operator: In
            values:
            - ${NODE_LABEL_VALUE}
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
            - key: app
              operator: In
              values:
              - demo
          topologyKey: topology.kubernetes.io/zone
      - weight: 90
        podAffinityTerm:
          labelSelector:
            matchExpressions:
            - key: app
              operator: In
              values:
              - demo
          topologyKey: kubernetes.io/hostname
EOF
```

## Verification and cleanup

To verify if the deployment succeeds and the Pods are deployed to nodes in the user node pool, run the following commands to verify:

```azurecli-interactive
kubectl get pod -n ${APP_NAMESPACE}
kubectl get nodes -o custom-columns=NAME:'{.metadata.name}',REGION:'{.metadata.labels.topology\.kubernetes\.io/region}',ZONE:'{metadata.labels.topology\.kubernetes\.io/zone}'
kubectl get pod -o=custom-columns=Pod:.metadata.name,Node:.spec.nodeName --all-namespaces
```

Finally, remember to clean up the resources if they're no longer needed:

```azurecli-interactive
az group delete --name ${RESOURCE_GROUP_NAME} --yes --no-wait 
```
