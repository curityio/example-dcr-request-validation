#!/bin/bash

export ISSUED_AT=$(date +%s)
envsubst < software-statement/software-statement-template.txt > software-statement/software-statement.txt
