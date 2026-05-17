package com.example.tappay

import android.content.Context
import android.content.Intent
import android.nfc.cardemulation.HostApduService
import android.os.Bundle

class TapPayHceService : HostApduService() {

    override fun processCommandApdu(commandApdu: ByteArray, extras: Bundle?): ByteArray {
        // Respond to any SELECT AID command (CLA=00, INS=A4)
        if (commandApdu.size >= 2 &&
            commandApdu[0] == 0x00.toByte() &&
            commandApdu[1] == 0xA4.toByte()
        ) {
            val token = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .getString(TOKEN_KEY, null)

            return if (token != null) {
                val tokenBytes = token.toByteArray(Charsets.UTF_8)
                // Response: [token bytes] + SW 90 00 (success)
                tokenBytes + byteArrayOf(0x90.toByte(), 0x00.toByte())
            } else {
                // 6A 82 = File not found — token not set yet
                byteArrayOf(0x6A.toByte(), 0x82.toByte())
            }
        }
        // Unknown command
        return byteArrayOf(0x00.toByte(), 0x00.toByte())
    }

    override fun onDeactivated(reason: Int) {
        // Fires when the phones separate after a tap — notify the Flutter layer
        sendBroadcast(Intent(ACTION_TAP_COMPLETE))
    }

    companion object {
        const val PREFS_NAME       = "tappay_hce"
        const val TOKEN_KEY        = "payment_token"
        const val ACTION_TAP_COMPLETE = "com.example.tappay.HCE_TAP_COMPLETE"
    }
}
