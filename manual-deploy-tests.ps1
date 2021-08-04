# Run a resource group Bicep deployment to an Azure subscription with a what-if confirmation.
$subscriptionID = ""
$resourceGroupName = ""
$parametersFilePath = "./bicep/prod-parameters.json"
$templateFilePath = "./bicep/main.bicep"

az account set --subscription $subscriptionID
az deployment group --resource-group $resourceGroupName --confirm-with-what-if --name DW --template-file $templateFilePath --parameters $parametersFilePath
