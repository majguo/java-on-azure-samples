# Java on Azure Samples

This repo is for hosting Java on Azure samples for different user scenarios.

## Disaster recovery solutions for WebLogic cluster on Azure VMs

The samples below describe different solutions for disaster recovery of WebLogic cluster on Azure VMs.

1. [Deploying a database based disaster recovery solution of WebLogic on Azure VMs](./wls-dr-database/README.md)
1. [Deploying an ASR based disaster recovery solution of WebLogic on Azure VMs](./wls-dr-asr/README.md)
1. [Deploying a filesystem based disaster recovery solution of WebLogic on Azure VMs](./wls-dr-filesystem/README.md)

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

## JBoss EAP on Azure App Service

The samples below describe different use cases of JBoss EAP on Azure App Service.

1. [JBoss EAP JMS sample using Message-Driven Bean](https://github.com/majguo/jboss-eap-on-app-service)
