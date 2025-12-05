import Flutter
import UIKit
import AWSCore
import AWSS3
import AWSCognito

/// Flutter plugin class for AWS S3 upload
/// Handles method calls, event streams, and manages active uploads
public class AwsUploaderPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {

  /// Event sink for sending upload progress events to Flutter
  private var eventSink: FlutterEventSink?

  /// Stores active upload tasks keyed by uploadId
  private var uploads: [String: AWSS3TransferUtilityMultiPartUploadTask] = [:]

  /// Registers plugin with Flutter
  public static func register(with registrar: FlutterPluginRegistrar) {
    let methodChannel = FlutterMethodChannel(name: "aws_uploader", binaryMessenger: registrar.messenger())
    let eventChannel = FlutterEventChannel(name: "aws_uploader_progress", binaryMessenger: registrar.messenger())
      
    let instance = AwsUploaderPlugin()
    registrar.addMethodCallDelegate(instance, channel: methodChannel)
    eventChannel.setStreamHandler(instance)
  }

  /// Handles method calls from Flutter
  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "startImgUpload":
      guard let args = call.arguments as? [String: Any] else {
        result(FlutterError(code: "INVALID_ARGS", message: "Missing arguments", details: nil))
        return
      }
      startImgUpload(args: args, result: result)
    case "cancelUpload":
      guard let args = call.arguments as? [String: Any],
      let uploadId = args["uploadId"] as? String else {
        result(FlutterError(code: "INVALID_ARGS", message: "Missing uploadId", details: nil))
        return
      }
      cancelUpload(uploadId: uploadId)
        result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Start listening to event stream from Flutter
  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    self.eventSink = events
    return nil
  }

  /// Stop listening to event stream
  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    self.eventSink = nil
    return nil
  }
}

// MARK: - Upload Logic
extension AwsUploaderPlugin {

  /// Starts uploading an image to AWS S3
  /// [args] contains all upload parameters
  private func startImgUpload(args: [String: Any], result: @escaping FlutterResult) {
    // 1️⃣ Validate required arguments
    guard
    let uploadId = args["uploadId"] as? String,
    let bucketName = args["bucketName"] as? String,
    let filePath = args["filePath"] as? String,
    let fileName = args["fileName"] as? String,
    let imageUploadFolder = args["imageUploadFolder"] as? String,
    let regionName = args["region"] as? String,
    let identityPoolId = args["identityPoolId"] as? String,
    let awsToken = args["awsToken"] as? String,
    let awsIdentityId = args["identityId"] as? String,
    let providerName = args["providerName"] as? String
    else {
      result(FlutterError(code: "INVALID_ARGS", message: "Missing required arguments for AWS upload", details: nil))
      return
    }

    let fileURL = URL(fileURLWithPath: filePath)
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      result(FlutterError(code: "INVALID_FILE", message: "File does not exist at path: \(filePath)", details: nil))
      return
    }

    guard let region = AWSHelper.shared.regionType(from: regionName) else {
      result(FlutterError(code: "INVALID_REGION", message: "Region is null or invalid", details: nil))
      return
    }

    do {
      // Set AWSHelper credentials
      AWSHelper.shared.awsToken = awsToken
      AWSHelper.shared.awsIdentityId = awsIdentityId

      // Initialize S3 and check if region is valid
      let success = AWSHelper.shared.initializeS3(regionName: regionName,
        identityPoolId: identityPoolId,
        providerName: providerName)
      if !success {
        // Stop upload early if region invalid
        result(FlutterError(code: "INVALID_REGION", message: "Provided AWS region is invalid: \(regionName)", details: nil))
        return
      }

      let key = "\(imageUploadFolder)/\(fileName)"

      let expression = AWSS3TransferUtilityMultiPartUploadExpression()
      expression.progressBlock = {
        [weak self] _, progress in
        DispatchQueue.main.async {
          self?.eventSink?(["uploadId": uploadId, "status": "progress", "progress": Int(progress.fractionCompleted * 100)])
        }
      }

      guard let transferUtility = AWSS3TransferUtility.s3TransferUtility(forKey: "awsUploaderTransferUtility") else {
        result(FlutterError(code: "UPLOAD_ERROR", message: "TransferUtility not initialized", details: nil))
        return
      }

      transferUtility.uploadUsingMultiPart(fileURL: fileURL,
        bucket: bucketName,
        key: key,
        contentType: "image/jpeg",
        expression: expression) {
        [weak self] task, error in
        if let error = error {
          self?.eventSink?(["uploadId": uploadId, "status": "failed", "error": error.localizedDescription])
        } else {
          let url = "https://\(bucketName).s3.\(regionName).amazonaws.com/\(key)"

          result(url)

          self?.eventSink?(["uploadId": uploadId, "status": "completed", "url": url])
        }
        self?.uploads.removeValue(forKey: uploadId)
      }.continueWith {
        [weak self] task -> Any? in
        if let uploadTask = task.result {
          self?.uploads[uploadId] = uploadTask
        }
        return nil
      }

    } catch let error {
      result(FlutterError(code: "UPLOAD_INIT_FAILED", message: "Failed to initialize AWS upload: \(error.localizedDescription)", details: nil))
    }

  }

  /// Cancels an ongoing upload by [uploadId]
  private func cancelUpload(uploadId: String) {
    if let task = uploads[uploadId] {
      task.cancel()
      uploads.removeValue(forKey: uploadId)
    }
  }
}
