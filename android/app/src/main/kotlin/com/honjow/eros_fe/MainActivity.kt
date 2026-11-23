package com.honjow.eros_fe

import android.content.ComponentName
import android.content.Intent.FLAG_ACTIVITY_NEW_TASK
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.annotation.NonNull
import androidx.core.view.WindowCompat
import dev.darttools.flutter_android_volume_keydown.FlutterAndroidVolumeKeydownFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity: FlutterAndroidVolumeKeydownFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {

        if (intent.getIntExtra("org.chromium.chrome.extra.TASK_ID", -1) == this.taskId) {
            this.finish()
            intent.addFlags(FLAG_ACTIVITY_NEW_TASK);
            startActivity(intent);
        }

        // Aligns the Flutter view vertically with the window.
        WindowCompat.setDecorFitsSystemWindows(getWindow(), false)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Disable the Android splash screen fade out animation to avoid
            // a flicker before the similar frame is drawn in Flutter.
            splashScreen.setOnExitAnimationListener { splashScreenView -> splashScreenView.remove() }
        }

        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "eros/app_icon"
        ).setMethodCallHandler { call, result ->
            if (call.method != "setAppIcon") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val style = call.arguments as? String
            val targetAlias = when (style) {
                "auto", "monochrome" -> ".LauncherMonochrome"
                "light" -> ".LauncherLight"
                "dark" -> ".LauncherDark"
                "purple" -> ".LauncherPurple"
                else -> {
                    result.error(
                        "invalid_app_icon",
                        "Expected auto, light, dark, or purple",
                        null
                    )
                    return@setMethodCallHandler
                }
            }
            updateAppIconAlias(targetAlias, result)
        }
    }

    private fun updateAppIconAlias(targetAlias: String, result: MethodChannel.Result) {
        try {
            val pm = applicationContext.packageManager
            val defaultEnabledAlias = ".LauncherMonochrome"
            val aliases = listOf(
                ".LauncherMonochrome",
                ".LauncherLight",
                ".LauncherDark",
                ".LauncherPurple"
            )

            // Enable target alias first so a launcher entry always remains active.
            val targetComponent = ComponentName(
                applicationContext,
                "${packageName}$targetAlias"
            )
            val targetState = pm.getComponentEnabledSetting(targetComponent)
            val targetAlreadyEnabled =
                targetState == PackageManager.COMPONENT_ENABLED_STATE_ENABLED ||
                    (targetAlias == defaultEnabledAlias &&
                        targetState == PackageManager.COMPONENT_ENABLED_STATE_DEFAULT)
            if (!targetAlreadyEnabled) {
                pm.setComponentEnabledSetting(
                    targetComponent,
                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                    PackageManager.DONT_KILL_APP
                )
            }

            for (alias in aliases) {
                if (alias == targetAlias) continue
                val component = ComponentName(
                    applicationContext,
                    "${packageName}$alias"
                )
                val state = pm.getComponentEnabledSetting(component)
                val alreadyDisabled =
                    state == PackageManager.COMPONENT_ENABLED_STATE_DISABLED ||
                        (alias != defaultEnabledAlias &&
                            state == PackageManager.COMPONENT_ENABLED_STATE_DEFAULT)
                if (!alreadyDisabled) {
                    pm.setComponentEnabledSetting(
                        component,
                        PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                        PackageManager.DONT_KILL_APP
                    )
                }
            }

            result.success(null)
        } catch (e: Exception) {
            result.error("set_app_icon_failed", e.message, null)
        }
    }
}
