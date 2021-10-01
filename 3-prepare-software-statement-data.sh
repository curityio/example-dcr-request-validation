#!/bin/bash
# Get local directory
D=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

cp "$D"/templates/dcr-request-template.json "$D"/dcr-request.json

export ISSUED_AT=$(date +%s)
mkdir -p "$D"/software-statement
envsubst < "$D"/templates/software-statement-template.json > "$D"/software-statement/software-statement.json
