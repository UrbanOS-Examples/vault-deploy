# vault
Define a vault deployment for secrets management within the cluster

How to use: https://github.com/SmartColumbusOS/scosopedia/wiki#vault

# Deployment
Until we have an automated way to do this or until we have no need to add additional policies and roles, any changes to policies and roles need to be applied manually using the following commands:

```
source /usr/local/bin/maintenance.sh

write_access_policies

enable_kubernetes
```

`enable_kubernetes` will give an error that can be safely ignored.

> Note: New deployments of Vault (that create a new Volume) will include all policies and roles that have been defined. This process is only needed for modifying existing deployments.
