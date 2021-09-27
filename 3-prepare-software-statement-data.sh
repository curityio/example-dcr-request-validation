#!/bin/bash

export ISSUED_AT=$(date +%s)
envsubst < software-statement/software-statement-template.json > software-statement/software-statement.txt
