A Bicep template covering the infrastructure components of a modern data warehouse deployment using Azure Synapse. Also includes an FTP server running on Azure Container Instance for data ingestion.

Dependencies:
- Azure AD Group object id for Data Engineers
- Azure AD Group object id for Data Analysts
- Azure AD Group object id for Infrastructure Admins

<br>

Creates:
- Azure Key Vault with access policies set for AD Groups and Synapse managed identity. Solution secrets are automatically added
- Azure Data Lake Storage Gen 2 with a standard data lake filesystem structure and RBAC assignments
- Azure Synapse Workspace
- Azure Container Instance FTP solution using Azure Files for persistent storage
- Log Analytics Workspace with synapse diagnostic logs configured





