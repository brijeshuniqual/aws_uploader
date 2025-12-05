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
import com.amazonaws.services.s3.AmazonS3
import com.amazonaws.services.s3.AmazonS3Client

import java.io.File
import kotlin.collections.get

/**
 * AwsUploaderPlugin
 *
 * Flutter plugin to upload images to AWS S3 using Cognito credentials.
 * Supports:
 * - Upload progress events via EventChannel
 * - Cancel ongoing uploads
 * - Token & IdentityId based authenticated upload
 */
class AwsUploaderPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    /// Android Context
    private lateinit var context: Context

    /// Method channel for Flutter calls
    private lateinit var methodChannel: MethodChannel

    /// Event channel to send upload progress back to Flutter
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null

    /// AWS TransferUtility instance
    private var transferUtility: TransferUtility? = null

    /// Map of active uploads for cancellation
    private val uploads = mutableMapOf<String, TransferObserver>()

    /**
     * Convert region string to AWS Regions enum.
     * Defaults to null if invalid.
     */
    private fun parseRegion(region: String?): Regions? {
        return try {
            if (region.isNullOrEmpty()) null else Regions.fromName(region)
        } catch (e: Exception) {
            null
        }
    }

    /**
     * Called when the plugin is attached to the Flutter engine.
     * Sets up method and event channels.
     */
    override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        methodChannel = MethodChannel(binding.binaryMessenger, "aws_uploader")
        eventChannel = EventChannel(binding.binaryMessenger, "aws_uploader_progress")

        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
    }


    /**
     * Handle method calls from Flutter.
     * Supported methods: startImgUpload, cancelUpload
     */
    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: MethodChannel.Result) {
        when (call.method) {
            "startImgUpload" -> {
                val args = call.arguments as Map<*, *>
                startImgUpload(args, result)
            }
            "cancelUpload" -> {
                val uploadId = (call.arguments as Map<*, *>)["uploadId"] as String
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


    /**
     * Starts uploading an image to AWS S3.
     *
     * @param args Map of upload parameters including:
     * - uploadId: unique ID for this upload
     * - bucketName: S3 bucket
     * - filePath: local image path
     * - fileName: filename for S3
     * - imageUploadFolder: S3 folder
     * - region: AWS region
     * - identityPoolId, awsToken, awsIdentityId: Cognito credentials
     * - providerName: Cognito provider
     * @param result MethodChannel.Result to return status
     */
    private fun startImgUpload(args: Map<*, *>, result: MethodChannel.Result) {
        val uploadId = args["uploadId"] as String
        val bucketName = args["bucketName"] as String
        val filePath = args["filePath"] as String
        val fileName = args["fileName"] as String
        val imageUploadFolder = args["imageUploadFolder"] as String
        val regionName = args["region"] as? String
        val identityPoolId = args["identityPoolId"] as? String ?: ""
        val awsToken = args["awsToken"] as String
        val awsIdentityId = args["identityId"] as String
        val providerName = args["providerName"] as String

        if (uploadId.isNullOrEmpty() || bucketName.isNullOrEmpty() || filePath.isNullOrEmpty() ||
            fileName.isNullOrEmpty() || imageUploadFolder.isNullOrEmpty() ||
            awsToken.isNullOrEmpty() || awsIdentityId.isNullOrEmpty() || providerName.isNullOrEmpty()
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
            result.error("INVALID_REGION", "Region is null or invalid. Please provide a correct AWS region.", null)
            return
        }

        // Handle network loss automatically
        TransferNetworkLossHandler.getInstance(context)

        try {
            // DeveloperAuthenticationProvider for Cognito token-based authentication
            val developerProvider = DeveloperAuthenticationProvider(
                awsToken = awsToken,
                awsIdentityId = awsIdentityId,
                providerName = providerName,
                accountId = null,
                identityPoolId = identityPoolId,
                region = region
            )

            // Cognito credentials provider
            val credentialsProvider = CognitoCachingCredentialsProvider(
                context,
                developerProvider,
                region
            )

            // Amazon S3 client
            val s3Client = AmazonS3Client(credentialsProvider, Region.getRegion(regionName))

            // Initialize TransferUtility
            transferUtility = TransferUtility.builder()
                .context(context)
                .s3Client(s3Client)
                .build()

            // Start the upload
            val observer = transferUtility!!.upload(
                bucketName, "$imageUploadFolder/$fileName", File(filePath)
            )

            // Store observer for cancellation support
            uploads[uploadId] = observer

            // Listen for upload progress and status
            observer.setTransferListener(object : TransferListener {
                override fun onStateChanged(id: Int, state: TransferState?) {
                    when (state) {
                        TransferState.COMPLETED -> {
                            val url =
                                "https://$bucketName.s3.${regionName}.amazonaws.com/$imageUploadFolder/$fileName"

                            result.success(url)

                            eventSink?.success(
                                mapOf(
                                    "uploadId" to uploadId,
                                    "status" to "completed",
                                    "url" to url
                                )
                            )
                        }

                        TransferState.FAILED -> {
                            eventSink?.success(mapOf("uploadId" to uploadId, "status" to "failed"))
                        }

                        else -> {}
                    }
                }

                override fun onProgressChanged(id: Int, bytesCurrent: Long, bytesTotal: Long) {
                    val progress =
                        if (bytesTotal > 0) (bytesCurrent * 100 / bytesTotal).toInt() else 0
                    eventSink?.success(
                        mapOf(
                            "uploadId" to uploadId,
                            "status" to "progress",
                            "progress" to progress
                        )
                    )
                }

                override fun onError(id: Int, ex: Exception?) {
                    eventSink?.success(
                        mapOf(
                            "uploadId" to uploadId,
                            "status" to "failed",
                            "error" to ex?.message
                        )
                    )
                }
            })

        } catch (e: Exception) {
            e.printStackTrace()
            result.error(
                "UPLOAD_INIT_FAILED",
                "Failed to initialize AWS upload: ${e.message}",
                null
            )
        }
    }

    /** Start listening to EventChannel from Flutter */
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    /** Stop listening to EventChannel from Flutter */
    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    /** Cleanup when detached from Flutter engine */
    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }
}
