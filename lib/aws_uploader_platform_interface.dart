import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'aws_uploader_method_channel.dart';

abstract class AwsUploaderPlatform extends PlatformInterface {
  /// Constructs a AwsUploaderPlatform.
  AwsUploaderPlatform() : super(token: _token);

  static final Object _token = Object();

  static AwsUploaderPlatform _instance = MethodChannelAwsUploader();

  /// The default instance of [AwsUploaderPlatform] to use.
  ///
  /// Defaults to [MethodChannelAwsUploader].
  static AwsUploaderPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [AwsUploaderPlatform] when
  /// they register themselves.
  static set instance(AwsUploaderPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
