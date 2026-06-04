import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aws_uploader/aws_uploader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel methodChannel = MethodChannel('aws_uploader');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
  });

  // ─── AWSUploadResult ────────────────────────────────────────────────────────

  group('AWSUploadResult', () {
    test('fromMap builds a successful result', () {
      final result = AWSUploadResult.fromMap({
        'uploadId': 'id-1',
        'url': 'https://bucket.s3.region.amazonaws.com/key',
        'bucket': 'bucket',
        'key': 'uploads/file.jpg',
        'fileName': 'file.jpg',
        'filePath': '/tmp/file.jpg',
      });

      expect(result.success, isTrue);
      expect(result.errorMessage, isNull);
      expect(result.uploadId, 'id-1');
      expect(result.url, 'https://bucket.s3.region.amazonaws.com/key');
      expect(result.bucket, 'bucket');
      expect(result.key, 'uploads/file.jpg');
      expect(result.fileName, 'file.jpg');
      expect(result.filePath, '/tmp/file.jpg');
    });

    test('failure factory builds a failed result', () {
      final result = AWSUploadResult.failure(
        uploadId: 'id-2',
        errorMessage: 'Upload failed',
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, 'Upload failed');
      expect(result.uploadId, 'id-2');
      expect(result.url, isEmpty);
      expect(result.bucket, isEmpty);
      expect(result.key, isEmpty);
      expect(result.fileName, isEmpty);
      expect(result.filePath, isEmpty);
    });

    test('toString reflects success state', () {
      final ok = AWSUploadResult.fromMap({
        'uploadId': 'id-3',
        'url': 'https://example.com/file.jpg',
        'bucket': 'b',
        'key': 'k',
        'fileName': 'f',
        'filePath': 'p',
      });
      expect(ok.toString(), contains('success: true'));

      final fail = AWSUploadResult.failure(uploadId: 'id-4', errorMessage: 'err');
      expect(fail.toString(), contains('success: false'));
      expect(fail.toString(), contains('err'));
    });
  });

  // ─── AWSUploadProgressEvent ─────────────────────────────────────────────────

  group('AWSUploadProgressEvent', () {
    test('fromMap parses progress status', () {
      final event = AWSUploadProgressEvent.fromMap({
        'uploadId': 'id-1',
        'status': 'progress',
        'progress': 42,
      });

      expect(event.status, AWSUploadStatus.progress);
      expect(event.progress, 42);
      expect(event.url, isNull);
      expect(event.error, isNull);
    });

    test('fromMap parses completed status', () {
      final event = AWSUploadProgressEvent.fromMap({
        'uploadId': 'id-1',
        'status': 'completed',
        'progress': 100,
        'url': 'https://example.com/file.jpg',
      });

      expect(event.status, AWSUploadStatus.completed);
      expect(event.progress, 100);
      expect(event.url, 'https://example.com/file.jpg');
    });

    test('fromMap parses failed status', () {
      final event = AWSUploadProgressEvent.fromMap({
        'uploadId': 'id-1',
        'status': 'failed',
        'progress': 0,
        'error': 'Network error',
      });

      expect(event.status, AWSUploadStatus.failed);
      expect(event.error, 'Network error');
    });

    test('fromMap defaults unknown status to failed', () {
      final event = AWSUploadProgressEvent.fromMap({
        'uploadId': 'id-1',
        'status': 'unknown_value',
        'progress': 0,
      });

      expect(event.status, AWSUploadStatus.failed);
    });
  });

  // ─── AwsUploader.startFileUpload ────────────────────────────────────────────

  group('AwsUploader.startFileUpload', () {
    test('returns successful result when channel returns data', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async {
        expect(call.method, 'startFileUpload');
        expect(call.arguments['uploadId'], 'test-id');
        return {
          'uploadId': 'test-id',
          'url': 'https://bucket.s3.ap-south-1.amazonaws.com/uploads/file.jpg',
          'bucket': 'bucket',
          'key': 'uploads/file.jpg',
          'fileName': 'file.jpg',
          'filePath': '/tmp/file.jpg',
        };
      });

      final result = await AwsUploader.startFileUpload(
        uploadId: 'test-id',
        awsToken: 'token',
        identityId: 'identity',
        bucketName: 'bucket',
        filePath: '/tmp/file.jpg',
        fileName: 'file.jpg',
        uploadFolder: 'uploads',
        identityPoolId: 'pool-id',
        providerName: 'provider',
        region: 'ap-south-1',
      );

      expect(result.success, isTrue);
      expect(result.uploadId, 'test-id');
      expect(result.url, contains('amazonaws.com'));
    });

    test('returns failure result on PlatformException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async {
        throw PlatformException(code: 'UPLOAD_FAILED', message: 'S3 error');
      });

      final result = await AwsUploader.startFileUpload(
        uploadId: 'test-id',
        awsToken: 'token',
        identityId: 'identity',
        bucketName: 'bucket',
        filePath: '/tmp/file.jpg',
        fileName: 'file.jpg',
        uploadFolder: 'uploads',
        identityPoolId: 'pool-id',
        providerName: 'provider',
        region: 'ap-south-1',
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('S3 error'));
      expect(result.uploadId, 'test-id');
    });

    test('returns failure result on unexpected error', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async {
        throw Exception('Unexpected');
      });

      final result = await AwsUploader.startFileUpload(
        uploadId: 'test-id',
        awsToken: 'token',
        identityId: 'identity',
        bucketName: 'bucket',
        filePath: '/tmp/file.jpg',
        fileName: 'file.jpg',
        uploadFolder: 'uploads',
        identityPoolId: 'pool-id',
        providerName: 'provider',
        region: 'ap-south-1',
      );

      expect(result.success, isFalse);
      expect(result.uploadId, 'test-id');
    });

    test('passes contentType when provided', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async {
        expect(call.arguments['contentType'], 'image/png');
        return {
          'uploadId': 'test-id',
          'url': 'https://example.com/f.png',
          'bucket': 'b',
          'key': 'k',
          'fileName': 'f.png',
          'filePath': '/tmp/f.png',
        };
      });

      final result = await AwsUploader.startFileUpload(
        uploadId: 'test-id',
        awsToken: 'token',
        identityId: 'identity',
        bucketName: 'b',
        filePath: '/tmp/f.png',
        fileName: 'f.png',
        uploadFolder: 'uploads',
        identityPoolId: 'pool-id',
        providerName: 'provider',
        region: 'ap-south-1',
        contentType: 'image/png',
      );

      expect(result.success, isTrue);
    });
  });

  // ─── AwsUploader.cancelUpload ───────────────────────────────────────────────

  group('AwsUploader.cancelUpload', () {
    test('sends cancelUpload method with uploadId', () async {
      String? capturedId;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async {
        expect(call.method, 'cancelUpload');
        capturedId = call.arguments['uploadId'] as String;
        return null;
      });

      await AwsUploader.cancelUpload('cancel-id');
      expect(capturedId, 'cancel-id');
    });

    test('returns failure result on PlatformException during cancel', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async {
        throw PlatformException(code: 'CANCEL_FAILED', message: 'Cannot cancel');
      });

      expect(
        () => AwsUploader.cancelUpload('id'),
        throwsException,
      );
    });
  });
}
