package com.uqbrijesh.aws.uploader

import com.amazonaws.auth.AWSAbstractCognitoDeveloperIdentityProvider
import com.amazonaws.regions.Regions

/**
 * DeveloperAuthenticationProvider
 *
 * Provides Cognito temporary credentials (Token & IdentityId) for authenticated S3 upload.
 */
class DeveloperAuthenticationProvider(
    private val awsToken: String,
    private val awsIdentityId: String,
    private val providerName: String,
    accountId: String? = null,
    identityPoolId: String,
    region: Regions
) : AWSAbstractCognitoDeveloperIdentityProvider(accountId, identityPoolId, region) {

    /** Returns the name of the Cognito provider */
    override fun getProviderName(): String {
        return providerName
    }

    /** Refreshes token and updates Cognito identity */
    override fun refresh(): String {
        setToken(null)
        update(awsIdentityId, awsToken)
        return awsToken
    }
}
