# aws_uploader

[![Flutter](https://img.shields.io/badge/flutter-3.3+-blue.svg)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/platform-android%20|%20ios-lightgrey.svg)](#)

A Flutter plugin to upload any file — images, videos, PDFs, documents, audio — to **AWS S3** using **Cognito Developer Identity** (token + identityId). Built on native multi-part upload APIs for both Android and iOS.

---

## Features

- Upload **any file type** to AWS S3 (images, video, audio, PDF, docs, zip, …)
- **MIME type auto-detection** from file extension, with optional override
- **Real-time progress stream** — typed events with percentage, completion URL, and error info
- **Cancel** any in-flight upload by its ID
- **Multi-part upload** support for large files (native TransferUtility on both platforms)
- Secure uploads via **Cognito Developer Identity** (token & identityId from your backend)
- Full native implementation — no Dart-side HTTP, no presigned URL handling needed
- **Android & iOS** support (CocoaPods + Swift Package Manager)

---

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  aws_uploader: ^0.1.0
```

---

## Usage

### 1. Import

```dart
import 'package:aws_uploader/aws_uploader.dart';
```

### 2. Listen to the progress stream

Set this up once — it covers all active uploads:

```dart
AwsUploader.progressStream.listen((AWSUploadProgressEvent event) {
  print('${event.uploadId} → ${event.status.name}  ${event.progress}%');

  if (event.status == AWSUploadStatus.completed) {
    print('URL: ${event.url}');
  }
  if (event.status == AWSUploadStatus.failed) {
    print('Error: ${event.error}');
  }
});
```

### 3. Upload a file

`startFileUpload` never throws — check `result.success` instead.

```dart
final AWSUploadResult result = await AwsUploader.startFileUpload(
  uploadId: 'unique-id-1',               // correlates stream events to this call
  awsToken: '<cognito-token>',           // from your backend
  identityId: '<cognito-identity-id>',   // from your backend
  bucketName: 'my-s3-bucket',
  filePath: '/path/to/local/file.pdf',
  fileName: 'report.pdf',
  uploadFolder: 'uploads/documents',     // S3 prefix / folder
  identityPoolId: '<identity-pool-id>',  // from AWS Console
  providerName: '<developer-provider>',  // from AWS Console
  region: 'us-east-1',
  // contentType: 'application/pdf',     // optional — auto-detected from extension
);

if (result.success) {
  print('Uploaded to: ${result.url}');
  print('S3 key: ${result.key}');
} else {
  print('Upload failed: ${result.errorMessage}');
}
```

### 4. Cancel an upload

```dart
await AwsUploader.cancelUpload('unique-id-1');
```

---

## Return types

### `AWSUploadResult`

Returned by `startFileUpload` on both success and failure.

| Field | Type | Description |
|-------|------|-------------|
| `success` | `bool` | `true` if the upload succeeded |
| `uploadId` | `String` | The ID passed when starting the upload |
| `url` | `String` | Public S3 URL — empty string on failure |
| `bucket` | `String` | S3 bucket name — empty string on failure |
| `key` | `String` | Full S3 object key (`uploadFolder/fileName`) — empty string on failure |
| `fileName` | `String` | File name stored in S3 — empty string on failure |
| `filePath` | `String` | Original local file path — empty string on failure |
| `errorMessage` | `String?` | Error description — set only when `success` is `false` |

### `AWSUploadProgressEvent`

Emitted by `progressStream` during upload.

| Field | Type | Description |
|-------|------|-------------|
| `uploadId` | `String` | Identifies which upload this event belongs to |
| `status` | `AWSUploadStatus` | `progress`, `completed`, or `failed` |
| `progress` | `int` | Completion percentage (0–100) |
| `url` | `String?` | S3 URL — set only on `completed` |
| `error` | `String?` | Error message — set only on `failed` |

---

## Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `uploadId` | yes | Unique string to identify this upload |
| `awsToken` | yes | Cognito developer identity token from your backend |
| `identityId` | yes | Cognito identity ID from your backend |
| `bucketName` | yes | Target S3 bucket |
| `filePath` | yes | Absolute local path to the file |
| `fileName` | yes | Name to store the file as in S3 |
| `uploadFolder` | yes | S3 folder prefix (e.g. `uploads/avatars`) |
| `identityPoolId` | yes | Cognito identity pool ID from AWS Console |
| `providerName` | yes | Cognito developer provider name from AWS Console |
| `region` | yes | AWS region string (e.g. `us-east-1`) |
| `contentType` | no | MIME type override; auto-detected from `fileName` extension when omitted |

---

## Platform support

| Platform | Method channel | Progress stream | Cancel | SPM |
|----------|---------------|-----------------|--------|-----|
| Android | ✅ | ✅ | ✅ | — |
| iOS | ✅ | ✅ | ✅ | ✅ |

---

## Requirements

- Flutter ≥ 3.19.0
- Dart ≥ 3.7.0
- Android minSdk 24
- iOS 13.0+
