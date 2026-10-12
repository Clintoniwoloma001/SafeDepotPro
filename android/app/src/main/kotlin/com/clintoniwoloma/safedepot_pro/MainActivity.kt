// © Flatra Tech Ltd. All rights reserved.
// Designed and developed by Clinton Iwoloma — The Imaginr, CEO, Flatra Tech Ltd.
// Proprietary and confidential. Unauthorized copying, modification, distribution or reuse is prohibited.
// Contact: +2349025975247

package com.clintoniwoloma.safedepot_pro

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest

/**
 * Reports the SHA-256 of the certificate that signed this installed APK.
 *
 * The Dart side compares this against the allow-list held in `app_builds`, so a
 * repackaged build signed with someone else's key produces a fingerprint that
 * no server-side row authorises. This is a *detection* signal rather than
 * containment: it is read from the same device that could be rooted, which is
 * why the server remains the authority.
 *
 * Values are returned without `:` separators and upper-cased, matching the
 * format stored in `app_builds.cert_fingerprint`.
 */
class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            INTEGRITY_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "signingCertificates" -> {
                    val fingerprints = signingCertificates()
                    if (fingerprints.isEmpty()) {
                        result.error(
                            "UNAVAILABLE",
                            "Could not read signing certificates",
                            null,
                        )
                    } else {
                        result.success(fingerprints)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun signingCertificates(): List<String> {
        return try {
            @Suppress("DEPRECATION")
            val packageInfo = applicationContext.packageManager.getPackageInfo(
                applicationContext.packageName,
                PackageManager.GET_SIGNING_CERTIFICATES,
            )
            val signatures = packageInfo.signingInfo?.apkContentsSigners
                ?: return emptyList()
            signatures.map { signature ->
                val digest = MessageDigest.getInstance("SHA-256")
                    .digest(signature.toByteArray())
                digest.joinToString("") { "%02X".format(it) }
            }
        } catch (e: Exception) {
            emptyList()
        }
    }

    private companion object {
        const val INTEGRITY_CHANNEL = "com.clintoniwoloma.safedepot_pro/integrity"
    }
}
