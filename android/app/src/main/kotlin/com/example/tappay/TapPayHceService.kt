package com.example.tappay

import android.content.Context
import android.content.Intent
import android.nfc.cardemulation.HostApduService
import android.os.Bundle
import android.util.Log

class TapPayHceService : HostApduService() {

    override fun processCommandApdu(commandApdu: ByteArray, extras: Bundle?): ByteArray {
        val apduHex = commandApdu.joinToString(" ") { "%02X".format(it) }
        Log.d(TAG, "APDU received (${commandApdu.size}B): $apduHex")

        if (commandApdu.size >= 2 &&
            commandApdu[0] == 0x00.toByte() &&
            commandApdu[1] == 0xA4.toByte()
        ) {
            Log.d(TAG, "SELECT AID command recognised")
            val token = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .getString(TOKEN_KEY, null)

            return if (token != null) {
                Log.d(TAG, "Token found (${token.length} chars) — responding 90 00")
                val tokenBytes = token.toByteArray(Charsets.UTF_8)
                tokenBytes + byteArrayOf(0x90.toByte(), 0x00.toByte())
            } else {
                Log.w(TAG, "No token in SharedPrefs — sender has not armed HCE yet (6A 82)")
                byteArrayOf(0x6A.toByte(), 0x82.toByte())
            }
        }

        Log.w(TAG, "Unknown APDU command — returning 00 00")
        return byteArrayOf(0x00.toByte(), 0x00.toByte())
    }

    override fun onDeactivated(reason: Int) {
        val reasonStr = if (reason == DEACTIVATION_LINK_LOSS) "LINK_LOSS" else "DESELECTED"
        Log.d(TAG, "onDeactivated — reason:$reasonStr — broadcasting tap_complete")
        sendBroadcast(Intent(ACTION_TAP_COMPLETE))
    }

    companion object {
        const val TAG              = "TapPayHCE"
        const val PREFS_NAME       = "tappay_hce"
        const val TOKEN_KEY        = "payment_token"
        const val ACTION_TAP_COMPLETE = "com.example.tappay.HCE_TAP_COMPLETE"
    }
}
