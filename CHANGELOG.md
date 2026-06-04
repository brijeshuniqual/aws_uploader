# Changelog

All notable changes to this project will be documented in this file.

This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.1.0] - 2026-06-04

### Added
- `startFileUpload` — replaces `startImgUpload`; now accepts any file type (images, video, audio, PDF, documents, archives, etc.)
- `AWSUploadResult` — structured return type with `uploadId`, `url`, `bucket`, `key`, `fileName`, `filePath`, `success`, and `errorMessage`
- `AWSUploadResult.failure()` — factory for failed results; `startFileUpload` never throws, check `result.success` instead
- `AWSUploadProgressEvent` — typed stream event with `AWSUploadStatus` enum (`progress`, `completed`, `failed`)
- Auto MIME type detection from file extension on both Android and iOS; optional `contentType` parameter to override
- `ios/Package.swift` — Swift Package Manager support for iOS (uses `aws-amplify/aws-sdk-ios-spm` binary XCFrameworks)

### Changed
- `imageUploadFolder` parameter renamed to `uploadFolder` to reflect support for all file types
- Progress stream type changed from `Stream<Map<String, dynamic>>` to `Stream<AWSUploadProgressEvent>`
- `startFileUpload` returns `AWSUploadResult` instead of a plain `String`
- Content type is no longer hardcoded to `image/jpeg`
- Minimum Flutter constraint updated to `>=3.19.0`

### Fixed
- iOS: re-registering `AWSS3TransferUtility` with the same key on every upload replaced the existing background `NSURLSession`, causing all uploads after the first to hang silently with no events or errors; the utility is now registered once per app session
- iOS: upload errors now correctly resolve the Flutter method result with `FlutterError` (previously the future would hang on failure)
- Android: added `resultSent` guard to prevent `MethodChannel.Result` being called twice when both `FAILED` state and `onError` fire
- Android: `FAILED` transfer state now calls `result.error()` so the Dart future resolves instead of silently completing

---

## [0.0.1] - 2025-12-05

### Added
- Initial release of `aws_uploader` plugin
- Upload images to AWS S3 using Cognito Developer Identity (`token` & `identityId`)
- Real-time upload progress stream
- Cancel ongoing uploads at any time
- Multi-part upload support for large files
- Android and iOS support
