# Run a resource group Bicep deployment to an Azure subscription with a what-if confirmation.
$subscriptionID = ""
$resourceGroupName = ""
$parametersFilePath = "./bicep/prod-parameters.json"
$templateFilePath = "./bicep/main.bicep"

az account set --subscription $subscriptionID
az deployment group create --confirm-with-what-if --name "DEPLOYMENT NAME" --resource-group $resourceGroupName --template-file $templateFilePath --parameters $parametersFilePath
