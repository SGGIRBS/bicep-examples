A Bicep template for secured web app for containers using PostgreSQL as a backend.

Dependencies:

Existing Azure AD groups
Azure Front Door

Creates:

Container registry
Storage account with blob and file shares for web app for container persistent storage.
Two web app for containers running linux with a holding container deployed.
Various conditions for production resources including deployment slots for production only.
Azure Cache for Redis.
Azure PostgreSQL server Azure AD authentication and Allow All Azure Services firewall rule.
Key vault with secrets added and access granted to admin groups and app service managed identities.
