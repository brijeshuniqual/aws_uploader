import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'aws_uploader_platform_interface.dart';

/// An implementation of [AwsUploaderPlatform] that uses method channels.
class MethodChannelAwsUploader extends AwsUploaderPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('aws_uploader');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
