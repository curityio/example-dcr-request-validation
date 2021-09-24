curl --cert certs/example.client.p12:Password1 --cert-type P12 --cacert certs/trusted-ca.trustchain.pem https://localhost:8443/oauth/v2/oauth-dynamic-client-registration -d @dcr-request.json -v -k
