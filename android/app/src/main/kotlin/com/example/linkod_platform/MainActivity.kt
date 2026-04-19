package com.example.linkod_platform

import android.app.NotificationManager
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import org.json.JSONObject
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	companion object {
		private const val OVERLAY_CHANNEL = "linkod.overlay_control"
		private const val EXTRA_OVERLAY_PAYLOAD = "overlayAnnouncementPayload"
		private var overlayView: View? = null
		private var pendingOverlayPayload: String? = null
	}

	override fun onCreate(savedInstanceState: Bundle?) {
		super.onCreate(savedInstanceState)
		captureOverlayPayload(intent)
	}

	override fun onNewIntent(intent: Intent) {
		super.onNewIntent(intent)
		setIntent(intent)
		captureOverlayPayload(intent)
	}

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(
			flutterEngine.dartExecutor.binaryMessenger,
			"linkod.notification_capabilities",
		).setMethodCallHandler { call, result ->
			when (call.method) {
				"canUseFullScreenIntent" -> {
					if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
						val notificationManager = getSystemService(NotificationManager::class.java)
						result.success(notificationManager?.canUseFullScreenIntent() == true)
					} else {
						result.success(true)
					}
				}
				"openFullScreenIntentSettings" -> {
					try {
						val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
							Intent("android.settings.MANAGE_APP_USE_FULL_SCREEN_INTENT").apply {
								data = Uri.parse("package:$packageName")
								addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
							}
						} else {
							Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
								putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
								addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
							}
						}
						startActivity(intent)
						result.success(true)
					} catch (_: Throwable) {
						result.success(false)
					}
				}
				"openNotificationSettings" -> {
					try {
						val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
							putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
							addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
						}
						startActivity(intent)
						result.success(true)
					} catch (_: Throwable) {
						result.success(false)
					}
				}
				"showAnnouncementAlertActivity" -> {
					try {
						val rawArgs = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
						val announcementId = rawArgs["announcementId"]?.toString() ?: ""
						val title = rawArgs["title"]?.toString() ?: "Barangay Announcement"
						val body = rawArgs["body"]?.toString() ?: "You have received a new announcement"
						
						if (announcementId.isEmpty()) {
							result.success(false)
							return@setMethodCallHandler
						}
						
						val intent = Intent(this, AnnouncementAlertActivity::class.java).apply {
							putExtra("announcementId", announcementId)
							putExtra("title", title)
							putExtra("body", body)
							flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
						}
						startActivity(intent)
						result.success(true)
					} catch (e: Exception) {
						result.success(false)
					}
				}
				else -> result.notImplemented()
			}
		}

		MethodChannel(
			flutterEngine.dartExecutor.binaryMessenger,
			OVERLAY_CHANNEL,
		).setMethodCallHandler { call, result ->
			when (call.method) {
				"showAnnouncementOverlay" -> {
					val rawArgs = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
					val payload = mapOf(
						"announcementId" to (rawArgs["announcementId"]?.toString() ?: ""),
						"title" to (rawArgs["title"]?.toString() ?: "Barangay Announcement"),
						"body" to (rawArgs["body"]?.toString() ?: "New barangay announcement."),
						"type" to (rawArgs["type"]?.toString() ?: "announcement"),
						"priority" to (rawArgs["priority"]?.toString() ?: "high"),
						"alertStyle" to (rawArgs["alertStyle"]?.toString() ?: "announcement_priority"),
						"attemptFullScreen" to (rawArgs["attemptFullScreen"]?.toString() ?: "true"),
					)
					if (payload["announcementId"].isNullOrEmpty()) {
						result.success(false)
						return@setMethodCallHandler
					}
					if (!Settings.canDrawOverlays(this)) {
						result.success(false)
						return@setMethodCallHandler
					}

					runOnUiThread {
						val payloadJson = JSONObject(payload).toString()
						val shown = showAnnouncementOverlay(payload, payloadJson)
						result.success(shown)
					}
				}
				"dismissAnnouncementOverlay" -> {
					runOnUiThread {
						dismissAnnouncementOverlay()
						result.success(true)
					}
				}
				"canDrawOverlay" -> {
					result.success(Settings.canDrawOverlays(this))
				}
				"requestOverlayPermission" -> {
					val intent = Intent(
						Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
						Uri.parse("package:$packageName"),
					)
					intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
					startActivity(intent)
					result.success(true)
				}
				"getInitialOverlayPayload" -> {
					val payload = pendingOverlayPayload
					pendingOverlayPayload = null
					result.success(payload)
				}
				else -> result.notImplemented()
			}
		}
	}

	private fun captureOverlayPayload(intent: Intent?) {
		if (intent == null) return
		val payload = intent.getStringExtra(EXTRA_OVERLAY_PAYLOAD)
		if (!payload.isNullOrEmpty()) {
			pendingOverlayPayload = payload
			intent.removeExtra(EXTRA_OVERLAY_PAYLOAD)
		}
	}

	private fun showAnnouncementOverlay(
		payload: Map<String, String>,
		payloadJson: String,
	): Boolean {
		if (overlayView != null) {
			dismissAnnouncementOverlay()
		}

		val windowManager = getSystemService(WINDOW_SERVICE) as? WindowManager ?: return false
		val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
			WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
		} else {
			@Suppress("DEPRECATION")
			WindowManager.LayoutParams.TYPE_PHONE
		}

		val root = LinearLayout(this).apply {
			orientation = LinearLayout.VERTICAL
			setBackgroundColor(0x80000000.toInt())
			gravity = Gravity.CENTER
			layoutParams = LinearLayout.LayoutParams(
				LinearLayout.LayoutParams.MATCH_PARENT,
				LinearLayout.LayoutParams.MATCH_PARENT,
			)
		}

		val card = LinearLayout(this).apply {
			orientation = LinearLayout.VERTICAL
			setPadding(dp(20), dp(20), dp(20), dp(16))
			setBackgroundColor(Color.WHITE)
			layoutParams = LinearLayout.LayoutParams(dp(320), LinearLayout.LayoutParams.WRAP_CONTENT)
		}

		val titleView = TextView(this).apply {
			text = payload["title"] ?: "Barangay Announcement"
			setTextColor(Color.parseColor("#1B5E20"))
			setTextSize(TypedValue.COMPLEX_UNIT_SP, 20f)
			typeface = Typeface.DEFAULT_BOLD
			gravity = Gravity.CENTER_HORIZONTAL
		}

		val bodyView = TextView(this).apply {
			text = payload["body"] ?: "New barangay announcement."
			setTextColor(Color.parseColor("#222222"))
			setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
			setPadding(0, dp(10), 0, dp(14))
			gravity = Gravity.CENTER_HORIZONTAL
		}

		val actionRow = LinearLayout(this).apply {
			orientation = LinearLayout.HORIZONTAL
			gravity = Gravity.END
		}

		val dismissBtn = Button(this).apply {
			text = "Dismiss"
			setOnClickListener {
				dismissAnnouncementOverlay()
			}
		}

		val viewBtn = Button(this).apply {
			text = "View"
			setOnClickListener {
				val launchIntent = Intent(this@MainActivity, MainActivity::class.java).apply {
					addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
					putExtra(EXTRA_OVERLAY_PAYLOAD, payloadJson)
				}
				startActivity(launchIntent)
				dismissAnnouncementOverlay()
			}
		}

		actionRow.addView(dismissBtn)
		actionRow.addView(viewBtn)

		card.addView(titleView)
		card.addView(bodyView)
		card.addView(actionRow)
		root.addView(card)

		val params = WindowManager.LayoutParams(
			WindowManager.LayoutParams.MATCH_PARENT,
			WindowManager.LayoutParams.MATCH_PARENT,
			type,
			WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
			android.graphics.PixelFormat.TRANSLUCENT,
		).apply {
			gravity = Gravity.CENTER
		}

		return try {
			windowManager.addView(root, params)
			overlayView = root
			true
		} catch (_: Throwable) {
			false
		}
	}

	private fun dismissAnnouncementOverlay() {
		val view = overlayView ?: return
		val windowManager = getSystemService(WINDOW_SERVICE) as? WindowManager ?: return
		try {
			windowManager.removeView(view)
		} catch (_: Throwable) {
			// Ignore detach failures when overlay is already gone.
		} finally {
			overlayView = null
		}
	}

	private fun dp(value: Int): Int {
		return TypedValue.applyDimension(
			TypedValue.COMPLEX_UNIT_DIP,
			value.toFloat(),
			resources.displayMetrics,
		).toInt()
	}
}
