# demo-azure-arc

## Prerequisites
https://learn.microsoft.com/en-us/azure/azure-arc/kubernetes/quickstart-connect-cluster?tabs=azure-cli#prerequisites
Azure CLI
az extension add --name connectedk8s
kubectl config set-context
Helm 3 (3.7.0+)

az provider register --namespace Microsoft.Kubernetes
az provider register --namespace Microsoft.KubernetesConfiguration
az provider register --namespace Microsoft.ExtendedLocation