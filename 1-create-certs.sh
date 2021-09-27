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
TLS_CERT_NAME='CN=*.example.com'

ACCREDITED_ROOT_CERT_NAME='Root CA for Client Certificates'
ACCREDITED_INTERMEDIATE_CERT_NAME='Issuing CA for Client Certificates'

CLIENT_CERT_NAME="example.client"
CLIENT_CERT_FILE_PREFIX='example.client'
CLIENT_CERT_PASSWORD='Password1'

SSL_CA_NAME='trusted-ca'
ACCREDITED_CA_NAME='accredited-ca'
SSA_CA_NAME='ssa-ca'

# Get local directory
D=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

#
# Create a root certificate authority for server certificates
#
"$D"/pki/create_ca.sh "$SSL_CA_NAME" "$SSL_ROOT_CERT_NAME" "$SSL_INTERMEDIATE_CERT_NAME"
"$D"/pki/create_ca.sh "$ACCREDITED_CA_NAME" "$ACCREDITED_ROOT_CERT_NAME" "$ACCREDITED_INTERMEDIATE_CERT_NAME"
"$D"/pki/create_ca.sh "$SSA_CA_NAME" "Root CA for Open Banking Brazil" "Software Statement Assertion Issuer"

#
# Create the SSL certificate that back end components will use
#
cd "$D"/pki/"$SSL_CA_NAME"
openssl genrsa -aes256 -passout pass:$TLS_CERT_PASSWORD -out "$D"/pki/"$SSL_CA_NAME"/intermediate/private/"$TLS_CERT_FILE_PREFIX".key 2048
chmod 400 "$D"/pki/"$SSL_CA_NAME"/intermediate/private/"$TLS_CERT_FILE_PREFIX".key
echo '*** Successfully created TLS key.'

openssl req \
    -new \
    -config "$D"/pki/openssl.cnf \
    -extensions server_cert \
    -passin pass:$TLS_CERT_PASSWORD \
    -key "$D"/pki/"$SSL_CA_NAME"/intermediate/private/"$TLS_CERT_FILE_PREFIX".key \
    -out "$D"/pki/"$SSL_CA_NAME"/intermediate/csr/"$TLS_CERT_FILE_PREFIX".csr \
    -subj "/${TLS_CERT_NAME//,//}"
echo '*** Successfully created TLS server certificate signing request.'

openssl ca -config "$D"/pki/openssl-intermediate.cnf \
      -batch \
      -extensions server_cert \
      -days 365 \
      -notext \
      -md sha256 \
      -in "$D"/pki/"$SSL_CA_NAME"/intermediate/csr/"$TLS_CERT_FILE_PREFIX".csr \
      -out "$D"/pki/"$SSL_CA_NAME"/intermediate/certs/"$TLS_CERT_FILE_PREFIX".cer

echo '*** Successfully created TLS server certificate.'

openssl pkcs12 \
    -export -inkey "$D"/pki/"$SSL_CA_NAME"/intermediate/private/"$TLS_CERT_FILE_PREFIX".key \
    -in "$D"/pki/"$SSL_CA_NAME"/intermediate/certs/"$TLS_CERT_FILE_PREFIX".cer \
    -passin pass:$TLS_CERT_PASSWORD \
    -name $TLS_CERT_NAME \
    -out "$D"/pki/"$SSL_CA_NAME"/intermediate/private/"$TLS_CERT_FILE_PREFIX".p12 \
    -passout pass:$TLS_CERT_PASSWORD
echo '*** Successfully exported TLS certificate to a PKCS#12 file.'

#
# Create the client certificate that the example TPP will use
#
cd "$D"/pki/"$ACCREDITED_CA_NAME"

openssl genrsa -aes256 -passout pass:$CLIENT_CERT_PASSWORD -out "$D"/pki/"$ACCREDITED_CA_NAME"/intermediate/private/"$CLIENT_CERT_FILE_PREFIX".key 2048
echo '*** Successfully created client key'

openssl req \
    -config "$D"/pki/openssl-client.cnf \
    -new \
    -passin pass:$CLIENT_CERT_PASSWORD \
    -key "$D"/pki/"$ACCREDITED_CA_NAME"/intermediate/private/"$CLIENT_CERT_FILE_PREFIX".key \
    -out "$D"/pki/"$ACCREDITED_CA_NAME"/intermediate/csr/"$CLIENT_CERT_FILE_PREFIX".csr
echo '*** Successfully created client certificate signing request'

openssl ca -config "$D"/pki/openssl-intermediate.cnf \
      -batch \
      -extensions obb_cert \
      -days 365 \
      -notext \
      -md sha256 \
      -in "$D"/pki/"$ACCREDITED_CA_NAME"/intermediate/csr/"$CLIENT_CERT_FILE_PREFIX".csr \
      -out "$D"/pki/"$ACCREDITED_CA_NAME"/intermediate/certs/"$CLIENT_CERT_FILE_PREFIX".cer
echo '*** Successfully created client certificate'

openssl pkcs12 \
    -export \
    -inkey "$D"/pki/"$ACCREDITED_CA_NAME"/intermediate/private/"$CLIENT_CERT_FILE_PREFIX".key \
    -in "$D"/pki/"$ACCREDITED_CA_NAME"/intermediate/certs/"$CLIENT_CERT_FILE_PREFIX".cer \
    -passin pass:$CLIENT_CERT_PASSWORD \
    -name $CLIENT_CERT_NAME \
    -out "$D"/pki/"$ACCREDITED_CA_NAME"/intermediate/private/"$CLIENT_CERT_FILE_PREFIX".p12 \
    -passout pass:$CLIENT_CERT_PASSWORD
echo '*** Successfully exported client certificate to a PKCS#12 file'

# Copy trustchains of all created CAs to certs folder
mv "$D"/pki/*.trustchain.pem "$D"/certs

# Copy server certificate and keystore to certs
mv "$D"/pki/"$SSL_CA_NAME"/intermediate/private/"$TLS_CERT_FILE_PREFIX.p12" "$D"/certs
cp "$D"/pki/"$SSL_CA_NAME"/intermediate/certs/"$TLS_CERT_FILE_PREFIX.cer" "$D"/certs

# Copy client certificate and keystore to
mv "$D"/pki/"$ACCREDITED_CA_NAME"/intermediate/private/"$CLIENT_CERT_FILE_PREFIX".p12 "$D"/certs
cp "$D"/pki/"$ACCREDITED_CA_NAME"/intermediate/certs/"$CLIENT_CERT_FILE_PREFIX".cer "$D"/certs

## Copy trusted issuers and signature verification keys
cp "$D"/pki/"$ACCREDITED_CA_NAME"/intermediate/certs/intermediate.ca.cer "$D"/certs/ssl-client-truststore/"$ACCREDITED_CA_NAME".issuer.cer
cp "$D"/pki/"$SSA_CA_NAME"/intermediate/certs/intermediate.ca.cer "$D"/certs/signature-verification/"$SSA_CA_NAME".issuer.cer

## Required for signing the software statement
cp "$D"/pki/"$SSA_CA_NAME"/intermediate/private/intermediate.ca.key "$D"/certs/"$SSA_CA_NAME".issuer.key
openssl rsa -in "$D"/certs/"$SSA_CA_NAME".issuer.key -pubout -out "$D"/certs/"$SSA_CA_NAME".issuer.pub

echo '*** Successfully moved generated certificates and keys to certs folder.'
