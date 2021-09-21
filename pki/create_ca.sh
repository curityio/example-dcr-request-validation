

function create_ca() {
  local CA_NAME=${1:?Missing a name for CA.}
  local ROOT_CERT_NAME=${2:-"$CA_NAME Root CA"}
  local INTERMEDIATE_CERT_NAME=${3:-"$CA_NAME Issuing CA"}

  mkdir $CA_NAME
  #cp openssl.cnf openssl-intermediate.cnf $CA_NAME
  cd $CA_NAME

  #
  # Create a root certificate authority
  #
  mkdir -p root/{certs,crl,newcerts,private}
  chmod 700 root/private
  touch root/index.txt
  echo 0001 > root/serial
  echo 0100 > root/crlnumber

  openssl genrsa -passout pass:password -aes256 -out root/private/root.ca.key 2048
  # Remove password
  openssl rsa -in root/private/root.ca.key -passin pass:password -out root/private/root.ca.key
  chmod 400 root/private/root.ca.key
  echo "*** Successfully created Root CA key $CA_NAME."

  openssl req \
      -x509 \
      -new \
      -config ../openssl.cnf \
      -key root/private/root.ca.key \
      -out root/certs/root.ca.cer \
      -subj "/CN=$ROOT_CERT_NAME" \
      -extensions v3_ca \
      -sha256 \
      -days 3650
  chmod 444 root/certs/root.ca.cer
  echo "*** Successfully created Root CA for $CA_NAME."

  #
  # Create an issuing certificate authority
  #
  mkdir -p intermediate/{certs,crl,newcerts,private,csr}
  chmod 700 intermediate/private
  touch intermediate/index.txt
  echo 0001 > intermediate/serial
  echo 0100 > intermediate/crlnumber

  openssl genrsa -passout pass:password -aes256 -out intermediate/private/intermediate.ca.key 2048
  # Remove password
  openssl rsa -in intermediate/private/intermediate.ca.key -passin pass:password -out intermediate/private/intermediate.ca.key
  chmod 400 intermediate/private/intermediate.ca.key

  openssl req \
      -new \
      -config ../openssl-intermediate.cnf \
      -key intermediate/private/intermediate.ca.key \
      -out intermediate/csr/intermediate.ca.csr \
      -subj "/CN=$INTERMEDIATE_CERT_NAME" \
      -sha256
  echo "*** Created request for Issuing CA for $CA_NAME"

  openssl ca \
        -batch \
        -config ../openssl.cnf \
        -extensions v3_intermediate_ca \
        -days 3650 \
        -notext \
        -md sha256 \
        -in intermediate/csr/intermediate.ca.csr \
        -out intermediate/certs/intermediate.ca.cer

  chmod 444 intermediate/certs/intermediate.ca.cer
  echo "*** Successfully created Issuing CA for $CA_NAME."

  cat root/certs/root.ca.cer intermediate/certs/intermediate.ca.cer > ../$CA_NAME.trustchain.pem

  cd ..
}

create_ca $1 $2 $3
