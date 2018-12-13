[![Build Status](https://cloud.drone.io/api/badges/lapazcloud/hashiapp/status.svg?branch=master)](https://cloud.drone.io/lapazcloud/hashiapp)

# Setup the servers
	
### Vault

```
export VAULT_ADDR=http://MASTER_IP:8200
```

```
vault operator init
```

```
vault operator unseal
```

```
vault login ${TOKEN}
```

### Database

```
vault secrets enable database
```

```
vault write database/config/hashidb \
    plugin_name=postgresql-database-plugin \
    allowed_roles="hashirole" \
    connection_url="postgresql://${USER}:${PASSWORD}@${DB_HOST}:5432/${DB_NAME}" 

```

```
vault write database/roles/hashirole \
    db_name=hashidb \
    creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
        GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
    default_ttl="1h" \
    max_ttl="24h"
```

### Clone the repo on the master server

```
git clone https://github.com/lapazcloud/hashiapp.git
```