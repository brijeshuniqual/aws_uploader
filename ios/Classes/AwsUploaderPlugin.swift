import Flutter
import UIKit
import AWSCore
import AWSS3
import AWSCognito

public class AwsUploaderPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {

    private var eventSink: FlutterEventSink?
    private var uploads: [String: AWSS3TransferUtilityMultiPartUploadTask] = [:]

    public static func register(with registrar: FlutterPluginRegistrar) {
        let methodChannel = FlutterMethodChannel(name: "aws_uploader", binaryMessenger: registrar.messenger())
        let eventChannel = FlutterEventChannel(name: "aws_uploader_progress", binaryMessenger: registrar.messenger())

        let instance = AwsUploaderPlugin()
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        eventChannel.setStreamHandler(instance)
        print("✅ [AwsUploaderPlugin] Plugin registered")
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        print("📲 [AwsUploaderPlugin] Method called: \(call.method)")
        switch call.method {
        case "startFileUpload":
            guard let args = call.arguments as? [String: Any] else {
                print("❌ [AwsUploaderPlugin] Missing arguments")
                result(FlutterError(code: "INVALID_ARGS", message: "Missing arguments", details: nil))
                return
            }
            startFileUpload(args: args, result: result)
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

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        print("✅ [AwsUploaderPlugin] EventChannel onListen — stream subscribed")
        self.eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        print("⚠️ [AwsUploaderPlugin] EventChannel onCancel — stream cancelled")
        self.eventSink = nil
        return nil
    }
}

// MARK: - Upload Logic
extension AwsUploaderPlugin {

    private func mimeType(for path: String) -> String {
        switch (path as NSString).pathExtension.lowercased() {
        case "jpg", "jpeg": return "image/jpeg"
        case "png":         return "image/png"
        case "gif":         return "image/gif"
        case "webp":        return "image/webp"
        case "heic", "heif": return "image/heic"
        case "pdf":         return "application/pdf"
        case "mp4":         return "video/mp4"
        case "mov":         return "video/quicktime"
        case "avi":         return "video/x-msvideo"
        case "mkv":         return "video/x-matroska"
        case "mp3":         return "audio/mpeg"
        case "aac":         return "audio/aac"
        case "wav":         return "audio/wav"
        case "ogg":         return "audio/ogg"
        case "txt":         return "text/plain"
        case "html", "htm": return "text/html"
        case "csv":         return "text/csv"
        case "doc":         return "application/msword"
        case "docx":        return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "xls":         return "application/vnd.ms-excel"
        case "xlsx":        return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case "ppt":         return "application/vnd.ms-powerpoint"
        case "pptx":        return "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        case "zip":         return "application/zip"
        case "gz":          return "application/gzip"
        default:            return "application/octet-stream"
        }
    }

    private func startFileUpload(args: [String: Any], result: @escaping FlutterResult) {
        print("🚀 [AwsUploaderPlugin] startFileUpload args received")

        guard
            let uploadId       = args["uploadId"]       as? String,
            let bucketName     = args["bucketName"]     as? String,
            let filePath       = args["filePath"]       as? String,
            let fileName       = args["fileName"]       as? String,
            let uploadFolder   = args["uploadFolder"]   as? String,
            let regionName     = args["region"]         as? String,
            let identityPoolId = args["identityPoolId"] as? String,
            let awsToken       = args["awsToken"]       as? String,
            let awsIdentityId  = args["identityId"]     as? String,
            let providerName   = args["providerName"]   as? String
        else {
            print("❌ [AwsUploaderPlugin] Missing required arguments")
            result(FlutterError(code: "INVALID_ARGS", message: "Missing required arguments for AWS upload", details: nil))
            return
        }

        print("✅ [AwsUploaderPlugin] Args parsed — uploadId: \(uploadId), file: \(fileName), bucket: \(bucketName)")

        let contentType = args["contentType"] as? String ?? mimeType(for: filePath)
        print("✅ [AwsUploaderPlugin] contentType: \(contentType)")

        let fileURL = URL(fileURLWithPath: filePath)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("❌ [AwsUploaderPlugin] File not found at: \(filePath)")
            result(FlutterError(code: "INVALID_FILE", message: "File does not exist at path: \(filePath)", details: nil))
            return
        }
        print("✅ [AwsUploaderPlugin] File exists at: \(filePath)")

        guard AWSHelper.shared.regionType(from: regionName) != nil else {
            print("❌ [AwsUploaderPlugin] Invalid region: \(regionName)")
            result(FlutterError(code: "INVALID_REGION", message: "Region is null or invalid: \(regionName)", details: nil))
            return
        }

