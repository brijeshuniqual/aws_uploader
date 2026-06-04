import Foundation
import AWSS3
import AWSCore
import AWSCognito

/// AWSHelper manages S3 transfer utility and credentials
class AWSHelper {
    static let shared = AWSHelper()

    /// Cognito token
    var awsToken: String?

    /// Cognito identity ID
    var awsIdentityId: String?

    /// Convert region string to AWSRegionType, return nil if invalid
    func regionType(from regionName: String) -> AWSRegionType? {
        switch regionName.lowercased() {
        case "us-east-1": return .USEast1
        case "us-east-2": return .USEast2
        case "us-west-1": return .USWest1
        case "us-west-2": return .USWest2
        case "ap-south-1": return .APSouth1
        case "ap-southeast-1": return .APSoutheast1
        case "ap-southeast-2": return .APSoutheast2
        case "ap-northeast-1": return .APNortheast1
        case "ap-northeast-2": return .APNortheast2
        case "eu-west-1": return .EUWest1
        case "eu-central-1": return .EUCentral1
        default: return nil
        }
    }

    /// Initialize S3 transfer utility with provided Cognito credentials
    func initializeS3(regionName: String, identityPoolId: String, providerName: String) -> Bool {
        print("🔧 [AWSHelper] initializeS3 called — region: \(regionName), pool: \(identityPoolId)")

        guard let region = regionType(from: regionName) else {
            print("❌ [AWSHelper] Invalid AWS region: \(regionName)")
            return false
        }
        print("✅ [AWSHelper] Region parsed: \(region.rawValue)")

        let devAuth = AmazonIdentityProvider(regionType: region,
            identityPoolId: identityPoolId,
            useEnhancedFlow: true,
            identityProviderManager: nil)
        print("✅ [AWSHelper] AmazonIdentityProvider created")

        let credentialsProvider = AWSCognitoCredentialsProvider(regionType: region,
                                                                identityProvider: devAuth)
        print("✅ [AWSHelper] AWSCognitoCredentialsProvider created")

        let configuration = AWSServiceConfiguration(region: region,
            credentialsProvider: credentialsProvider)
        print("✅ [AWSHelper] AWSServiceConfiguration created: \(String(describing: configuration))")

        AWSServiceManager.default().defaultServiceConfiguration = configuration
        print("✅ [AWSHelper] Default service configuration set")

        let transferConfig = AWSS3TransferUtilityConfiguration()
        transferConfig.isAccelerateModeEnabled = false

        // Register only once per key. Re-registering replaces the existing
        // AWSS3TransferUtility and creates a new background NSURLSession with
        // the same identifier, which causes the 2nd upload to hang silently.
        // Credentials stay current because AmazonIdentityProvider reads from
        // AWSHelper.shared.awsToken / awsIdentityId at call time.
        if AWSS3TransferUtility.s3TransferUtility(forKey: "awsUploaderTransferUtility") == nil {
            print("🔧 [AWSHelper] Registering AWSS3TransferUtility (first time)...")
            AWSS3TransferUtility.register(with: configuration!,
                transferUtilityConfiguration: transferConfig,
                forKey: "awsUploaderTransferUtility")
            print("✅ [AWSHelper] AWSS3TransferUtility registered")
        } else {
            print("✅ [AWSHelper] AWSS3TransferUtility already registered — reusing existing instance")
        }

        if AWSS3.s3(forKey: "awsUploaderS3") == nil {
            AWSS3.register(with: configuration!, forKey: "awsUploaderS3")
            print("✅ [AWSHelper] AWSS3 registered")
        } else {
            print("✅ [AWSHelper] AWSS3 already registered — reusing existing instance")
        }

        return true
    }
}
