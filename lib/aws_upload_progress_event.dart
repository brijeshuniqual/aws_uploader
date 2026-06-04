/// Upload status emitted by the progress stream
enum AWSUploadStatus {
  /// Upload is in progress; check [AWSUploadProgressEvent.progress] for percentage
  progress,

  /// Upload finished successfully; [AWSUploadProgressEvent.url] is set
  completed,

  /// Upload failed; [AWSUploadProgressEvent.error] may contain the reason
  failed,
}

/// A single event emitted by [AwsUploader.progressStream]
class AWSUploadProgressEvent {
  final String uploadId;
  final AWSUploadStatus status;

  /// Upload completion percentage (0–100). Non-zero only during [AWSUploadStatus.progress]
  /// and set to 100 when [AWSUploadStatus.completed].
  final int progress;

  /// S3 URL of the uploaded file. Set only on [AWSUploadStatus.completed].
  final String? url;

  /// Error message. Set only on [AWSUploadStatus.failed].
  final String? error;

  const AWSUploadProgressEvent({
    required this.uploadId,
    required this.status,
    this.progress = 0,
    this.url,
    this.error,
  });

  factory AWSUploadProgressEvent.fromMap(Map<String, dynamic> map) {
    final statusStr = map['status'] as String? ?? '';
    final status = switch (statusStr) {
      'progress' => AWSUploadStatus.progress,
      'completed' => AWSUploadStatus.completed,
      _ => AWSUploadStatus.failed,
    };
    return AWSUploadProgressEvent(
      uploadId: map['uploadId'] as String? ?? '',
      status: status,
      progress: (map['progress'] as num?)?.toInt() ?? 0,
      url: map['url'] as String?,
      error: map['error'] as String?,
    );
  }

  @override
  String toString() =>
      'AWSUploadProgressEvent(uploadId: $uploadId, status: $status, '
      'progress: $progress, url: $url, error: $error)';
}
