FROM curity.azurecr.io/curity/idsvr:latest

COPY certs/signature-verification/*.cer etc/init/crypto/signature-verification/
COPY certs/ssl-client-truststore/ etc/init/crypto/ssl-client-truststore
COPY certs/example.tls.p12 etc/init/crypt/ssl-server-keystore/

COPY pre-processing-procedures/open-banking-brazil-dcr-validation.js etc/init/pre-processing-procedures/

COPY config/license.json etc/init/license/
COPY config/curity-config-obb-fapi.xml etc/init/
