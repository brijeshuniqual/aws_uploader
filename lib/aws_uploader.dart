import 'package:flutter/services.dart';

/// AwsUploader Flutter plugin
///
/// Provides functions to upload images to AWS S3 using Cognito token & identityId.
/// Supports upload progress stream and cancellation.
class AwsUploader {
  static const MethodChannel _methodChannel = MethodChannel('aws_uploader');
  static const EventChannel _eventChannel = EventChannel(
    'aws_uploader_progress',
  );

  /// Stream to listen for upload progress
  /// Emits a map containing:
  /// - "uploadId": the ID of the upload
  /// - "status": progress/completed/failed
  /// - "progress": percentage (only for progress)
  /// - "url": S3 URL (only when completed)
  static Stream<Map<String, dynamic>> get progressStream => _eventChannel
      .receiveBroadcastStream()
      .map((e) => Map<String, dynamic>.from(e));

  /// Starts uploading an image to AWS S3
  ///
  /// [uploadId] is a unique identifier for this upload
  /// [bucketName] is your S3 bucket
  /// [filePath] is the local path of the image
  /// [fileName] is the name to save the image as in S3
  /// [imageUploadFolder] is the S3 folder
  /// [region] is AWS region
  /// [identityId] and [awsToken] are Cognito credentials
  /// [providerName] is the Cognito provider
  static Future<String> startImgUpload({
    required String uploadId,
    required String awsToken,
    required String identityId,
    required String bucketName,
    required String filePath,
    required String fileName,
    required String imageUploadFolder,
    required String identityPoolId,
    required String providerName,
    required String region,
  }) async {
    try {
      final fileUrl = await _methodChannel.invokeMethod('startImgUpload', {
        'region': region,
        'uploadId': uploadId,
        'awsToken': awsToken,
        'identityId': identityId,
        'bucketName': bucketName,
        'filePath': filePath,
        'fileName': fileName,
        'imageUploadFolder': imageUploadFolder,
        'identityPoolId': identityPoolId,
        'providerName': providerName,
      });
      return fileUrl;
    } on PlatformException catch (e) {
      // Forward the exception with a meaningful message
      throw Exception('AWS upload failed: ${e.message}');
    } catch (e) {
      // Catch any other exceptions
      throw Exception('Unexpected error while uploading to AWS: $e');
    }
  }

  /// Cancel an ongoing upload by [uploadId]
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
