# Java on Azure Samples

This repo is for hosting Java on Azure samples for different user scenarios.

## Disaster recovery solutions for WebLogic cluster on Azure VMs

The samples below describe different solutions for disaster recovery of WebLogic cluster on Azure VMs.

1. [Deploying a database based disaster recovery solution of WebLogic on Azure VMs](./wls-dr-database/README.md)
1. [Deploying an ASR based disaster recovery solution of WebLogic on Azure VMs](./wls-dr-asr/README.md)
1. [Deploying a filesystem based disaster recovery solution of WebLogic on Azure VMs](./wls-dr-filesystem/README.md)

## WebSphere on Azure VMs

The samples below describe different use cases of WebSphere on Azure VMs.

1. [Disaster recovery solution of WebSphere on Azure VM](https://github.com/majguo/websphere-on-azure)

## Connect to Azure SQL

The samples below describe different scenarios to connect to Azure SQL database.

1. [Connect to Azure SQL with authentication "ActiveDirectoryPassword"](./sql-auth-aad-password/README.md)
1. [Integrate Open Liberty with AzureSQL using Active Directory Password](./javaee-cafe-mssql-auth-aad-password/README.md)

## Install Open Liberty Operator v0.8.2 using kubectl

This [module](./olo-installation/README.md) provies guides on installing Open Liberty Operator 0.8.2 in different modes, including:

1. [Watch own namespace](./olo-installation/watch-own-namespace.md)
1. [Watch another namespace](./olo-installation/watch-another-namespace.md)
1. [Watch all namespaces](./olo-installation/watch-all-namespaces.md)

## Enable Application Gateway Ingress Controller (AGIC)

This [module](./agic-aks/README.md) provides guides on enabling AGIC for the AKST cluster with different approaches, including:

1. [Enable AGIC with AKS Add-On](./agic-aks/agic-addon.md)
1. [Enable AGIC with Helm using service principal credentials](./agic-aks/agic-helm-sp.md)
1. [Enable AGIC with Helm using AAD Pod Identity](./agic-aks/agic-helm-identity.md)

## Instrument Open Liberty Application 

The guidance decribes the steps on how to instrument Open Liberty Application with the java agent dd-java-agent.

1. [Instrument Open Liberty Application with the java agent](./ola-instrument/README.md)

## JBoss EAP on Azure App Service

The samples below describe different use cases of JBoss EAP on Azure App Service.

1. [JBoss EAP JMS sample using Message-Driven Bean](https://github.com/majguo/jboss-eap-on-app-service)

## Quarkus on Azure

The guidance decribes the steps on how to deploy and run Quarkus app on Azure.

1. [Deploy and run a simple Quarkus app on Azure Spring Apps](./quarkus/quarkus-on-asa.md)
1. [Communication between microservices in Azure Spring Apps and Azure Container Apps](./quarkus/quarkus-quickstart.md)
1. [Connect to Azure Storage Blob using Microsoft Entra ID](./camel-quarkus-azure-storage-blob/)

## Java on Azure Container Apps

The guidance decribes the steps and samples on how to deploy a complete microservices application on Azure Container Apps.

1. [Java on Azure Container Apps Workshop](https://github.com/majguo/azure-spring-apps-training/tree/master/aca)

## Other guides engaged

1. [Access Azure Database for Postgresql using Managed Identities in WebSphere deployed on Azure](https://github.com/Azure-Samples/Passwordless-Connections-for-Java-Apps/tree/main/JakartaEE/websphere)
1. [Deploy Spring Petclinic Angular on Azure Container Apps](https://github.com/majguo/spring-petclinic-angular#deploy-on-azure-container-apps)
1. [PetClinic AI which integrates with OpenAI service using LangChain for Java](https://github.com/seanli1988/petclinic/tree/ai)
1. [PetClinic app which talks to OpenAI service](https://github.com/seanli1988/petclinic/tree/main)
