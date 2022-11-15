# demo-azure-arc

## Prerequisites
https://learn.microsoft.com/en-us/azure/azure-arc/kubernetes/quickstart-connect-cluster?tabs=azure-cli#prerequisites
Azure CLI
az extension add --name connectedk8s

az provider register --namespace Microsoft.Kubernetes
az provider register --namespace Microsoft.KubernetesConfiguration
az provider register --namespace Microsoft.ExtendedLocation

### Powershell
$resourceGroup="rg-ipsazurearcdemo"
$aksName="aks-azurearcdemo"
$resourceLocation="westeurope"
$arcClusterName="arck-azurearcdemo"

az aks get-credentials -g $resourceGroup -n $aksName --admin --file config
kubectl get ns --kubeconfig config
az connectedk8s connect -g $resourceGroup -n $arcClusterName --kube-config config
az connectedk8s show -g $resourceGroup -n $arcClusterName

## Log Analytics
$workspaceName="log-azurearcdemo"

$logAnalyticsWorkspaceId=$(az monitor log-analytics workspace show `
    --resource-group $resourceGroup `
    --workspace-name $workspaceName `
    --query customerId `
    --output tsv)
$logAnalyticsWorkspaceIdEnc=[Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($logAnalyticsWorkspaceId))
$logAnalyticsKey=$(az monitor log-analytics workspace get-shared-keys `
    --resource-group $resourceGroup `
    --workspace-name $workspaceName `
    --query primarySharedKey `
    --output tsv)
$logAnalyticsKeyEnc=[Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($logAnalyticsKey))

## App Service on Azure Arc
### Arc cluster setup
https://learn.microsoft.com/en-us/azure/app-service/manage-create-arc-environment?tabs=powershell
az extension add --upgrade --yes --name customlocation
az extension remove --name appservice-kube
az extension add --upgrade --yes --name appservice-kube

$extensionName="appservice-ext" # Name of the App Service extension
$namespace="appservice-ns" # Namespace in your cluster to install the extension and provision resources
$kubeEnvironmentName="ase-azurearcdemo" # Name of the App Service Kubernetes environment resource

az k8s-extension create `
    --resource-group $resourceGroup `
    --name $extensionName `
    --cluster-type connectedClusters `
    --cluster-name $arcClusterName `
    --extension-type 'Microsoft.Web.Appservice' `
    --release-train stable `
    --auto-upgrade-minor-version true `
    --scope cluster `
    --release-namespace $namespace `
    --configuration-settings "Microsoft.CustomLocation.ServiceAccount=default" `
    --configuration-settings "appsNamespace=${namespace}" `
    --configuration-settings "clusterName=${kubeEnvironmentName}" `
    --configuration-settings "keda.enabled=true" `
    --configuration-settings "buildService.storageClassName=default" `
    --configuration-settings "buildService.storageAccessMode=ReadWriteOnce" `
    --configuration-settings "customConfigMap=${namespace}/kube-environment-config" `
    --configuration-settings "envoy.annotations.service.beta.kubernetes.io/azure-load-balancer-resource-group=${resourceGroup}" `
    --configuration-settings "logProcessor.appLogs.destination=log-analytics" `
    --configuration-protected-settings "logProcessor.appLogs.logAnalyticsConfig.customerId=${logAnalyticsWorkspaceIdEnc}" `
    --configuration-protected-settings "logProcessor.appLogs.logAnalyticsConfig.sharedKey=${logAnalyticsKeyEnc}"

$extensionId=$(az k8s-extension show `
    --cluster-type connectedClusters `
    --cluster-name $arcClusterName `
    --resource-group $resourceGroup `
    --name $extensionName `
    --query id `
    --output tsv)

kubectl get pods -n $namespace --kubeconfig config

### Custom location
$customLocationName="custom-location" # Name of the custom location
$connectedClusterId=$(az connectedk8s show --resource-group $resourceGroup --name $arcClusterName --query id --output tsv)

az customlocation create `
    --resource-group $resourceGroup `
    --name $customLocationName `
    --host-resource-id $connectedClusterId `
    --namespace $namespace `
    --cluster-extension-ids $extensionId

az customlocation show --resource-group $resourceGroup --name $customLocationName

$customLocationId=$(az customlocation show `
    --resource-group $resourceGroup `
    --name $customLocationName `
    --query id `
    --output tsv)

### App Service Kubernetes Environment

az appservice kube create `
    --resource-group $resourceGroup `
    --name $kubeEnvironmentName `
    --custom-location $customLocationId

az appservice kube show --resource-group $resourceGroup --name $kubeEnvironmentName


### Application
https://learn.microsoft.com/en-us/azure/app-service/quickstart-arc
az extension add --upgrade --yes --name customlocation
az extension remove --name appservice-kube
az extension add --upgrade --yes --name appservice-kube

$appName="app-azurearcdemo"

az webapp list-runtimes --os linux
az webapp create `
    --resource-group $resourceGroup `
    --name $appName `
    --custom-location $customLocationId `
    --runtime "NODE:14-lts"

git clone https://github.com/Azure-Samples/nodejs-docs-hello-world
Compress-Archive -Path ./nodejs-docs-hello-world/* -DestinationPath package.zip -Force
<!-- az webapp config appsettings set -g $resourceGroup -n $appName --settings SCM_DO_BUILD_DURING_DEPLOYMENT=true -->
az webapp deployment source config-zip -g $resourceGroup -n $appName --src package.zip