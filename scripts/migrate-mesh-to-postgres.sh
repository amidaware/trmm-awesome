#!/usr/bin/env bash

# NOTE: Node might need some postgres modules installed.
#   cd $mesh_install
#   node npm install pg pgtools

# NOTE: These can be modified if necessary.
mesh_install="/meshcentral"
mesh_data="/meshcentral/meshcentral-data"
mesh_program="node_modules/meshcentral"

if ! which jq >/dev/null
then
	echo "jq is not installed"
	echo "Please install jq with:"
	echo "  sudo apt-get install jq"
	exit 1
fi

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

print_green() {
	printf >&2 "${GREEN}%0.s-${NC}" {1..80}
	printf >&2 "\n"
	printf >&2 "${GREEN}${1}${NC}\n"
	printf >&2 "${GREEN}%0.s-${NC}" {1..80}
	printf >&2 "\n"
}

print_green 'Creating login for the meshcentral database'
meshdbuser=$(cat /dev/urandom | tr -dc 'a-z' | fold -w 8 | head -n 1)
meshdbpw=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 20 | head -n 1)

# Postgres database name has to be "meshcentral"
# https://github.com/Ylianst/MeshCentral/issues/3398
meshdbname="meshcentral"

# Meshcentral configs
MESH_PG_DB="$meshdbname"
MESH_PG_USER="$meshdbuser"
MESH_PG_PW="$meshdbpw"
MESH_PG_PORT="5432"
MESH_PG_HOST="localhost"

print_green 'Creating postgres database for the meshcentral'
sudo -u postgres psql <<EOT
CREATE DATABASE ${meshdbname};
CREATE USER ${meshdbuser} WITH PASSWORD '${meshdbpw}';
ALTER ROLE ${meshdbuser} SET client_encoding TO 'utf8';
ALTER ROLE ${meshdbuser} SET default_transaction_isolation TO 'read committed';
ALTER ROLE ${meshdbuser} SET timezone TO 'UTC';
GRANT ALL PRIVILEGES ON DATABASE ${meshdbname} TO ${meshdbuser};
EOT

print_green 'Export meshcentral database'
cd "${mesh_install}"
node "${mesh_program}" --dbexport

cat "${mesh_data}/config.json" |
    jq " del(.settings.MongoDb, .settings.MongoDbName) " |
    jq " .settings.postgres.user |= \"${MESH_PG_USER}\" " |
    jq " .settings.postgres.password |= \"${MESH_PG_PW}\" " |
    jq " .settings.postgres.port |= \"${MESH_PG_PORT}\" " |
    jq " .settings.postgres.host |= \"${MESH_PG_HOST}\" " > "${mesh_data}/config-postgres.json"

# Backup Meshcentral config for MongoDB
print_green 'Backing up meshcentral config'
cp "${mesh_data}/config.json" "${mesh_data}/config-mongodb-$(date "+%Y%m%dT%H%M%S").json"
cp "${mesh_data}/config-postgres.json" "${mesh_data}/config.json"

print_green 'Restart meshcentral'
sudo systemctl restart meshcentral
print_green 'Import Database from meshcentral'
node "${mesh_program}" --dbimport
print_green 'Final restart of meshcentral'
sudo systemctl restart meshcentral

print_green 'Shutting down MongoDB'
sudo systemctl stop mongod.service
print_green 'Disabling MongoDB'
sudo systemctl disable mongod.service

