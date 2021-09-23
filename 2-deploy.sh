#!/bin/bash

##########################################################################
# A script to deploy the Authorization Server.
# The Authorization Server is configured to support mutual TLS.
# The configuration includes a preprocessing procedure for validation of
# the software statement in the DCR request according to the requirements
# of Open Banking Brasil.
# https://github.com/OpenBanking-Brasil/specs-seguranca/blob/main/open-banking-brasil-dynamic-client-registration-1_ID1.md.
##########################################################################

docker build --tag idsvr:openbankingbrasil --file docker/Dockerfile .

if [ $? -ne 0 ]; then
  echo "Problem encountered building Docker image."
  exit 1
fi

echo "Setting environment variables:"

OBB_CLIENT_TRUSTSTORE_ID="mocked-icp-ca.trustchain"
echo "OBB_CLIENT_TRUSTSTORE_ID=$OBB_CLIENT_TRUSTSTORE_ID"

OBB_SANDBOX_G1=$(cat certs/obb-issuing-sandbox-g1.cer)
echo "OBB_SANDBOX_G1=$OBB_SANDBOX_G1"

echo "Starting Identity Server in Docker container"

docker run --rm --publish 6749:6749 --publish 8443:8443 \
--env PASSWORD=Password1 \
--env OBB_CLIENT_TRUSTSTORE_ID="$OBB_CLIENT_TRUSTSTORE_ID" \
--env OBB_SANDBOX_G1="$OBB_SANDBOX_G1" \
--name idsvr-obb idsvr:openbankingbrasil

if [ $? -ne 0 ]; then
  echo "Problem encountered running Identity Server in Docker container."
  exit 1
fi

echo "Started container with $?"
