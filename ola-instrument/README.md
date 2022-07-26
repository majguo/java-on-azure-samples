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

The following deployment manifest is based on [Pej's sample](https://github.com/ptabasso2/springkafkacassandrak8s/blob/df93048571b26026bb5ccf3f70ec27d8f37ebe90/k8s/depl.yaml#L91-L141) and revised to make it comply with `OpenLibertyApplication` CRD supported by Open Liberty Operator.  Execute the command below to deploy an `OpenLibertyApplication` sample instrumented with the java agent.

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
  replicas: 1
  applicationImage: icr.io/appcafe/open-liberty/samples/getting-started
  pullPolicy: Always
  service:
    type: LoadBalancer
    targetPort: 9080
    port: 80
  env:
  # The log format is JSON by default, setting to 'SIMPLE' will change it to be plain text which is easy for human reading.
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

> **Note**
> The following JVM options passed to env `JAVA_TOOL_OPTIONS` are not related to agent instrument. Instead, they're default value of `JAVA_TOOL_OPTIONS` of open liberty image, see Line 9 of [Image Layer Details - openliberty/open-liberty:latest](https://hub.docker.com/layers/open-liberty/openliberty/open-liberty/latest/images/sha256-0fd8f1ef4a324af43912fbfb6a720b9294af4be39183777490c87f40c08577a5?context=explore) as an example.
> 
> ```
> -XX:+IgnoreUnrecognizedVMOptions -XX:+PortableSharedCache -XX:+IdleTuningGcOnIdle 
> -Xshareclasses:name=openj9_system_scc,cacheDir=/opt/java/.scc,readonly,nonFatal
> ```

## Verification

Follow steps below to verify if the sample is successfully deployed and instrumented with the java agent:

1. Get the list of pods associated with the sample CR which are indirectly created by Open Liberty Operator:

   ```
   kubectl get pod
   ```

1. Inspect the log of the pod whose name starts with `demoapp`:

   ```
   kubectl logs <demoapp-xxxx-xxxxx> -f
   ```

   Here is the [log sample](./log/pod.log) I captured before. You should see the [similar log entry](https://github.com/majguo/java-on-azure-samples/blob/main/ola-instrument/log/pod.log#L1) at the beginning:

   ```
   [dd.trace 2022-07-26 07:01:21:105 +0000] [dd-task-scheduler] INFO datadog.trace.agent.core.StatusLogger - DATADOG TRACER CONFIGURATION {"version":"0.104.0~a17ff6ca7f","os_name":"Linux","os_version":"5.4.0-1085-azure","architecture":"amd64","lang":"jvm","lang_version":"11.0.15","jvm_vendor":"IBM Corporation","jvm_version":"openj9-0.32.0","java_class_version":"55.0","http_nonProxyHosts":"null","http_proxyHost":"null","enabled":true,"service":"demoapp","agent_url":"http://10.224.0.4:8126","agent_error":true,"debug":false,"analytics_enabled":false,"sample_rate":1.0,"sampling_rules":[{},{}],"priority_sampling_enabled":true,"logs_correlation_enabled":true,"profiling_enabled":true,"appsec_enabled":false,"dd_version":"0.104.0~a17ff6ca7f","health_checks_enabled":true,"configuration_file":"no config file present","runtime_id":"50178bea-a266-460c-8048-9c046159d316","logging_settings":{"levelInBrackets":false,"dateTimeFormat":"'[dd.trace 'yyyy-MM-dd HH:mm:ss:SSS Z']'","logFile":"System.err","configurationFile":"simplelogger.properties","showShortLogName":false,"showDateTime":true,"showLogName":true,"showThreadName":true,"defaultLogLevel":"INFO","warnLevelString":"WARN","embedException":false},"cws_enabled":false,"cws_tls_refresh":5000}
   ``` 

Wait for a while, you will observe `Failed to upload profile to ...` is reported in the log. Here is the [similar log entry](https://github.com/majguo/java-on-azure-samples/blob/main/ola-instrument/log/pod.log#L58) in the [log sample](./log/pod.log):

```
[dd.trace 2022-07-26 07:03:25:300 +0000] [OkHttp http://10.224.0.4:8126/...] WARN com.datadog.profiling.uploader.ProfileUploader - Failed to upload profile to http://10.224.0.4:8126/profiling/v1/input java.net.ConnectException: Failed to connect to /10.224.0.4:8126 (Will not log errors for 5 minutes)
```

The error seems to be caused by the fact that a datadog server is unavailable for the sample instrumented with `dd-java-agent`, which is configured using environment variable `DD_AGENT_HOST`. As the image `icr.io/appcafe/open-liberty/samples/getting-started` I used in the sample is from [Open Liberty Getting Started sample](https://github.com/OpenLiberty/sample-getting-started), it seems reasonable that the sample hasn't been configured with a working `DD_AGENT_HOST`.

## Cleanup

Finally, remember to clean up the resources if they're no longer needed:

```azurecli-interactive
az group delete --name ${RESOURCE_GROUP_NAME} --yes --no-wait 
```
