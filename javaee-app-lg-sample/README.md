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
