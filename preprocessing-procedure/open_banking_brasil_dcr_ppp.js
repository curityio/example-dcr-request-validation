/*
 * Copyright (C) 2021 Curity AB. All rights reserved.
 *
 * The contents of this file are the property of Curity AB.
 * You may not copy or use this file, in either source code
 * or executable form, except in compliance with terms
 * set by Curity AB.
 *
 * For further information, please contact Curity AB.
 */

//Note: ES5!
function result(context) {
    var maximumLifetimeInSeconds = 60*5;
    var requiredSignatureAlgorithm = "PS256";

    var registrationData = context.getRegistrationData();
    var redirectUrisRaw = registrationData.redirect_uris;
    var jwks = registrationData.jwks;
    var jwksUri = registrationData.jwks_uri;
    var scope = registrationData.scope;
    var softwareStatement = registrationData.software_statement;

    var isRolePagto = false;
    var isRoleDados = false;
    var isRoleConta = false;
    var isRoleCcorr = false;

    var scopes = scope ? scope.split[' '] : [];

//========================================================
    /*
        shall reject dynamic client registration requests not performed over a connection secured with mutual tls using certificates issued by Brazil ICP (production) or the Directory of Participants (sandbox);
        shall validate that the request contains software_statement JWT signed using the PS256 algorithim issued by the Open Banking Brasil directory of participants;
        shall validate that the software_statement was issued (iat) not more than 5 minutes prior to the request being received;
        shall validate that a jwks (key set by value) was not included;
        shall require and validate that the jwks_uri matches the software_jwks_uri provided in the software statement;
        shall require and validate that redirect_uris match or contain a sub set of software_redirect_uris provided in the software statement;
        shall require and validate that all client authentication mechanism adhere to the requirements defined in Financial-grade API Security Profile 1.0 - Part 1: Advanced;
        shall require encrypted request objects as required by the Brasil Open Banking Security Profile;
        shall validate that requested scopes are appropriate for the softwares authorized regulatory roles;
        should where possible validate client asserted metadata against metadata provided in the software_statement;
        shall accept all x.500 AttributeType name strings defined in the Distinguished Name of the x.509 Certificate Profiles defined in [Open Banking Brasil x.509 Certificate Standards][OBB-Cert-Standards];
        if supporting tls_client_auth client authentication mechanism as defined in [RFC8705] shall only accept tls_client_auth_subject_dn as an indication of the certificate subject value as defined in clause 2.1.2 [RFC8705];
    */
//========================================================


//========================================================
// shall validate that the request contains software_statement JWT signed using the PS256 algorithim issued by the Open Banking Brasil directory of participants;

    if (!softwareStatement) {
        throw exceptionFactory.badRequestException("Missing software_statement in request.");
    }
    /*
        var jwtHeader = base64Decode(softwareStatement.split('.')[0]);
        var ssaMetadata = context.json.fromJson(jwtHeader);

        if (ssaMetadata.alg != requiredSignatureAlgorithm) {
            throw exceptionFactory.badRequestException("Unexpected signature algorithm was found in software statement assertion.");
        }
    */

    // TODO: Discuss when to validate signature as its time consuming
    var ssa = context.validateSignatureAndExtractClaims("obb-production-ssa-issuer", requiredSignatureAlgorithm, softwareStatement);

    if (!ssa || ssa.size() == 0) {
        throw exceptionFactory.badRequestException("Validation of software statement assertion failed.");
    }

//========================================================
// shall validate that the software_statement was issued (iat) not more than 5 minutes prior to the request being received;

    var iat = ssa.iat;

    if (secondsSince(iat) > maximumLifetimeInSeconds) {
        //throw exceptionFactory.badRequestException("The software statement assertion is too old.");
    }

//========================================================
// shall validate that a jwks (key set by value) was not included;

    if (jwks) {
        throw exceptionFactory.badRequestException("Request must not include jwks");
    }

//========================================================
// shall require and validate that the jwks_uri matches the software_jwks_uri provided in the software statement;
    if (!jwksUri) {
        throw exceptionFactory.badRequestException("jwks_uri is missing.");
    }

    if (jwksUri != ssa.software_jwks_uri) {
        throw exceptionFactory.badRequestException("jwks_uri does not match the value provided in the software statement assertion.");
    }

//========================================================
// shall require and validate that redirect_uris match or contain a sub set of software_redirect_uris provided in the software statement;

    var registeredSoftwareRedirectUris = ssa.software_redirect_uris;

    // use for loop because redirectUrisRaw is object/list and not Array
    for (var index in redirectUrisRaw) {
        var redirectUri = redirectUrisRaw[index];

        if (registeredSoftwareRedirectUris.indexOf(redirectUri) == -1) {
            throw exceptionFactory.badRequestException("At least one redirect uri does not match the list of redirect uris provided in the software statement assertion.");
        }
    }

//========================================================
// shall require and validate that all client authentication mechanism adhere to the requirements defined in Financial-grade API Security Profile 1.0 - Part 1: Advanced;
// From FAPI 1.0 - Part 2: clause 5.2.2-14
// shall authenticate the confidential client using one of the following methods (this overrides FAPI Security Profile 1.0 - Part 1: Baseline clause 5.2.2-4):
//   tls_client_auth or self_signed_tls_client_auth as specified in section 2 of MTLS, or
//   private_key_jwt as specified in section 9 of OIDC;
//
// solved by configuration for client authentication

//========================================================
// shall require encrypted request objects as required by the Brasil Open Banking Security Profile;
//
// not applicable in DCR context

//========================================================
// shall validate that requested scopes are appropriate for the softwares authorized regulatory roles;
// DADOS: openid          consents resources accounts credit-cards-accounts customers invoice-financings financings loans unarranged-accounts-overdraft
// PAGTO: openid payments consents resources
// CONTA: openid
// CCORR: openid

    var regulatoryRoles = ssa.software_roles;

    isRoleDados = regulatoryRoles.indexOf("DADOS") != -1;
    isRolePagto = regulatoryRoles.indexOf("PAGTO") != -1;
    isRoleConta = regulatoryRoles.indexOf("CONTA") != -1;
    isRoleCcorr = regulatoryRoles.indexOf("CCORR") != -1;

    if (scopes.length != 0) {
        scopes = scope.split(' ');
        var foundInvalidScope = scopes.some(function (element) {
            var isValidScope = false;
            switch(element) {
                case "payments":
                    // payments is valid scope if list of regulatory roles includes PAGTO
                    isValidScope = isRolePagto;
                    break;
                case "resources":
                case "consents":
                    // resources and consents are valid scopes if list of regulatory roles includes PAGTO or DADOS
                    isValidScope = isRolePagto || isRoleDados;
                    break;
                case "accounts":
                case "credit-cards-accounts":
                case "customers":
                case "invoice-financings":
                case "financings":
                case "loans":
                case "unarranged-accounts-overdraft":
                    // any of the scopes above is a valid scope if the list of regulatory roles includes DADOS
                    isValidScope = isRoleDados;
                    break;
                case "openid":
                    // for the sake of completeness
                    isValidScope = true;
                    break;
                default:
                    // custom scope always valid
                    isValidScope = true;
                    break;
            }

            // found invalid scope
            return !isValidScope;
        });

        if (foundInvalidScope) {
            throw exceptionFactory.badRequestException("Unauthorized scope(s) requested.");
        }
    }

//========================================================
// should where possible validate client asserted metadata against metadata provided in the software_statement;
// if supporting tls_client_auth client authentication mechanism as defined in [RFC8705] shall only accept tls_client_auth_subject_dn as an indication of the certificate subject value as defined in clause 2.1.2 [RFC8705];
    registrationData.forEach(function(key, value)
    {
        // TODO: check if that can be solved by server configuration for non-templatized clients
        if (key.startsWith("tls_client_auth_") && key != "tls_client_auth_subject_dn") {
            throw exceptionFactory.badRequestException("Only tls_client_auth_subject_dn is allowed for indication of the certificate subject.");
        }

        var ssaValue;

        switch (key) {
            case "jwks_uri":
            case "redirect_uris":
            case "software_statement":
                break;
            case "software_id":
            case "software_version":
                ssaValue = ssa[key];
                if (ssaValue && value != ssaValue) {
                    throw exceptionFactory.badRequestException(key + " does not match the value provided in the software statement assertion.");
                }
                break;
            default:
                ssaValue = ssa["software_" + key];
                if (ssaValue && value != ssaValue) {
                    throw exceptionFactory.badRequestException(key + " does not match the value provided in the software statement assertion.");
                }
                break;
        }
    });

//========================================================
// shall accept all x.500 AttributeType name strings defined in the Distinguished Name of the x.509 Certificate Profiles defined in [Open Banking Brasil x.509 Certificate Standards][OBB-Cert-Standards];
// shall select and apply the encryption algorithm and cipher choice from the most recommended of the IANA cipher suites that is supported by the Authorisation Server;
//
// solved by server configuration
// TODO: create certificates that meet requirements and test subject DN


//========================================================
// shall populate defaults from values within the software statement assertion where possible;
    /* identify possible/applicable defaults:
        client_name
        client_uri
        jwks_uri
        logo_uri
        policy_uri
        tos_uri
        software_id
        software_version
    */

    // overwrite existing and add missing
    var attributes = {
        client_name: ssa.software_client_name,
        client_uri: ssa.software_client_uri,
        jwks_uri: ssa.software_jwks_uri,
        logo_uri: ssa.software_logo_uri,
        policy_uri: ssa.software_policy_uri,
        tos_uri: ssa.software_tos_uri,

        software_id: ssa.software_id,
        software_version: ssa.software_version
    }


//========================================================
// shall grant the client permission to the complete set of potential scopes based on the softwares regulatory permissions included in the software_statement;

    var authorizedScopes = [];

    if (isRoleDados) {
        authorizedScopes = ["openid",
            "consents",
            "resources",
            "accounts",
            "credit-cards-accounts",
            "customers",
            "invoice-financings",
            "financings",
            "loans",
            "unarranged-accounts-overdraft"];

        if (isRolePagto) {
            authorizedScopes.push("payments");
        }
    } else if (isRolePagto) {
        authorizedScopes = ["openid", "payments", "consents", "resources"];
    } else if (isRoleConta || isRoleCcorr) {
        authorizedScopes = [" openid"];
    }

    authorizedScopes.forEach(function(element) {
        if (scopes.indexOf(element) == -1) {
            scopes.push(element);
        }
    });

    if (scopes.length > 0) {
        attributes.scope = scopes.join(' ');
    }

//========================================================

    return attributes;
}
