# Validate DCR request with Pre-Processing Procedure

[![Quality](https://img.shields.io/badge/quality-experiment-red)](https://curity.io/resources/code-examples/status/)
[![Availability](https://img.shields.io/badge/availability-source-blue)](https://curity.io/resources/code-examples/status/)

This repository contains an example based on the Open Banking Brazil profile that demonstrates how to use a Pre-Processing Procedure to validate a DCR request.

# Open Banking Brazil
The Open Banking Brazil (aka Open Banking Brasil or OBB) ecosystem provides a central repository, the "directory" for accredited and trusted clients as well as authorization servers. Registered clients can then retrieve a signed software statement from the directory, aka the software statement assertion (SSA), a signed JWT. The client includes this token in the Dynamic Client Registration request and authenticates using mutual TLS. The Authorization Server is obliged to verify the software statement assertion according to the specification. The Curity Identity Server version 6.5 and later support Pre-Processing Procedures for DCR endpoints that can be used to validate and manipulate incoming DCR requests.

Please refer to the profile documentation for the details:
* [Open Banking Brasil Security Profile](https://github.com/OpenBanking-Brasil/specs-seguranca/blob/main/open-banking-brasil-financial-api-1_ID3.md)
* [Open Banking Brasil Dynamic Client Registration Profile](https://github.com/OpenBanking-Brasil/specs-seguranca/blob/main/open-banking-brasil-dynamic-client-registration-1_ID1.md)

# Mocked Infrastructure
To make this repository self contained the deployment makes use of a mocked infrastructure that simulates the Open Banking Brazil trust management. In particular the public key infrastructure (PKI) created as part of the deployment contains the following certificate authorities, each with its own scope:

* CA that issues server certificates: `trusted-ca`
* CA that issues client certificates: `accredited-ca`
* CA that issues software statements: `ssa-ca`

However, certificates and keys used in the Open Banking Brazil Sandbox environment are also included. As a result, the scripts provided in this repository can be adapted to work for integration testing the DCR flow in the sandbox environment.

# Requirements
## General
This deployment will only work for Curity Identity Server version 6.5 and higher

**TODO: update Dockerfile!**

## License
Aquire a license that includes support for FAPI features and copy the license file to `config/license.json`.

## Certificates
### Server side
* Server certificate and related key for the runtime service of the Curity Identity Server: `example.tls.p12`
* Trusted issuer of client certificates: `accredited-ca.issuer.cer`
* Signature verification key/certificate for the entity signing software statement assertions: `ssa-ca.issuer.cer`

### Client side
* Client certificate and related key for testing: `example.client.p12`
* Trustchain to validate server certificate during testing: `trusted-ca.trustchain.pem`
* Private and public key for signing a software statement: `ssa-ca.issuer.key` and `ssa-ca.issuer.pub`

# Deployment
1. Create the required certificates: `./1-create-certs.sh`
1. Configure and run the server with the certificates, TLS and trust settings: `./2-deploy.sh`

# Testing
The client must provide a software statement during the Dynamic Client Registration process. So, first create a software statement signed by one of the CAs created during deployment.

## Software Statement Creation
1. Navigate to [oauth.tools](https://oauth.tools/)
1. Start a new flow called `Create JWT`.
1. Select `PS256` from the dropdown in the Signature area.
1. Copy the public key from `certs/ssa-ca.issuer.pub` into the field for the Public Key.
1. Copy the private key from `certs/ssa-ca.issuer.key` into the field for the Private Key.
1. Prepare the content of the software statement: `./3-prepare-software-statement-data.sh`
1. Copy the content of the file `software-statement/software-statement.json` into the field for the Body.
1. Save the Body.
1. Click on `Generate JWT`.
1. Copy the resulted JWT (there's a `Copy to Clipboard` button in the upper right corner of the box).
1. Open `dcr-request.json`.
1. Replace the string "*Place JWT here*" with the JWT from the clipboard.

## Dynamic Client Registration
Run `4-register-DCR-client.sh` to register a client using the client certificate for MTLS and the software statement created before.


## More Information
Please visit [curity.io](https://curity.io/) for more information about the Curity Identity Server.
