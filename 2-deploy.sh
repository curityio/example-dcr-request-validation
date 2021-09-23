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

echo "*** Preparing environment"

SERVICE_NAME="test-obb"
OBB_CLIENT_TRUSTSTORE_ID="mocked-icp-ca.trustchain"

SSL_KEY_ID="example.tls"
SSL_KEY_PASSWORD="Password1"

SSL_KEYSTORE_FILE="certs/example.tls.p12"

SSL_KEYSTORE_B64=$(openssl base64 -e -A -in $SSL_KEYSTORE_FILE)
#SSL_KEYSTORE_B64=$(openssl pkcs12 -export -passin pass:$SSL_KEY_PASSWORD -passout pass:default < certs/example.tls.combined.pem | openssl base64 -e -A)


if [ $? -ne 0 ]; then
  echo "Problem encountered when loading TLS keystore."
  exit 1
fi

echo "Using client truststore with id $OBB_CLIENT_TRUSTSTORE_ID"
echo "Using server ssl keystore with id $SSL_KEY_ID"

echo "*** Starting Identity Server in Docker container"

docker run --rm --detach --publish 6749:6749 --publish 8443:8443 \
--env PASSWORD=Password1 \
--env OBB_CLIENT_TRUSTSTORE_ID="$OBB_CLIENT_TRUSTSTORE_ID" \
--env SERVICE_NAME="$SERVICE_NAME" \
--name idsvr-obb idsvr:openbankingbrasil

#
# Wait for the admin endpoint to become available
#
echo "Waiting for the Curity Identity Server ..."

while [ ! -z "$(docker exec idsvr-obb idsh 2>&1)" ]; do
  sleep 2s
done

## Seems like idsh can connect before actions actually work. Wait a bit longer...
sleep 5s

echo "Updating the server certificate ..."

docker exec -i idsvr-obb idsh << EOF
configure
request facilities crypto add-ssl-server-keystore id "$SSL_KEY_ID" keystore "$SSL_KEYSTORE_B64" password "$SSL_KEY_PASSWORD"
set environments environment services service-role default ssl-server-keystore "$SSL_KEY_ID"
commit comment "Changed SSL keystore to test-key"
exit no-confirm
exit
EOF

echo "Updating the signature verification keys ..."
SSA_ISSUER_B64=$(openssl base64 -e -A -in certs/signature-verification/obb-ssa-issuing-sandbox.pem)

docker exec -i idsvr-obb idsh << EOF
configure
request facilities crypto add-signature-verification-key id obb-ssa-issuer keystore "$SSA_ISSUER_B64"
exit no-confirm
exit
EOF
