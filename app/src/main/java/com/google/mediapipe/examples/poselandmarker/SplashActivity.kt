package com.google.mediapipe.examples.poselandmarker

import android.annotation.SuppressLint
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.view.ViewTreeObserver
import androidx.appcompat.app.AppCompatActivity
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen

@SuppressLint("CustomSplashScreen")
class SplashActivity : AppCompatActivity() {

    // Set your desired minimum display time in milliseconds. 2500L = 2.5 seconds.
    private val MINIMUM_DISPLAY_TIME = 2500L

    override fun onCreate(savedInstanceState: Bundle?) {
        val splashScreen = installSplashScreen()
        super.onCreate(savedInstanceState)

        // We don't need a layout file for this modern approach
        // The theme handles the initial icon display.

        var keepShowing = true
        splashScreen.setKeepOnScreenCondition { keepShowing }

        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            keepShowing = false
            navigateToMain()
        }, MINIMUM_DISPLAY_TIME)
    }

    private fun navigateToMain() {
        val intent = Intent(this, MainActivity::class.java)
        startActivity(intent)
        finish() // Finish this activity so the user can't navigate back to it.
    }
}
