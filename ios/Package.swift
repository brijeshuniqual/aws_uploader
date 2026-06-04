// swift-tools-version: 5.9
// Flutter iOS SPM integration — see https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-plugin-authors
//
// AWS SDK dependencies come from aws-amplify/aws-sdk-ios-spm, which ships
// the same ObjC-based AWS iOS SDK that the CocoaPods spec uses, packaged as
// binary XCFramework targets for SPM consumption.
import PackageDescription

let package = Package(
    name: "aws_uploader",
    platforms: [
        .iOS(.v13),
    ],
    products: [
        .library(name: "aws_uploader", targets: ["aws_uploader"]),
    ],
    dependencies: [
        // Binary XCFramework distribution of the AWS iOS SDK (ObjC).
        // Check https://github.com/aws-amplify/aws-sdk-ios-spm for the latest version.
        .package(
            url: "https://github.com/aws-amplify/aws-sdk-ios-spm",
            from: "2.36.7"
        ),
    ],
    targets: [
        .target(
            name: "aws_uploader",
            dependencies: [
                .product(name: "AWSS3",      package: "aws-sdk-ios-spm"),
                .product(name: "AWSCognito", package: "aws-sdk-ios-spm"),
                // AWSCore is a transitive dependency of both; listed explicitly for clarity
                .product(name: "AWSCore",    package: "aws-sdk-ios-spm"),
            ],
            path: "Classes"
        ),
    ]
)
