# Get local directory
D=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

curl --cert "$D"/certs/example.client.p12:Password1 --cert-type P12 \
--cacert "$D"/certs/trusted-ca.trustchain.pem \
https://localhost:8443/oauth/v2/oauth-dynamic-client-registration \
-d @"$D"/dcr-request.json -v
