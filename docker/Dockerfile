#FROM curity.azurecr.io/curity/idsvr:latest
FROM curity/idsvr-unstable:6.4.0-c3b2992bf7

COPY certs/signature-verification/ etc/init/crypto/signature-verification
COPY certs/ssl-client-truststore/ etc/init/crypto/ssl-client-truststore
COPY pre-processing-procedures/ etc/init/pre-processing-procedures

COPY config/license.json etc/init/license/
COPY config/curity-config-obb-fapi.xml etc/init/
