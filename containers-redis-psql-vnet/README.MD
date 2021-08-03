A Bicep template with various options for secure container deployments using PostgreSQL as a backend.

Dependencies:
- Existing private dns zones
- Existing virtual network
- Existing Azure AD groups

<br>

Creates:
- Container registry
- Storage account with private endpoint and file shares for web app for container persistent storage. Additional blob container for static web files.
- Two VNet integrated app services (web app for containers) running linux with a private endpoint and a holding container deployed.
- Azure Cache for Redis with a private endpoint.
- Azure PostgreSQL server with a private endpoint and Azure AD authentication.
- Linux virtual machine.
- Key vault with secrets added and access granted to the admin groups and app service managed identities.





