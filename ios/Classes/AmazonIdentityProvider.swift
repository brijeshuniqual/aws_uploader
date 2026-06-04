import AWSCore
import AWSCognito

public final class AmazonIdentityProvider: AWSCognitoCredentialsProviderHelper {
    private var cachedLogin: NSDictionary?

    // MARK: - Logins

    public override func logins() -> AWSTask<NSDictionary> {
        print("🔑 [AmazonIdentityProvider] logins() called — token prefix: \(AWSHelper.shared.awsToken?.prefix(20) ?? "nil")")
        let login: NSDictionary = ["cognito-identity.amazonaws.com": AWSHelper.shared.awsToken as Any]
        cachedLogin = login
        return AWSTask(result: cachedLogin)
    }

    // MARK: - Token

    public override func token() -> AWSTask<NSString> {
        print("🔑 [AmazonIdentityProvider] token() called")
        return AWSTask(result: AWSHelper.shared.awsToken as NSString?)
    }

    // MARK: - IdentityId

    public override func getIdentityId() -> AWSTask<NSString> {
        print("🔑 [AmazonIdentityProvider] getIdentityId() called — identityId: \(AWSHelper.shared.awsIdentityId ?? "nil")")
        return AWSTask(result: AWSHelper.shared.awsIdentityId as NSString?)
    }
}
