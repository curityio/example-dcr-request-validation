#!/bin/bash

####################################################################
# A script to create development certificates for Mutual TLS testing
####################################################################

set -e

#
# Certificate parameters
#
SSL_ROOT_CERT_NAME='Root CA for TLS Testing'
SSL_INTERMEDIATE_CERT_NAME='Issuing CA for TLS Testing'

TLS_CERT_FILE_PREFIX='example.tls'
TLS_CERT_PASSWORD='Password1'
TLS_CERT_NAME='*.example.com'

ACCREDITED_ROOT_CERT_NAME='Root CA for Client Certificates'
ACCREDITED_INTERMEDIATE_CERT_NAME='Issuing CA for Client Certificates'

CLIENT_CERT_NAME='demo-merchant'
CLIENT_CERT_FILE_PREFIX='example.client'
CLIENT_CERT_PASSWORD='Password1'

SSL_CA_NAME='trusted-ca'
ACCREDITED_CA_NAME='mocked-icp-ca'
SSA_CA_NAME='ssa-ca'

cd pki

#
# Create a root certificate authority for server certificates
#
./create_ca.sh "$SSL_CA_NAME" "$SSL_ROOT_CERT_NAME" "$SSL_INTERMEDIATE_CERT_NAME"
./create_ca.sh "$ACCREDITED_CA_NAME" "$ACCREDITED_ROOT_CERT_NAME" "$ACCREDITED_INTERMEDIATE_CERT_NAME"
./create_ca.sh "$SSA_CA_NAME" "Root CA for Open Banking Brasil" "Software Statement Assertion Issuer"

#
# Create the SSL certificate that back end components will use
#
cd $SSL_CA_NAME

openssl genrsa -aes256 -passout pass:$TLS_CERT_PASSWORD -out intermediate/private/$TLS_CERT_FILE_PREFIX.key 2048
chmod 400 intermediate/private/$TLS_CERT_FILE_PREFIX.key
echo '*** Successfully created TLS key.'

openssl req \
    -new \
    -config ../openssl.cnf \
    -extensions server_cert \
    -passin pass:$TLS_CERT_PASSWORD \
    -key intermediate/private/$TLS_CERT_FILE_PREFIX.key \
    -out intermediate/csr/$TLS_CERT_FILE_PREFIX.csr \
    -subj "/CN=$TLS_CERT_NAME"
echo '*** Successfully created TLS server certificate signing request.'

openssl ca -config ../openssl-intermediate.cnf \
      -batch \
      -extensions server_cert \
      -days 365 \
      -notext \
      -md sha256 \
      -in intermediate/csr/$TLS_CERT_FILE_PREFIX.csr \
      -out intermediate/certs/$TLS_CERT_FILE_PREFIX.cer

echo '*** Successfully created TLS server certificate.'

openssl pkcs12 \
    -export -inkey intermediate/private/$TLS_CERT_FILE_PREFIX.key \
    -in intermediate/certs/$TLS_CERT_FILE_PREFIX.cer \
    -passin pass:$TLS_CERT_PASSWORD \
    -name $TLS_CERT_NAME \
    -out intermediate/private/$TLS_CERT_FILE_PREFIX.p12 \
    -passout pass:$TLS_CERT_PASSWORD
echo '*** Successfully exported TLS certificate to a PKCS#12 file.'

cd .. # exit SSL_CA_NAME

#
# Create the client certificate that the example merchant will use
#
cd $ACCREDITED_CA_NAME

openssl genrsa -aes256 -passout pass:$CLIENT_CERT_PASSWORD -out intermediate/private/$CLIENT_CERT_FILE_PREFIX.key 2048
echo '*** Successfully created client key'

openssl req \
    -config ../openssl-intermediate.cnf \
    -new \
    -passin pass:$CLIENT_CERT_PASSWORD \
    -key intermediate/private/$CLIENT_CERT_FILE_PREFIX.key \
    -out intermediate/csr/$CLIENT_CERT_FILE_PREFIX.csr \
    -subj "/CN=$CLIENT_CERT_NAME"
echo '*** Successfully created client certificate signing request'

openssl ca -config ../openssl-intermediate.cnf \
      -batch \
      -extensions obb_cert \
      -days 365 \
      -notext \
      -md sha256 \
      -in intermediate/csr/$CLIENT_CERT_FILE_PREFIX.csr \
      -out intermediate/certs/$CLIENT_CERT_FILE_PREFIX.cer
echo '*** Successfully created client certificate'

openssl pkcs12 \
    -export \
    -inkey intermediate/private/$CLIENT_CERT_FILE_PREFIX.key \
    -in intermediate/certs/$CLIENT_CERT_FILE_PREFIX.cer \
    -passin pass:$CLIENT_CERT_PASSWORD \
    -name $CLIENT_CERT_NAME \
    -out intermediate/private/$CLIENT_CERT_FILE_PREFIX.p12 \
    -passout pass:$CLIENT_CERT_PASSWORD
echo '*** Successfully exported client certificate to a PKCS#12 file'

cd .. # exit ACCREDITED_CA_NAME

cd .. # exit pki

# Copy trustchains of all created CAs to certs folder
mv pki/*.trustchain.pem certs

# Copy server certificate and keystore to certs
mv pki/"$SSL_CA_NAME"/intermediate/private/"$TLS_CERT_FILE_PREFIX".p12 certs
cp pki/"$SSL_CA_NAME"/intermediate/certs/"$TLS_CERT_FILE_PREFIX".cer certs

# Copy client certificate and keystore to
mv pki/"$ACCREDITED_CA_NAME"/intermediate/private/"$CLIENT_CERT_FILE_PREFIX".p12 certs
cp pki/"$ACCREDITED_CA_NAME"/intermediate/certs/"$CLIENT_CERT_FILE_PREFIX".cer certs

##
cp pki/"$ACCREDITED_CA_NAME"/intermediate/certs/intermediate.ca.cer certs/ssl-client-truststore/"$ACCREDITED_CA_NAME".issuer.cer
cp pki/"$SSA_CA_NAME"/intermediate/certs/intermediate.ca.cer certs/signature-verification/"$SSA_CA_NAME".issuer.cer

echo '*** Successfully moved generated certificates and keys to certs folder.'
