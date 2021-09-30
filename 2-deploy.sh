#!/bin/bash

##########################################################################
# A script to deploy the Authorization Server.
# The Authorization Server is configured to support mutual TLS.
# The configuration includes a pre-processing procedure for validation of
# the software statement in the DCR request according to the requirements
# of Open Banking Brazil.
# https://github.com/OpenBanking-Brasil/specs-seguranca/blob/main/open-banking-brasil-dynamic-client-registration-1_ID1.md.
#
# Note for developing purpose the deployment created by this script uses its
# own PKI and certificates to simulate the trusted infrastructure that the
# OBB profile is built upon. Create the certificates by running ./1-create-certs.sh
# Certificates for the sandbox environment are included. With a few changes
# in the deployment the resulting system can be used for integration testing
# DCR requests of clients that are part of the sandbox environment.
##########################################################################

echo "*** Preparing environment"

SERVICE_NAME="test-obb"

# Used for TLS settings of the runtime
SSL_KEY_ID="example.tls"
SSL_KEY_PASSWORD="Password1"
SSL_KEYSTORE_FILE="certs/example.tls.p12"

# Public key of the SSA issuer for the OBB sandbox environment
# Only certificates can be loaded from etc/init and thus this key will be added via CLI with the given id
SSA_OFFICIAL_ISSUER_ID="obb-ssa-issuing-sandbox"
SSA_OFFICIAL_ISSUER_FILE="certs/signature-verification/obb-ssa-issuing-sandbox.pem"

# Id of signature verification key used in the pre-processing procedure to validate the software statement assertion (SSA)
# Id matches the ceritifcate file name (without file ending) in etc/init/crypto/signature-verification
SSA_ISSUER_ID="ssa-ca.issuer"

# Id of trusted issuer of client certificates for mtls
# Id matches the ceritifcate file name (without file ending) in etc/init/crypto/ssl-client-truststore
MTLS_CLIENT_TRUSTSTORE_ID="accredited-ca.issuer"

# For testing with the OBB sandbox environment use the following settings instead
#SSA_ISSUER_ID="obb-ssa-issuing-sandbox"
#MTLS_CLIENT_TRUSTSTORE_ID="obb-issuing-sandbox-g1"

# Get local directory
D=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

#
# Check that a license file for the Curity Identity Server has been provided
#
if [ ! -f "$D/config/license.json" ]; then
  echo "Please provide a license.json file in the $D/config folder in order to deploy the system."
  exit 1
fi

#
# Check that a server SSL certificate for the Curity Identity Server has been provided
#
if [ ! -f "$D/certs/example.tls.p12" ]; then
  echo "Please create certificates before deploying the system."
  exit 1
fi

# Update Pre-Processing-Procedure with correct ssa issuer id
export SSA_ISSUER_ID
envsubst < "$D"/templates/open-banking-brazil-dcr-validation-template.js > "$D"/pre-processing-procedures/open-banking-brazil-dcr-validation.js

# Building Docker image for testing DCR validation for Open Banking Brazil
# Copy license, certificates and pre-processing procedure to the etc/init folder
docker build --tag idsvr:dcr-validation --file "$D"/docker/Dockerfile "$D"

if [ $? -ne 0 ]; then
  echo "Problem encountered building Docker image."
  exit 1
fi

echo "*** Starting Identity Server in Docker container"
echo "Using client truststore with id $MTLS_CLIENT_TRUSTSTORE_ID"

# Run the Identity Server and enable mtls
docker run --rm --detach --publish 6749:6749 --publish 8443:8443 \
--env PASSWORD=Password1 \
--env MTLS_CLIENT_TRUSTSTORE_ID="$MTLS_CLIENT_TRUSTSTORE_ID" \
--env SERVICE_NAME="$SERVICE_NAME" \
--name idsvr-dcr-validation idsvr:dcr-validation

#
# Wait for the idsh to become available
#
echo "Waiting for the Curity Identity Server to start ..."

STATUS=$(docker inspect --format='{{ .State.Running}}' idsvr-dcr-validation)

while [ -n "$(docker exec idsvr-dcr-validation idsh 2>&1)" -a "$STATUS" == "true" ]; do
  sleep 2s
  STATUS=$(docker inspect --format='{{ .State.Running}}' idsvr-dcr-validation)
done

if [ "$STATUS" != "true" ]; then
  echo "Error while starting Identity Server: $STATUS"
  docker container rm -f idsvr-dcr-validation
  exit 1
fi

## Seems like idsh can connect before actions actually work. Wait a bit longer...
sleep 5s

echo "Updating the server certificate ..."
echo "Using server ssl keystore with id $SSL_KEY_ID"

# Preparing the SSL keystore for the runtime
SSL_KEYSTORE_B64=$(openssl base64 -e -A -in "$D"/"$SSL_KEYSTORE_FILE")

if [ $? -ne 0 ]; then
  echo "Problem encountered when loading TLS keystore. Using default instead."
else
  # Upload and activate SSL key with CLI; commit changes
  docker exec -i idsvr-dcr-validation idsh << EOF
configure
request facilities crypto add-ssl-server-keystore id "$SSL_KEY_ID" keystore "$SSL_KEYSTORE_B64" password "$SSL_KEY_PASSWORD"
set environments environment services service-role default ssl-server-keystore "$SSL_KEY_ID"
commit comment "Changed SSL keystore to $SSL_KEY_ID"
exit no-confirm
exit
EOF
fi

echo "Adding the official signature verification key ..."
SSA_OFFICIAL_ISSUER_B64=$(openssl base64 -e -A -in "$D"/"$SSA_OFFICIAL_ISSUER_FILE")

if [ $? -ne 0 ]; then
  echo "Problem encountered when loading signature verification key. Deployment failed."
  docker container rm -f idsvr-dcr-validation
  exit 1
fi
# Upload signature verification key with CLI
docker exec -i idsvr-dcr-validation idsh << EOF
configure
request facilities crypto add-signature-verification-key id "$SSA_OFFICIAL_ISSUER_ID" keystore "$SSA_OFFICIAL_ISSUER_B64"
exit no-confirm
exit
EOF
