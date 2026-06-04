/// Result returned from an AWS S3 file upload attempt
class AWSUploadResult {
  /// Whether the upload succeeded
  final bool success;

  /// Error message when [success] is false, null otherwise
  final String? errorMessage;

  /// The upload ID that was passed when starting the upload
  final String uploadId;

  /// Public S3 URL of the uploaded file; empty string on failure
  final String url;

  /// S3 bucket name; empty string on failure
  final String bucket;

  /// Full S3 object key (uploadFolder/fileName); empty string on failure
  final String key;

  /// File name used in S3; empty string on failure
  final String fileName;

  /// Local file path that was uploaded; empty string on failure
  final String filePath;

  const AWSUploadResult._({
    required this.success,
    required this.uploadId,
    required this.url,
    required this.bucket,
    required this.key,
    required this.fileName,
    required this.filePath,
    this.errorMessage,
  });

  factory AWSUploadResult.fromMap(Map<String, dynamic> map) {
    return AWSUploadResult._(
      success: true,
      uploadId: map['uploadId'] as String,
      url: map['url'] as String,
      bucket: map['bucket'] as String,
      key: map['key'] as String,
      fileName: map['fileName'] as String,
      filePath: map['filePath'] as String,
    );
  }

  factory AWSUploadResult.failure({
    required String uploadId,
    required String errorMessage,
  }) {
    return AWSUploadResult._(
      success: false,
      uploadId: uploadId,
      url: '',
      bucket: '',
      key: '',
      fileName: '',
      filePath: '',
      errorMessage: errorMessage,
    );
  }

  @override
  String toString() => success
      ? 'AWSUploadResult(success: true, uploadId: $uploadId, url: $url, bucket: $bucket, key: $key)'
      : 'AWSUploadResult(success: false, uploadId: $uploadId, error: $errorMessage)';
}
