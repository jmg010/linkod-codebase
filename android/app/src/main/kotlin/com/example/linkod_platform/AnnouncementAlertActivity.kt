package com.example.linkod_platform

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.widget.Button
import android.widget.TextView
import android.widget.ImageView
import androidx.core.content.ContextCompat

/**
 * Full-screen announcement alert activity.
 * 
 * Displays a prominent alert for high-priority barangay announcements.
 * - Shows when FCM full-screen intent is triggered
 * - Respects device lock state (Android 10+)
 * - Provides "View" button to open announcement detail
 * - Provides "Dismiss" button to close alert
 * - Extracts announcement ID from intent extras
 */
class AnnouncementAlertActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Set green status bar color that channels from styles.xml
        setTheme(R.style.AnnouncementAlertTheme)
        setContentView(R.layout.activity_announcement_alert)
        
        // Extract announcement data from intent extras
        val announcementId = intent.extras?.getString("announcementId") ?: ""
        val title = intent.extras?.getString("title") ?: "Barangay Announcement"
        val body = intent.extras?.getString("body") ?: "You have received a new announcement"
        
        // Find views
        val titleText = findViewById<TextView>(R.id.titleText)
        val bodyText = findViewById<TextView>(R.id.bodyText)
        val infoIcon = findViewById<ImageView>(R.id.infoIcon)
        val viewButton = findViewById<Button>(R.id.viewButton)
        val dismissButton = findViewById<Button>(R.id.dismissButton)
        
        // Set text content
        titleText.text = title
        bodyText.text = body
        
        // Tint icon with green color
        infoIcon.setColorFilter(
            ContextCompat.getColor(this, R.color.linkod_green_primary),
            android.graphics.PorterDuff.Mode.SRC_IN
        )
        
        // View button: navigate to announcement detail 
        viewButton.setOnClickListener {
            if (announcementId.isNotEmpty()) {
                val mainActivityIntent = Intent(this, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    putExtra("type", "announcement")
                    putExtra("announcementId", announcementId)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                startActivity(mainActivityIntent)
            }
            finish()
        }
        
        // Dismiss button: close alert
        dismissButton.setOnClickListener {
            finish()
        }
    }
    
    override fun onBackPressed() {
        // Allow back button to dismiss the alert
        super.onBackPressed()
    }
}
