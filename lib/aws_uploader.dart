import 'package:flutter/services.dart';
import 'aws_upload_result.dart';
import 'aws_upload_progress_event.dart';

export 'aws_upload_result.dart';
export 'aws_upload_progress_event.dart';

/// Flutter plugin for uploading any file to AWS S3 via Cognito token auth.
///
/// Supports progress streaming, cancellation, and multi-part uploads.
class AwsUploader {
  static const MethodChannel _methodChannel = MethodChannel('aws_uploader');
  static const EventChannel _eventChannel = EventChannel('aws_uploader_progress');

  /// Broadcast stream of [AWSUploadProgressEvent] for all active uploads.
  ///
  /// Events include upload progress (0–100 %), completion with URL, and failure.
  static Stream<AWSUploadProgressEvent> get progressStream =>
      _eventChannel
          .receiveBroadcastStream()
          .map((e) => AWSUploadProgressEvent.fromMap(Map<String, dynamic>.from(e)));

  /// Uploads any file to AWS S3 using Cognito token-based authentication.
  ///
  /// - [uploadId] unique identifier for this upload (used to correlate stream events)
  /// - [awsToken] Cognito token from your backend
  /// - [identityId] Cognito identity ID from your backend
  /// - [bucketName] S3 bucket name
  /// - [filePath] absolute local path to the file
  /// - [fileName] filename to store in S3 (e.g. `photo.jpg`, `report.pdf`)
  /// - [uploadFolder] S3 folder / prefix (e.g. `uploads/avatars`)
  /// - [identityPoolId] Cognito identity pool ID from AWS Console
  /// - [providerName] Cognito developer provider name from AWS Console
  /// - [region] AWS region string (e.g. `us-east-1`)
  /// - [contentType] MIME type override; auto-detected from [fileName] extension when omitted
  ///
  /// Returns an [AWSUploadResult] on both success and failure.
  ///
  /// Check [AWSUploadResult.success] to determine the outcome.
  /// On failure, [AWSUploadResult.errorMessage] contains the reason.
  static Future<AWSUploadResult> startFileUpload({
    required String uploadId,
    required String awsToken,
    required String identityId,
    required String bucketName,
    required String filePath,
    required String fileName,
    required String uploadFolder,
    required String identityPoolId,
    required String providerName,
    required String region,
    String? contentType,
  }) async {
    try {
      final raw = await _methodChannel.invokeMethod('startFileUpload', {
        'region': region,
        'uploadId': uploadId,
        'awsToken': awsToken,
        'identityId': identityId,
        'bucketName': bucketName,
        'filePath': filePath,
        'fileName': fileName,
        'uploadFolder': uploadFolder,
        'identityPoolId': identityPoolId,
        'providerName': providerName,
        if (contentType != null) 'contentType': contentType,
      });
      return AWSUploadResult.fromMap(Map<String, dynamic>.from(raw));
    } on PlatformException catch (e) {
      return AWSUploadResult.failure(
        uploadId: uploadId,
        errorMessage: e.message ?? 'AWS upload failed',
      );
    } catch (e) {
      return AWSUploadResult.failure(
        uploadId: uploadId,
        errorMessage: 'Unexpected error while uploading to AWS: $e',
      );
    }
  }

  /// Cancels an ongoing upload identified by [uploadId].
  static Future<void> cancelUpload(String uploadId) async {
    try {
      await _methodChannel.invokeMethod('cancelUpload', {'uploadId': uploadId});
    } on PlatformException catch (e) {
      throw Exception('Failed to cancel upload: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error while cancelling upload: $e');
    }
  }
}
