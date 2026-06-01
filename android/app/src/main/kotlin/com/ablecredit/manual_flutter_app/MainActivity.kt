package com.ablecredit.manual_flutter_app

import android.util.Log
import android.widget.Toast
import com.google.gson.Gson
import com.ablecredit.sdk.manager.AbleCredit
import com.ablecredit.sdk.model.constants.AbleCreditErrorCodes
import com.ablecredit.sdk.model.AbleCreditFileStatus
import com.ablecredit.sdk.model.AbleCreditFileUploadListener
import com.ablecredit.sdk.model.AbleCreditLoanResponse
import com.ablecredit.sdk.model.AbleCreditResult
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val gson = Gson()
    private val channelName = "ablecredit/wrapper_sdk"
    private val audioStatusChannelName = "ablecredit/audio_upload_status"
    private var audioStatusSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, audioStatusChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    audioStatusSink = events
                }

                override fun onCancel(arguments: Any?) {
                    audioStatusSink = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "configure" -> {
                        val apiKey = call.argument<String>("apiKey").orEmpty()
                        val tenantId = call.argument<String>("tenantId").orEmpty()
                        val userId = call.argument<String>("userId").orEmpty()
                        val baseUrl = call.argument<String>("baseUrl").orEmpty()
                        val branchId = call.argument<String>("branchId")?.takeIf { it.isNotBlank() }
                        Thread {
                            val configResult = AbleCredit.configure(
                                this,
                                apiKey,
                                tenantId,
                                userId,
                                baseUrl,
                                branchId
                            )
                            runOnUiThread {
                                when (configResult) {
                                    is AbleCreditResult.Success -> result.success(
                                        mapOf("success" to true, "message" to "SDK configured")
                                    )
                                    is AbleCreditResult.Failure -> {
                                        if (configResult.ableCreditErrorCode == AbleCreditErrorCodes.SDK_ALREADY_INITIALIZED) {
                                            result.success(mapOf("success" to true, "message" to "SDK configured"))
                                        } else {
                                            result.success(
                                                mapOf(
                                                    "success" to false,
                                                    "message" to configResult.message,
                                                    "code" to configResult.ableCreditErrorCode.toString()
                                                )
                                            )
                                        }
                                    }
                                }
                            }
                        }.start()
                    }
                    "createNewLoanCase" -> {
                        val payload = call.argument<Map<String, Any?>>("payload") ?: emptyMap()
                        AbleCredit.createNewLoanCase(this, payload) { sdkResult ->
                            result.success(serializeLoanResult(sdkResult))
                        }
                    }
                    "fetchLoanDetails" -> {
                        val loanReference = call.argument<String>("loanReference").orEmpty()
                        AbleCredit.fetchLoanDetails(this, loanReference) { sdkResult ->
                            result.success(serializeLoanResult(sdkResult))
                        }
                    }
                    "requestReportGeneration" -> {
                        val id = call.argument<String>("loanApplicationId").orEmpty()
                        AbleCredit.requestReportGeneration(this, id) { sdkResult ->
                            when (sdkResult) {
                                is AbleCreditResult.Success -> result.success(mapOf("success" to true, "message" to sdkResult.message))
                                is AbleCreditResult.Failure -> result.success(mapOf(
                                    "success" to false,
                                    "message" to sdkResult.message,
                                    "code" to sdkResult.ableCreditErrorCode.toString()
                                ))
                            }
                        }
                    }
                    "viewLoanApplications" -> {
                        AbleCredit.viewLoanApplications(this)
                        result.success(mapOf("success" to true))
                    }
                    "recordAudio" -> {
                        val id = call.argument<String>("loanApplicationId")
                        AbleCredit.recordAudio(
                            context = this,
                            loanApplicationId = id,
                            listener = object : AbleCreditFileUploadListener {
                                override fun onStatusChanged(
                                    uniqueId: String,
                                    status: AbleCreditFileStatus,
                                    message: String?
                                ) {
                                    showToast("audio", status, message)
                                    audioStatusSink?.success(
                                        mapOf(
                                            "type" to "audio",
                                            "uniqueId" to uniqueId,
                                            "status" to status.name,
                                            "message" to message
                                        )
                                    )
                                }
                            }
                        )
                        result.success(mapOf("success" to true))
                    }
                    "captureFamilyPhotos" -> {
                        val id = call.argument<String>("loanApplicationId")
                        AbleCredit.captureFamilyPhotos(this, id, object : AbleCreditFileUploadListener {
                            override fun onStatusChanged(uniqueId: String, status: AbleCreditFileStatus, message: String?) {
                                showToast("family_photos", status, message)
                                audioStatusSink?.success(mapOf(
                                    "type" to "family_photos",
                                    "uniqueId" to uniqueId,
                                    "status" to status.name,
                                    "message" to message
                                ))
                            }
                        })
                        result.success(mapOf("success" to true))
                    }
                    "captureBusinessPhotos" -> {
                        val id = call.argument<String>("loanApplicationId")
                        AbleCredit.captureBusinessPhotos(this, id, object : AbleCreditFileUploadListener {
                            override fun onStatusChanged(uniqueId: String, status: AbleCreditFileStatus, message: String?) {
                                showToast("business_photos", status, message)
                                audioStatusSink?.success(mapOf(
                                    "type" to "business_photos",
                                    "uniqueId" to uniqueId,
                                    "status" to status.name,
                                    "message" to message
                                ))
                            }
                        })
                        result.success(mapOf("success" to true))
                    }
                    "captureCollateralPhotos" -> {
                        val id = call.argument<String>("loanApplicationId")
                        AbleCredit.captureCollateralPhotos(this, id, object : AbleCreditFileUploadListener {
                            override fun onStatusChanged(uniqueId: String, status: AbleCreditFileStatus, message: String?) {
                                showToast("collateral_photos", status, message)
                                audioStatusSink?.success(mapOf(
                                    "type" to "collateral_photos",
                                    "uniqueId" to uniqueId,
                                    "status" to status.name,
                                    "message" to message
                                ))
                            }
                        })
                        result.success(mapOf("success" to true))
                    }
                    "clearSdkData" -> {
                        AbleCredit.clearSdkData { sdkResult ->
                            when (sdkResult) {
                                is AbleCreditResult.Success -> result.success(mapOf("success" to true))
                                is AbleCreditResult.Failure -> result.success(mapOf("success" to false, "message" to sdkResult.message))
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * [AbleCreditLoanResponse] is not encodable by Flutter's [MethodChannel]; convert to nested maps/lists.
     */
    private fun serializeLoanResult(sdkResult: AbleCreditResult<AbleCreditLoanResponse>): Map<String, Any?> {
        return when (sdkResult) {
            is AbleCreditResult.Success -> {
                val loan = sdkResult.data
                val dataMap: Map<String, Any?>? = loan?.let(::loanResponseToFlutterMap)
                val applicationId = try {
                    loan?.data?.application?._id.orEmpty()
                } catch (_: Exception) {
                    ""
                }
                mapOf(
                    "success" to true,
                    "message" to (sdkResult.message ?: loan?.message ?: loan?.msg ?: "OK"),
                    "applicationId" to applicationId,
                    "data" to dataMap,
                )
            }

            is AbleCreditResult.Failure -> mapOf(
                "success" to false,
                "message" to sdkResult.message,
                "code" to sdkResult.ableCreditErrorCode.toString(),
            )
        }
    }

    private fun showToast(type: String, status: AbleCreditFileStatus, message: String?) {
        val label = when (status) {
            AbleCreditFileStatus.UPLOADED    -> "[$type] Uploaded"
            AbleCreditFileStatus.FAILED      -> "[$type] Failed: ${message ?: "unknown error"}"
            AbleCreditFileStatus.UPLOADING   -> "[$type] Uploading…"
            AbleCreditFileStatus.UPLOAD_PENDING -> "[$type] Upload pending"
            AbleCreditFileStatus.IN_PROGRESS -> "[$type] In progress"
            AbleCreditFileStatus.CREATED     -> "[$type] Created"
            AbleCreditFileStatus.CANCELLED   -> "[$type] Cancelled"
        }
        Log.d("AbleCredit", "showToast: $label")
        runOnUiThread {
            Toast.makeText(applicationContext, label, Toast.LENGTH_SHORT).show()
        }
    }

    @Suppress("UNCHECKED_CAST")
    private fun loanResponseToFlutterMap(loan: AbleCreditLoanResponse): Map<String, Any?> {
        return gson.fromJson(gson.toJson(loan), Map::class.java) as Map<String, Any?>
    }
}
