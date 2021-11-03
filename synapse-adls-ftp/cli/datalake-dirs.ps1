# Creates data lake directories based on chosen subject areas and filesystem

param ($dataLakeStorageAccountName)

# Filesystems (Should already be created by the Bicep template)
$fileSystem1 = "raw"
$fileSystem2 = "cleansed"
$fileSystem3 = "curated"
$fileSystem4 = "laboratory"
$fileSystem5 = "staging"

# Subject areas
$subjectAreadir1 = "Customer"
$subjectAreadir2 = "Finance"
$subjectAreadir3 = "Sales"

# Create directorys in the raw filesystem
az storage fs directory create -n $subjectAreadir1 -f $fileSystem1 --account-name $datalakeStorageAccountName --auth-mode key
az storage fs directory create -n $subjectAreadir2 -f $fileSystem1 --account-name $datalakeStorageAccountName --auth-mode key
az storage fs directory create -n $subjectAreadir3 -f $fileSystem1 --account-name $datalakeStorageAccountName --auth-mode key

# Create directorys in the cleansed filesystem
az storage fs directory create -n $subjectAreadir1 -f $fileSystem2 --account-name $datalakeStorageAccountName --auth-mode key
az storage fs directory create -n $subjectAreadir2 -f $fileSystem2 --account-name $datalakeStorageAccountName --auth-mode key
az storage fs directory create -n $subjectAreadir3 -f $fileSystem2 --account-name $datalakeStorageAccountName --auth-mode key

# Create directorys in the curated filesystem
az storage fs directory create -n $subjectAreadir1/dimensions -f $fileSystem3 --account-name $datalakeStorageAccountName --auth-mode key
az storage fs directory create -n $subjectAreadir2/dimensions -f $fileSystem3 --account-name $datalakeStorageAccountName --auth-mode key
az storage fs directory create -n $subjectAreadir3/dimensions -f $fileSystem3 --account-name $datalakeStorageAccountName --auth-mode key

az storage fs directory create -n $subjectAreadir1/facts -f $fileSystem3 --account-name $datalakeStorageAccountName --auth-mode key
az storage fs directory create -n $subjectAreadir2/facts -f $fileSystem3 --account-name $datalakeStorageAccountName --auth-mode key
az storage fs directory create -n $subjectAreadir3/facts -f $fileSystem3 --account-name $datalakeStorageAccountName --auth-mode key

# Create directorys in the staging filesystem
az storage fs directory create -n $subjectAreadir1 -f $fileSystem5 --account-name $datalakeStorageAccountName --auth-mode key
