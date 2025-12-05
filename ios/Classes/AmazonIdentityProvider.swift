import AWSCore
import AWSCognito

public final class AmazonIdentityProvider: AWSCognitoCredentialsProviderHelper {
    // Store cached login dictionary
    private var cachedLogin: NSDictionary?

    // MARK: - Logins

    public override func logins() -> AWSTask<NSDictionary> {
        let login: NSDictionary = ["cognito-identity.amazonaws.com": AWSHelper.shared.awsToken]
        cachedLogin = login
        return AWSTask(result: cachedLogin)
    }

    // MARK: - Token

    public override func token() -> AWSTask<NSString> {
        return AWSTask(result: AWSHelper.shared.awsToken as NSString?)
    }

    // MARK: - IdentityId

    public override func getIdentityId() -> AWSTask<NSString> {
        return AWSTask(result: AWSHelper.shared.awsIdentityId as NSString?)
    }
}
