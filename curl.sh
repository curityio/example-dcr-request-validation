curl --cert certs/example-client.p12 --cert-type pkcs12 --cacert certs/trusted-ca.trustcain.pem https://localhost:8443/oauth/v2/oauth-dynamic-client-registration -d @dcr-request.json -v
