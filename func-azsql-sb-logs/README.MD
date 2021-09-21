A Bicep template for a serverless integration POC

Dependencies:
- Existing Azure AD group for SQL admin

<br>

Creates:
- Consumption based Azure Function connected to Azure Application Insights
- Serverless Azure SQL Database with Azure AD Authentication and logging to Log Analytics. Access allowed from all Azure Services
- Server Bus with 3 topics and logging to Log Analytics. Access granted from Function managed identity
- Log Analytics Workspace for centralised logging
- Key vault with secrets added and access granted to the Function managed identity