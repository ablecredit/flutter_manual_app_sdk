package com.ablecredit.manual_flutter_app

import android.util.Log
import android.widget.Toast
import com.google.gson.Gson
import com.ablecredit.sdk.manager.AbleCredit
import com.ablecredit.sdk.model.constants.AbleCreditErrorCodes
import com.ablecredit.sdk.model.AbleCreditDockedButton
import com.ablecredit.sdk.model.AbleCreditFileStatus
import com.ablecredit.sdk.model.AbleCreditFileUploadListener
import com.ablecredit.sdk.model.AbleCreditFlowConfig
import com.ablecredit.sdk.model.AbleCreditFlowListener
import com.ablecredit.sdk.model.AbleCreditFlowStep
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
    private var flutterChannel: MethodChannel? = null

    // Holds the pending MethodChannel.Result for the currently open SDK screen so
    // the docked button's onClick can resolve it early (before a terminal upload status)
    // when the user taps "client screen" and the activity needs to finish first.
    private var pendingCaptureResult: MethodChannel.Result? = null

    override fun onResume() {
        super.onResume()
        // If MainActivity regains focus while a pendingCaptureResult is still set, it means the
        // SDK screen was dismissed via back press (not via docked button or terminal upload status).
        // Resolve it with CANCELLED so Flutter's awaiting _callStep() unblocks.
        val pending = pendingCaptureResult
        if (pending != null) {
            pendingCaptureResult = null
            pending.success(mapOf("success" to false, "status" to AbleCreditFileStatus.CANCELLED.name))
        }
    }

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

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        flutterChannel = channel
        channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "configure" -> {
                        val sdkKey = call.argument<String>("sdkKey").orEmpty()
                        val tenantId = call.argument<String>("tenantId").orEmpty()
                        val userId = call.argument<String>("userId").orEmpty()
                        val baseUrl = call.argument<String>("baseUrl").orEmpty()
                        val branchId = call.argument<String>("branchId")?.takeIf { it.isNotBlank() }
                        Thread {
                            val configResult = AbleCredit.configure(
                                this,
                                sdkKey,
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
                    "getLoanById" -> {
                        val applicationId = call.argument<String>("applicationId").orEmpty()
                        AbleCredit.getLoanById(this, applicationId) { sdkResult ->
                            result.success(serializeLoanResult(sdkResult))
                        }
                    }
                    "getLoanByReference" -> {
                        val loanReference = call.argument<String>("loanReference").orEmpty()
                        AbleCredit.getLoanByReference(this, loanReference) { sdkResult ->
                            result.success(serializeLoanResult(sdkResult))
                        }
                    }
                    "requestReportGeneration" -> {
                        val loanApplicationId = call.argument<String>("loanApplicationId").orEmpty()
                        AbleCredit.requestReportGeneration(this, loanApplicationId) { sdkResult ->
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
                        result.success(mapOf("success" to false, "message" to "viewLoanApplications is not supported in this SDK version"))
                    }
                    "recordAudio" -> {
                        val loanApplicationId = call.argument<String>("loanApplicationId")
                        val dockedButton = buildDockedButton(call.argument("nextStep"), call.argument("nextStepLabel"), loanApplicationId, call.argument("transition"))
                        AbleCredit.recordAudio(
                            context = this,
                            loanApplicationId = loanApplicationId,
                            listener = captureListener("audio", result),
                            dockedButton = dockedButton,
                        )
                    }
                    "captureFamilyPhotos" -> {
                        val loanApplicationId = call.argument<String>("loanApplicationId")
                        val dockedButton = buildDockedButton(call.argument("nextStep"), call.argument("nextStepLabel"), loanApplicationId, call.argument("transition"))
                        AbleCredit.captureFamilyPhotos(this, loanApplicationId, captureListener("family_photos", result), dockedButton)
                    }
                    "captureBusinessPhotos" -> {
                        val loanApplicationId = call.argument<String>("loanApplicationId")
                        val dockedButton = buildDockedButton(call.argument("nextStep"), call.argument("nextStepLabel"), loanApplicationId, call.argument("transition"))
                        AbleCredit.captureBusinessPhotos(this, loanApplicationId, captureListener("business_photos", result), dockedButton)
                    }
                    "captureCollateralPhotos" -> {
                        val loanApplicationId = call.argument<String>("loanApplicationId")
                        val dockedButton = buildDockedButton(call.argument("nextStep"), call.argument("nextStepLabel"), loanApplicationId, call.argument("transition"))
                        AbleCredit.captureCollateralPhotos(this, loanApplicationId, captureListener("collateral_photos", result), dockedButton)
                    }
                    "startLoanFlow" -> {
                        val stepNames = call.argument<List<String>>("steps") ?: emptyList()
                        val useExistingLoan = call.argument<Boolean>("useExistingLoan") ?: false
                        val existingLoanReference = call.argument<String>("existingLoanApplicationId")
                        val payload = call.argument<Map<String, Any?>>("payload") ?: emptyMap()

                        val steps = stepNames.mapNotNull { name ->
                            runCatching { AbleCreditFlowStep.valueOf(name) }.getOrNull()
                        }
                        if (steps.isEmpty()) {
                            result.success(mapOf("success" to false, "message" to "No valid flow steps provided"))
                            return@setMethodCallHandler
                        }

                        val flowListener = object : AbleCreditFlowListener {
                            override fun onLoanCreated(applicationId: String, response: AbleCreditLoanResponse) {
                                Log.d("AbleCredit", "Flow onLoanCreated: applicationId=$applicationId")
                                val loanRef = try {
                                    response.data?.application?.loan_reference.orEmpty()
                                } catch (_: Exception) { "" }
                                runOnUiThread {
                                    audioStatusSink?.success(mapOf(
                                        "type" to "loan_created",
                                        "applicationId" to applicationId,
                                        "loanReference" to loanRef
                                    ))
                                }
                            }

                            override fun onFileStatusChanged(
                                step: AbleCreditFlowStep,
                                uniqueId: String,
                                status: AbleCreditFileStatus,
                                message: String?
                            ) {
                                showToast("flow_${step.name}", status, message)
                                audioStatusSink?.success(mapOf(
                                    "type" to "flow_${step.name}",
                                    "uniqueId" to uniqueId,
                                    "status" to status.name,
                                    "message" to message
                                ))
                            }

                            override fun onFlowCompleted(applicationId: String) {
                                Log.d("AbleCredit", "Flow completed: applicationId=$applicationId")
                            }

                            override fun onFlowFailed(step: AbleCreditFlowStep, error: AbleCreditResult.Failure) {
                                Log.e("AbleCredit", "Flow failed at step=$step: ${error.message}")
                            }

                            override fun onStepCompleted(step: AbleCreditFlowStep) {
                                Log.d("AbleCredit", "Flow step completed: $step")
                            }
                        }

                        try {
                            val config = if (useExistingLoan) {
                                // Existing-loan flows must NOT include CREATE_LOAN_CASE.
                                val existingSteps = steps.filter { it != AbleCreditFlowStep.CREATE_LOAN_CASE }
                                AbleCreditFlowConfig.Builder()
                                    .steps(*existingSteps.toTypedArray())
                                    .listener(flowListener)
                                    .withExistingLoan(existingLoanReference.orEmpty())
                            } else {
                                // New-loan flows require CREATE_LOAN_CASE to be explicitly configured.
                                // If the org did not enable it in Profile → Flow config, block the call.
                                if (!steps.contains(AbleCreditFlowStep.CREATE_LOAN_CASE)) {
                                    result.success(mapOf(
                                        "success" to false,
                                        "message" to "\"Create loan case\" is not enabled in Profile → Flow config. Enable it or use Existing loan mode."
                                    ))
                                    return@setMethodCallHandler
                                }
                                val newSteps = mutableListOf(AbleCreditFlowStep.CREATE_LOAN_CASE)
                                newSteps.addAll(steps.filter { it != AbleCreditFlowStep.CREATE_LOAN_CASE })
                                AbleCreditFlowConfig.Builder()
                                    .steps(*newSteps.toTypedArray())
                                    .listener(flowListener)
                                    .withNewLoan(payload)
                            }
                            AbleCredit.startLoanFlow(this, config)
                            result.success(mapOf("success" to true))
                        } catch (e: IllegalArgumentException) {
                            result.success(mapOf("success" to false, "message" to e.message))
                        }
                    }
                    "setShowSdkHeader" -> {
                        val show = call.argument<Boolean>("show") ?: true
                        AbleCredit.setShowSdkHeader(show)
                        result.success(mapOf("success" to true))
                    }
                    "setSdkToastsEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: true
                        AbleCredit.setSdkToastsEnabled(enabled)
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

    /**
     * Builds a docked button for the current SDK screen.
     *
     * - [nextStep] null → no docked button (last step).
     * - [transition] "direct" → button launches [nextStep] SDK screen directly from native.
     * - [transition] "clientScreen" → button resolves the pending Flutter result with
     *   {dockedButton:true} and finishes the SDK activity. Flutter comes to the foreground,
     *   sees the dockedButton flag, and pushes MockClientScreen. The user taps Continue
     *   which calls the next SDK step via the bridge.
     */
    private fun buildDockedButton(
        nextStep: String?,
        nextStepLabel: String?,
        loanApplicationId: String?,
        transition: String?,
    ): AbleCreditDockedButton? {
        if (nextStep == null) return null
        val isGenerateReport = nextStep == "generateReport"
        val label = when {
            isGenerateReport -> nextStepLabel ?: "Generate report"
            nextStepLabel != null -> "$nextStepLabel →"
            else -> "Next →"
        }

        return when (transition) {
            "clientScreen" -> AbleCreditDockedButton(
                label = "Next: client screen →",
                onClick = { ctx ->
                    // Resolve Flutter's awaiting result first, then finish the SDK
                    // activity so Flutter comes to the foreground.
                    val pending = pendingCaptureResult
                    pendingCaptureResult = null
                    pending?.success(mapOf(
                        "success" to true,
                        "status" to "DOCKED_BUTTON",
                        "nextStep" to nextStep,
                        "nextStepLabel" to (nextStepLabel ?: nextStep),
                    ))
                    if (ctx is android.app.Activity) ctx.finish()
                }
            )
            else -> if (isGenerateReport) {
                AbleCreditDockedButton(
                    label = label,
                    isGenerateReport = true,
                    onClick = { ctx ->
                        if (!loanApplicationId.isNullOrBlank()) {
                            AbleCredit.requestReportGeneration(ctx, loanApplicationId) { result ->
                                val msg = when (result) {
                                    is AbleCreditResult.Success -> "Report requested successfully"
                                    is AbleCreditResult.Failure -> "Report failed: ${result.message}"
                                    else -> null
                                }
                                if (msg != null) runOnUiThread {
                                    android.widget.Toast.makeText(ctx, msg, android.widget.Toast.LENGTH_SHORT).show()
                                }
                            }
                        }
                    }
                )
            } else {
                AbleCreditDockedButton(label = label, onClick = { ctx ->
                    when (nextStep) {
                        "recordAudio" -> AbleCredit.recordAudio(ctx, loanApplicationId)
                        "captureBusinessPhotos" -> AbleCredit.captureBusinessPhotos(ctx, loanApplicationId)
                        "captureFamilyPhotos" -> AbleCredit.captureFamilyPhotos(ctx, loanApplicationId)
                        "captureCollateralPhotos" -> AbleCredit.captureCollateralPhotos(ctx, loanApplicationId)
                    }
                })
            }
        }
    }

    /**
     * Returns a listener that resolves Flutter's [result] exactly once on a terminal status.
     * Also registers [result] as [pendingCaptureResult] so the clientScreen docked button
     * can resolve it early (before upload completes) when the user taps to show the client screen.
     */
    private fun captureListener(type: String, result: MethodChannel.Result): AbleCreditFileUploadListener {
        pendingCaptureResult = result
        var resolved = false
        return object : AbleCreditFileUploadListener {
            override fun onStatusChanged(uniqueId: String, status: AbleCreditFileStatus, message: String?) {
                showToast(type, status, message)
                audioStatusSink?.success(mapOf(
                    "type" to type,
                    "uniqueId" to uniqueId,
                    "status" to status.name,
                    "message" to message,
                ))
                val isTerminal = status == AbleCreditFileStatus.UPLOADED
                    || status == AbleCreditFileStatus.FAILED
                    || status == AbleCreditFileStatus.CANCELLED
                if (isTerminal && !resolved) {
                    // Only resolve if the docked button hasn't already resolved it.
                    if (pendingCaptureResult === result) {
                        pendingCaptureResult = null
                        resolved = true
                        runOnUiThread {
                            result.success(mapOf("success" to (status == AbleCreditFileStatus.UPLOADED), "status" to status.name))
                        }
                    }
                }
            }
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
