#!/usr/bin/env bash

print_green 'Creating login for the meshcentral database'
meshdbuser=$(cat /dev/urandom | tr -dc 'a-z' | fold -w 8 | head -n 1)
meshdbpw=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 20 | head -n 1)

print_green 'Creating database for the meshcentral'
sudo -u postgres psql -c "CREATE DATABASE meshcentral"
sudo -u postgres psql -c "CREATE USER ${meshdbuser} WITH PASSWORD '${meshdbpw}'"
sudo -u postgres psql -c "ALTER ROLE ${meshdbuser} SET client_encoding TO 'utf8'"
sudo -u postgres psql -c "ALTER ROLE ${meshdbuser} SET default_transaction_isolation TO 'read committed'"
sudo -u postgres psql -c "ALTER ROLE ${meshdbuser} SET timezone TO 'UTC'"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE meshcentral TO ${meshdbuser}"

print_green 'Export meshcentral database'
cd /meshcentral
node node_modules/meshcentral --dbexport

# Database cannot be specified
# https://github.com/Ylianst/MeshCentral/issues/3398
MESH_PG_DB=""
MESH_PG_USER="$meshdbuser"
MESH_PG_PW="$meshdbpw"
MESH_PG_PORT="5432"
MESH_PG_HOST="localhost"

cat /meshcentral/meshcentral-data/config.json |
    jq " del(.settings.MongoDb, .settings.MongoDbName) " |
    jq " .settings.postgres.user |= \"${MESH_PG_USER}\" " |
    jq " .settings.postgres.password |= \"${MESH_PG_PW}\" " |
    jq " .settings.postgres.port |= \"${MESH_PG_PORT}\" " |
    jq " .settings.postgres.host |= \"${MESH_PG_HOST}\" " > /meshcentral/meshcentral-data/config-postgres.json

# Backup Meshcentral config for MongoDB
print_green 'Backing up meshcentral config'
cp /meshcentral/meshcentral-data/config.json /meshcentral/meshcentral-data/config-mongodb-$(date "+%Y%m%dT%H%M%S").json
cp /meshcentral/meshcentral-data/config-postgres.json /meshcentral/meshcentral-data/config.json

print_green 'Restart meshcentral'
sudo systemctl restart meshcentral
print_green 'Import Database from meshcentral'
node node_modules/meshcentral --dbimport
print_green 'Final restart of meshcentral'
sudo systemctl restart meshcentral

print_green 'Shutting down MongoDB'
sudo systemctl stop mongod.service
print_green 'Disabling MongoDB'
sudo systemctl disable mongod.service

