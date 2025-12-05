import 'package:flutter_test/flutter_test.dart';
import 'package:aws_uploader/aws_uploader_platform_interface.dart';
import 'package:aws_uploader/aws_uploader_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockAwsUploaderPlatform
    with MockPlatformInterfaceMixin
    implements AwsUploaderPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final AwsUploaderPlatform initialPlatform = AwsUploaderPlatform.instance;

  test('$MethodChannelAwsUploader is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelAwsUploader>());
  });

  test('getPlatformVersion', () async {
    // AwsUploader awsUploaderPlugin = AwsUploader();
    MockAwsUploaderPlatform fakePlatform = MockAwsUploaderPlatform();
    AwsUploaderPlatform.instance = fakePlatform;

    // expect(await awsUploaderPlugin.getPlatformVersion(), '42');
  });
}
