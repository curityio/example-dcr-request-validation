# example-dcr-request-validation
An example based on the Open Banking Brasil profile that demonstrates how to use a pre-processing procedure to validate a DCR request.

1.) Create PKI and required certificates
2.) Deploy
3.) Register a client via DCR
  a) Get a software statement assertion
  b) Update obb-dcr-request.json with the value of the jwt/ssa
  b) Run curl command

  TODO: Update DN of client certificate to match OBB certificate profile

Getting a software statement
  * navigate to oauth.tools
  * start a new flow called "Create JWT"
  * copy decoded software statement in the body
  * select PS256 from the drop down for the signature
  * copy ssa-issuer.pub in the field for the public key
  * copy ssa-issuer.key in the field for the private key
  * Generate jwt and copy result
