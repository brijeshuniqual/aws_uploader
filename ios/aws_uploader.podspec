#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint aws_uploader.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'aws_uploader'
  s.version          = '0.1.0'
  s.summary          = 'Flutter plugin to upload any file to AWS S3 using Cognito token-based authentication.'
  s.description      = <<-DESC
    aws_uploader lets you upload images, videos, documents, and any other file type
    directly to AWS S3 from Flutter apps. It uses Cognito Developer Identity (token +
    identityId) for authentication, streams real-time upload progress via an EventChannel,
    supports multi-part uploads for large files, and allows cancellation of in-flight uploads.
  DESC
  s.homepage         = 'https://github.com/brijeshuniqual/aws_uploader'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'brijeshbhut' => 'uniqual.dev@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.dependency 'AWSS3'
  s.dependency 'AWSCore'
  s.dependency 'AWSCognito'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
