#!/bin/bash
# Get local directory
D=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

export ISSUED_AT=$(date +%s)
envsubst < "$D"/software-statement/software-statement-template.json > "$D"/software-statement/software-statement.txt
