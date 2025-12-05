# Changelog

All notable changes to this project will be documented in this file.

This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.0.1] - 2025-12-05

### Added
- Initial release of `aws_uploader` plugin
- Upload images to AWS S3 using Cognito credentials (`token` & `identityId`)
- Real-time upload progress stream for monitoring upload percentage
- Cancel ongoing uploads at any time
- Multi-part upload support for large image files
- Full support for **Android** and **iOS** platforms

### Fixed
- N/A (first release)

### Changed
- N/A

### Notes
- Currently supports only **image uploads**
- File path must exist and be valid for upload
- Only works on **Android & iOS**
