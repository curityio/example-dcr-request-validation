

function create_ca() {
  local CA_NAME=${1:?Missing a name for CA.}
  local ROOT_CERT_NAME=${2:-"$CA_NAME Root CA"}
  local INTERMEDIATE_CERT_NAME=${3:-"$CA_NAME Issuing CA"}

  # Get local directory
  export D=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
  mkdir $D/$CA_NAME
  cd $D/$CA_NAME

  #
  # Create a root certificate authority
  #
  mkdir -p "$D"/"$CA_NAME"/root/{certs,crl,newcerts,private}
  chmod 700 "$D"/"$CA_NAME"/root/private
  touch "$D"/"$CA_NAME"/root/index.txt
  echo 0001 > "$D"/"$CA_NAME"/root/serial
  echo 0100 > "$D"/"$CA_NAME"/root/crlnumber

  openssl genrsa -passout pass:password -aes256 -out "$D"/"$CA_NAME"/root/private/root.ca.key 2048
  # Remove password
  openssl rsa -in "$D"/"$CA_NAME"/root/private/root.ca.key -passin pass:password -out "$D"/"$CA_NAME"/root/private/root.ca.key
  chmod 400 "$D"/"$CA_NAME"/root/private/root.ca.key
  echo "*** Successfully created Root CA key $CA_NAME."

  openssl req \
      -x509 \
      -new \
      -config "$D"/openssl.cnf \
      -key "$D"/"$CA_NAME"/root/private/root.ca.key \
      -out "$D"/"$CA_NAME"/root/certs/root.ca.cer \
      -subj "/CN=$ROOT_CERT_NAME" \
      -extensions v3_ca \
      -sha256 \
      -days 3650
  chmod 444 "$D"/"$CA_NAME"/root/certs/root.ca.cer
  echo "*** Successfully created Root CA for $CA_NAME."

  #
  # Create an issuing certificate authority
  #
  mkdir -p "$D"/"$CA_NAME"/intermediate/{certs,crl,newcerts,private,csr}
  chmod 700 "$D"/"$CA_NAME"/intermediate/private
  touch "$D"/"$CA_NAME"/intermediate/index.txt
  echo 0001 > "$D"/"$CA_NAME"/intermediate/serial
  echo 0100 > "$D"/"$CA_NAME"/intermediate/crlnumber

  openssl genrsa -passout pass:password -aes256 -out "$D"/"$CA_NAME"/intermediate/private/intermediate.ca.key 2048
  # Remove password
  openssl rsa -in "$D"/"$CA_NAME"/intermediate/private/intermediate.ca.key -passin pass:password -out "$D"/"$CA_NAME"/intermediate/private/intermediate.ca.key
  chmod 400 "$D"/"$CA_NAME"/intermediate/private/intermediate.ca.key

  openssl req \
      -new \
      -config "$D"/openssl-intermediate.cnf \
      -key "$D"/"$CA_NAME"/intermediate/private/intermediate.ca.key \
      -out "$D"/"$CA_NAME"/intermediate/csr/intermediate.ca.csr \
      -subj "/CN=$INTERMEDIATE_CERT_NAME" \
      -sha256
  echo "*** Created request for Issuing CA for $CA_NAME"

  openssl ca \
        -batch \
        -config "$D"/openssl.cnf \
        -extensions v3_intermediate_ca \
        -days 3650 \
        -notext \
        -md sha256 \
        -in "$D"/"$CA_NAME"/intermediate/csr/intermediate.ca.csr \
        -out "$D"/"$CA_NAME"/intermediate/certs/intermediate.ca.cer

  chmod 444 "$D"/"$CA_NAME"/intermediate/certs/intermediate.ca.cer
  echo "*** Successfully created Issuing CA for $CA_NAME."

  cat "$D"/"$CA_NAME"/root/certs/root.ca.cer "$D"/"$CA_NAME"/intermediate/certs/intermediate.ca.cer > "$D"/$CA_NAME.trustchain.pem
}

create_ca "$1" "$2" "$3"
