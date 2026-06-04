package com.uqbrijesh.aws.uploader

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import android.content.Context
import androidx.annotation.NonNull
import com.amazonaws.auth.CognitoCachingCredentialsProvider
import com.amazonaws.mobileconnectors.s3.transferutility.*
import com.amazonaws.mobileconnectors.s3.transferutility.TransferListener
import com.amazonaws.mobileconnectors.s3.transferutility.TransferObserver
import com.amazonaws.mobileconnectors.s3.transferutility.TransferState
import com.amazonaws.mobileconnectors.s3.transferutility.TransferUtility
import com.amazonaws.mobileconnectors.s3.transferutility.TransferNetworkLossHandler
import com.amazonaws.regions.Region
import com.amazonaws.regions.Regions
import com.amazonaws.services.s3.AmazonS3Client
import com.amazonaws.services.s3.model.ObjectMetadata

import java.io.File
import java.util.concurrent.atomic.AtomicBoolean

class AwsUploaderPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private lateinit var context: Context
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    private var transferUtility: TransferUtility? = null
    private val uploads = mutableMapOf<String, TransferObserver>()

    private fun parseRegion(region: String?): Regions? {
        return try {
            if (region.isNullOrEmpty()) null else Regions.fromName(region)
        } catch (e: Exception) {
            null
        }
    }

    private fun getMimeType(filePath: String): String {
        return when (filePath.substringAfterLast('.', "").lowercase()) {
            "jpg", "jpeg" -> "image/jpeg"
            "png" -> "image/png"
            "gif" -> "image/gif"
            "webp" -> "image/webp"
            "heic", "heif" -> "image/heic"
            "pdf" -> "application/pdf"
            "mp4" -> "video/mp4"
            "mov" -> "video/quicktime"
            "avi" -> "video/x-msvideo"
            "mkv" -> "video/x-matroska"
            "mp3" -> "audio/mpeg"
            "aac" -> "audio/aac"
            "wav" -> "audio/wav"
            "ogg" -> "audio/ogg"
            "txt" -> "text/plain"
            "html", "htm" -> "text/html"
            "csv" -> "text/csv"
            "doc" -> "application/msword"
            "docx" -> "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
            "xls" -> "application/vnd.ms-excel"
            "xlsx" -> "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
            "ppt" -> "application/vnd.ms-powerpoint"
            "pptx" -> "application/vnd.openxmlformats-officedocument.presentationml.presentation"
            "zip" -> "application/zip"
            "tar" -> "application/x-tar"
            "gz" -> "application/gzip"
            else -> "application/octet-stream"
        }
    }

    override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        methodChannel = MethodChannel(binding.binaryMessenger, "aws_uploader")
        eventChannel = EventChannel(binding.binaryMessenger, "aws_uploader_progress")
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: MethodChannel.Result) {
        when (call.method) {
            "startFileUpload" -> {
                val args = call.arguments as? Map<*, *>
                if (args == null) {
                    result.error("INVALID_ARGS", "Missing arguments", null)
                    return
                }
                startFileUpload(args, result)
            }
            "cancelUpload" -> {
                val args = call.arguments as? Map<*, *>
                val uploadId = args?.get("uploadId") as? String
                if (uploadId == null) {
                    result.error("INVALID_ARGS", "Missing uploadId", null)
                    return
                }
                val observer = uploads[uploadId]
                if (observer != null && transferUtility != null) {
                    transferUtility!!.cancel(observer.id)
                    uploads.remove(uploadId)
                }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun startFileUpload(args: Map<*, *>, result: MethodChannel.Result) {
        val uploadId       = args["uploadId"]       as? String ?: ""
        val bucketName     = args["bucketName"]     as? String ?: ""
        val filePath       = args["filePath"]       as? String ?: ""
        val fileName       = args["fileName"]       as? String ?: ""
        val uploadFolder   = args["uploadFolder"]   as? String ?: ""
        val regionName     = args["region"]         as? String
        val identityPoolId = args["identityPoolId"] as? String ?: ""
        val awsToken       = args["awsToken"]       as? String ?: ""
        val awsIdentityId  = args["identityId"]     as? String ?: ""
        val providerName   = args["providerName"]   as? String ?: ""
        val contentType    = args["contentType"]    as? String ?: getMimeType(filePath)

        if (uploadId.isEmpty() || bucketName.isEmpty() || filePath.isEmpty() ||
            fileName.isEmpty() || uploadFolder.isEmpty() || identityPoolId.isEmpty() ||
            awsToken.isEmpty() || awsIdentityId.isEmpty() || providerName.isEmpty()
        ) {
            result.error("INVALID_ARGS", "Missing required arguments for AWS upload", null)
            return
        }

        val file = File(filePath)
        if (!file.exists()) {
            result.error("INVALID_FILE", "File does not exist at path: $filePath", null)
            return
        }

        val region = parseRegion(regionName)
        if (region == null) {
            result.error("INVALID_REGION", "Region is null or invalid: $regionName", null)
            return
        }

        TransferNetworkLossHandler.getInstance(context)

        try {
            val developerProvider = DeveloperAuthenticationProvider(
                awsToken = awsToken,
                awsIdentityId = awsIdentityId,
                providerName = providerName,
                accountId = null,
                identityPoolId = identityPoolId,
                region = region
            )

            val credentialsProvider = CognitoCachingCredentialsProvider(
                context, developerProvider, region
            )

            val s3Client = AmazonS3Client(credentialsProvider, Region.getRegion(regionName))

            transferUtility = TransferUtility.builder()
                .context(context)
                .s3Client(s3Client)
                .build()

            val key = "$uploadFolder/$fileName"

            val metadata = ObjectMetadata()
            metadata.contentType = contentType

            val observer = transferUtility!!.upload(bucketName, key, file, metadata)
            uploads[uploadId] = observer

            // AtomicBoolean ensures only one callback (COMPLETED, FAILED, or onError)
            // calls result() even if multiple listener methods fire from different threads.
            val resultSent = AtomicBoolean(false)

            observer.setTransferListener(object : TransferListener {
                override fun onStateChanged(id: Int, state: TransferState?) {
                    when (state) {
                        TransferState.COMPLETED -> {
                            if (resultSent.compareAndSet(false, true)) {
                                val url = "https://$bucketName.s3.$regionName.amazonaws.com/$key"
                                result.success(
                                    mapOf(
                                        "uploadId" to uploadId,
                                        "url"      to url,
                                        "bucket"   to bucketName,
                                        "key"      to key,
                                        "fileName" to fileName,
                                        "filePath" to filePath,
                                    )
                                )
                                eventSink?.success(
                                    mapOf(
                                        "uploadId" to uploadId,
                                        "status"   to "completed",
                                        "progress" to 100,
                                        "url"      to url,
                                    )
                                )
                                uploads.remove(uploadId)
                            }
                        }
                        TransferState.FAILED -> {
                            if (resultSent.compareAndSet(false, true)) {
                                result.error("UPLOAD_FAILED", "Upload failed", null)
                                eventSink?.success(
                                    mapOf(
                                        "uploadId" to uploadId,
                                        "status"   to "failed",
                                        "progress" to 0,
                                    )
                                )
                                uploads.remove(uploadId)
                            }
                        }
                        else -> {}
                    }
                }

                override fun onProgressChanged(id: Int, bytesCurrent: Long, bytesTotal: Long) {
                    val progress = if (bytesTotal > 0) (bytesCurrent * 100 / bytesTotal).toInt() else 0
                    eventSink?.success(
                        mapOf(
                            "uploadId" to uploadId,
                            "status"   to "progress",
                            "progress" to progress,
                        )
                    )
                }

                override fun onError(id: Int, ex: Exception?) {
                    // Guard eventSink too — prevents a spurious "failed" event firing
                    // after a "completed" event when both COMPLETED and onError are called.
                    if (resultSent.compareAndSet(false, true)) {
                        result.error("UPLOAD_ERROR", ex?.message ?: "Unknown upload error", null)
                        eventSink?.success(
                            mapOf(
                                "uploadId" to uploadId,
                                "status"   to "failed",
                                "progress" to 0,
                                "error"    to (ex?.message ?: "Unknown error"),
                            )
                        )
                        uploads.remove(uploadId)
                    }
                }
            })

        } catch (e: Exception) {
            result.error("UPLOAD_INIT_FAILED", "Failed to initialize AWS upload: ${e.message}", null)
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }
}