        AWSHelper.shared.awsToken = awsToken
        AWSHelper.shared.awsIdentityId = awsIdentityId
        print("✅ [AwsUploaderPlugin] Credentials set on AWSHelper.shared")

        let initialized = AWSHelper.shared.initializeS3(
            regionName: regionName,
            identityPoolId: identityPoolId,
            providerName: providerName
        )
        guard initialized else {
            print("❌ [AwsUploaderPlugin] initializeS3 returned false")
            result(FlutterError(code: "INVALID_REGION", message: "Provided AWS region is invalid: \(regionName)", details: nil))
            return
        }
        print("✅ [AwsUploaderPlugin] initializeS3 succeeded")

        guard let transferUtility = AWSS3TransferUtility.s3TransferUtility(forKey: "awsUploaderTransferUtility") else {
            print("❌ [AwsUploaderPlugin] TransferUtility is nil for key 'awsUploaderTransferUtility'")
            result(FlutterError(code: "UPLOAD_ERROR", message: "TransferUtility not initialized", details: nil))
            return
        }
        print("✅ [AwsUploaderPlugin] TransferUtility retrieved successfully")

        let key = "\(uploadFolder)/\(fileName)"
        print("🔧 [AwsUploaderPlugin] S3 key: \(key)")

        let expression = AWSS3TransferUtilityMultiPartUploadExpression()
        expression.progressBlock = { [weak self] _, progress in
            let pct = Int(progress.fractionCompleted * 100)
            print("📶 [AwsUploaderPlugin] Progress: \(pct)% — uploadId: \(uploadId)")
            DispatchQueue.main.async {
                self?.eventSink?([
                    "uploadId": uploadId,
                    "status": "progress",
                    "progress": pct,
                ])
            }
        }

        // Guards result() from being called more than once across both callbacks.
        var resultSent = false

        func sendResult(_ value: Any?) {
            guard !resultSent else { return }
            resultSent = true
            result(value)
        }

        func sendFailure(code: String, message: String) {
            sendResult(FlutterError(code: code, message: message, details: nil))
            self.eventSink?([
                "uploadId": uploadId,
                "status": "failed",
                "progress": 0,
                "error": message,
            ])
        }

        print("🔧 [AwsUploaderPlugin] Starting multipart upload...")
        transferUtility.uploadUsingMultiPart(
            fileURL: fileURL,
            bucket: bucketName,
            key: key,
            contentType: contentType,
            expression: expression
        ) { [weak self] _, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ [AwsUploaderPlugin] Upload completion error: \(error.localizedDescription)")
                    sendResult(FlutterError(code: "UPLOAD_FAILED", message: error.localizedDescription, details: nil))
                    self?.eventSink?([
                        "uploadId": uploadId,
                        "status": "failed",
                        "progress": 0,
                        "error": error.localizedDescription,
                    ])
                } else {
                    let url = "https://\(bucketName).s3.\(regionName).amazonaws.com/\(key)"
                    print("✅ [AwsUploaderPlugin] Upload completed — url: \(url)")
                    sendResult([
                        "uploadId": uploadId,
                        "url": url,
                        "bucket": bucketName,
                        "key": key,
                        "fileName": fileName,
                        "filePath": fileURL.path,
                    ])
                    self?.eventSink?([
                        "uploadId": uploadId,
                        "status": "completed",
                        "progress": 100,
                        "url": url,
                    ])
                }
                self?.uploads.removeValue(forKey: uploadId)
                print("🔧 [AwsUploaderPlugin] Upload task removed from tracking — uploadId: \(uploadId)")
            }
        }.continueWith { [weak self] task -> Any? in
            if let uploadTask = task.result {
                self?.uploads[uploadId] = uploadTask
                print("✅ [AwsUploaderPlugin] Upload task tracked — uploadId: \(uploadId)")
            } else if let error = task.error {
                print("❌ [AwsUploaderPlugin] continueWith error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    sendFailure(code: "UPLOAD_START_FAILED", message: error.localizedDescription)
                }
            } else {
                print("⚠️ [AwsUploaderPlugin] continueWith — task.result is nil")
                DispatchQueue.main.async {
                    sendFailure(code: "UPLOAD_START_FAILED", message: "Upload failed to start")
                }
            }
            return nil
        }
    }

    private func cancelUpload(uploadId: String) {
        print("🔧 [AwsUploaderPlugin] cancelUpload — uploadId: \(uploadId)")
        if let task = uploads[uploadId] {
            task.cancel()
            uploads.removeValue(forKey: uploadId)
            print("✅ [AwsUploaderPlugin] Upload cancelled")
        } else {
            print("⚠️ [AwsUploaderPlugin] cancelUpload — no task found for uploadId: \(uploadId)")
        }
    }
}
