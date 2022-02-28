# Legal & General engagement samples

This document lists all samples developed while engaging with Legal & General.

## Enable Application Gateway Ingress Controller (AGIC)

There're 3 comprehensive guidances describing how to enable AGIC with different approaches, along with the end-to-end instructions about setting up the Azure Container Registry (ACR) instance, Azure Kubernetes Service (AKS) cluster with additonal user node pool, building the container image, pushing to the ACR instance and deploying to the AKS cluster:

1. [Enable AGIC with AKS Add-On](./agic-addon.md)
2. [Enable AGIC with Helm using service principal credentials](./agic-helm-sp.md)
3. [Enable AGIC with Helm using AAD Pod Identity](./agic-helm-identity.md)

References:

* [What is Application Gateway Ingress Controller?](https://docs.microsoft.com/azure/application-gateway/ingress-controller-overview)
* [Tutorial: Enable the Ingress Controller add-on for a new AKS cluster with a new Application Gateway instance](https://docs.microsoft.com/azure/application-gateway/tutorial-ingress-controller-add-on-new)
* [Install an Application Gateway Ingress Controller (AGIC) using an existing Application Gateway](https://docs.microsoft.com/azure/application-gateway/ingress-controller-install-existing)
## Install Open Liberty Operator v0.8.0 using kubectl

Depending on the operator is only watching own namespace, watching another namespace or all namespaces, there're 3 guidances describing how to install Open Liberty Operator v0.8.0 using kubectl, including the AKS setup with additonal user node pool, Operator installation, sample app deployment and verification:

1. [Watch own namespace](./watch-own-namespace.md)
1. [Watch another namespace](./watch-another-namespace.md)
1. [Watch all namespaces](./watch-all-namespaces.md)

Referneces:

* [Open Liberty Operator v0.8.0](https://github.com/OpenLiberty/open-liberty-operator/tree/main/deploy/releases/0.8.0)
* [Install using kubectl](https://github.com/OpenLiberty/open-liberty-operator/tree/main/deploy/releases/0.8.0/kubectl)