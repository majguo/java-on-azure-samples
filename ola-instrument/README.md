# Instrument Open Liberty Application with the java agent

The guidance decribes the steps on how to instrument Open Liberty Application with the java agent [dd-java-agent](https://mvnrepository.com/artifact/com.datadoghq/dd-java-agent). The Open Liberty Application is a custom resource with type `OpenLibertyApplication` running as a container in a pod of an AKS cluster, which is managed by [Open Liberty Operator](https://github.com/OpenLiberty/open-liberty-operator).

## Create an AKS cluster

Follow steps below to create an AKS cluster with specified version 1.22.6.

```azurecli-interactive
# Create resource group
# Replace <prefix> with the one you prefer 
RESOURCE_GROUP_NAME=<prefix>-aks-1.22.6
az group create --name $RESOURCE_GROUP_NAME --location eastus

# Create AKS cluster
CLUSTER_NAME=aksCluster
az aks create --resource-group $RESOURCE_GROUP_NAME --name $CLUSTER_NAME --kubernetes-version 1.22.6 --node-count 1 --generate-ssh-keys --enable-managed-identity --zones 1 2 3

# Connect to the AKS cluster
az aks get-credentials --resource-group $RESOURCE_GROUP_NAME --name $CLUSTER_NAME --overwrite-existing
```

## Install Open Liberty Operator v0.8.2

You're going to install the Operator in `default` namespace, and make it watch all namespaces. Follow [guidance](https://github.com/OpenLiberty/open-liberty-operator/tree/main/deploy/releases/0.8.2/kubectl) or steps below to complete the installation:

```azurecli-interactive
# Install Custom Resource Definitions (CRDs) for OpenLibertyApplication
kubectl apply -f https://raw.githubusercontent.com/OpenLiberty/open-liberty-operator/main/deploy/releases/0.8.2/kubectl/openliberty-app-crd.yaml

# Install cluster-level role-based access to watch all namespaces
OPERATOR_NAMESPACE=default
WATCH_NAMESPACE='""'
curl -L https://raw.githubusercontent.com/OpenLiberty/open-liberty-operator/main/deploy/releases/0.8.2/kubectl/openliberty-app-rbac-watch-all.yaml \
    | sed -e "s/OPEN_LIBERTY_OPERATOR_NAMESPACE/${OPERATOR_NAMESPACE}/" \
    | kubectl apply -f -

# Install the operator
curl -L https://raw.githubusercontent.com/OpenLiberty/open-liberty-operator/main/deploy/releases/0.8.2/kubectl/openliberty-app-operator.yaml \
    | sed -e "s/OPEN_LIBERTY_WATCH_NAMESPACE/${WATCH_NAMESPACE}/" \
    | kubectl apply -n ${OPERATOR_NAMESPACE} -f -
```

## Deploy a sample instrumented with the java agent

Follow steps below to complete the deployment.

```azurecli-interactive
cat <<EOF | kubectl apply -f -
apiVersion: apps.openliberty.io/v1beta2
kind: OpenLibertyApplication
metadata:
  name: demoapp
  labels:
    name: demoapp
    tags.datadoghq.com/env: "dev"
    tags.datadoghq.com/service: "demoapp"
    tags.datadoghq.com/version: "12"
  annotations:
    ad.datadoghq.com/demoapp.logs: '[{"source": "java", "service": "demoapp", "log_processing_rules": [{"type": "multi_line", "name": "log_start_with_date", "pattern" : "\\d{4}-(0?[1-9]|1[012])-(0?[1-9]|[12][0-9]|3[01])"}]}]'
    apm.datadoghq.com/env: '{ "DD_ENV": "dev", "DD_SERVICE": "demoapp", "DD_VERSION": "12", "DD_TRACE_ANALYTICS_ENABLED": "true" }'
spec:
  replicas: 2
  applicationImage: icr.io/appcafe/open-liberty/samples/getting-started
  pullPolicy: Always
  service:
    type: LoadBalancer
    targetPort: 9080
    port: 80
  env:
  - name: WLP_LOGGING_CONSOLE_FORMAT
    value: SIMPLE
  - name: DD_AGENT_HOST
    valueFrom:
      fieldRef:
        fieldPath: status.hostIP
  - name: DD_ENV
    valueFrom:
      fieldRef:
        fieldPath: metadata.labels['tags.datadoghq.com/env']
  - name: DD_SERVICE
    valueFrom:
      fieldRef:
        fieldPath: metadata.labels['tags.datadoghq.com/service']
  - name: DD_VERSION
    valueFrom:
      fieldRef:
        fieldPath: metadata.labels['tags.datadoghq.com/version']
  - name: JAVA_TOOL_OPTIONS
    value: >
      -javaagent:/app/javaagent/dd-java-agent.jar 
      -Ddd.env=dev -Ddd.service=demoapp 
      -Ddd.version=12 -Ddd.tags=env:dev -Ddd.trace.sample.rate=1 -Ddd.logs.injection=true 
      -Ddd.profiling.enabled=true -XX:FlightRecorderOptions=stackdepth=256 
      -Ddd.trace.http.client.split-by-domain=true ${JAVA_TOOL_OPTIONS}
      -XX:+IgnoreUnrecognizedVMOptions -XX:+PortableSharedCache -XX:+IdleTuningGcOnIdle 
      -Xshareclasses:name=openj9_system_scc,cacheDir=/opt/java/.scc,readonly,nonFatal
  initContainers:
  - name: download-dd-java-agent
    image: busybox:1.28
    command:
    - wget
    - "-O"
    - "/work-dir/dd-java-agent.jar"
    - "https://repo1.maven.org/maven2/com/datadoghq/dd-java-agent/0.104.0/dd-java-agent-0.104.0.jar"
    volumeMounts:
    - name: workdir
      mountPath: /work-dir
  volumeMounts:
  - name: workdir
    mountPath: /app/javaagent
  volumes:
  - name: workdir
    emptyDir: {}
EOF
```

## Verification and cleanup

To verify if the deployment succeeded, run the following commands to verify:


Finally, remember to clean up the resources if they're no longer needed:

```azurecli-interactive
az group delete --name ${RESOURCE_GROUP_NAME} --yes --no-wait 
```

## References

* [ptabasso2/springkafkacassandrak8s/k8s/depl.yaml](https://github.com/ptabasso2/springkafkacassandrak8s/blob/df93048571b26026bb5ccf3f70ec27d8f37ebe90/k8s/depl.yaml#L91-L141)
