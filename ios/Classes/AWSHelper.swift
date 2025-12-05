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
        default: return nil  // <-- invalid region returns nil
        }
    }

    /// Initialize S3 transfer utility with provided Cognito credentials
    func initializeS3(regionName: String, identityPoolId: String, providerName: String) -> Bool {
        guard let region = regionType(from: regionName) else {
            print("❌ Invalid AWS region: \(regionName)")
            return false
        }
        let devAuth = AmazonIdentityProvider(regionType: region,
            identityPoolId: identityPoolId,
            useEnhancedFlow: true,
            identityProviderManager: nil)
        let credentialsProvider = AWSCognitoCredentialsProvider(regionType: region,
                                                                identityProvider: devAuth)
        
        let configuration = AWSServiceConfiguration(region: region,
            credentialsProvider: credentialsProvider)

        AWSServiceManager.default().defaultServiceConfiguration = configuration

        let transferConfig = AWSS3TransferUtilityConfiguration()
        transferConfig.isAccelerateModeEnabled = false

        AWSS3TransferUtility.register(with: configuration!,
            transferUtilityConfiguration: transferConfig,
            forKey: "awsUploaderTransferUtility")

        AWSS3.register(with: configuration!, forKey: "awsUploaderS3")
        return true
    }
}
