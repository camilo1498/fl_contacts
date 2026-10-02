package co.quis.fl_contacts

import android.content.ContentValues
import android.content.ContentResolver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.BlockedNumberContract
import android.telephony.PhoneNumberUtils
import android.telephony.TelephonyManager

/** System number blocking via [BlockedNumberContract] (API 24+).
 *
 * All operations require the app to be the default dialer/SMS app or hold
 * carrier privileges; callers translate refusal into `security_error`.
 */
object BlockedNumbers {
    /** Whether the current user is allowed to manage blocked numbers. */
    fun isAvailable(context: Context): Boolean {
        return try {
            BlockedNumberContract.canCurrentUserBlockNumbers(context)
        } catch (e: Exception) {
            false
        }
    }

    /** Whether [number] is blocked (original or E.164 form). */
    fun isBlocked(context: Context, number: String): Boolean {
        return BlockedNumberContract.isBlocked(context, number)
    }

    /** Every blocked number with its E.164 form when derivable. */
    fun getAll(resolver: ContentResolver, context: Context): List<Map<String, Any?>> {
        val cursor = resolver.query(
            BlockedNumberContract.BlockedNumbers.CONTENT_URI,
            arrayOf(
                BlockedNumberContract.BlockedNumbers.COLUMN_ORIGINAL_NUMBER,
                BlockedNumberContract.BlockedNumbers.COLUMN_E164_NUMBER
            ),
            null,
            null,
            null
        ) ?: return listOf()
        cursor.use {
            val out = mutableListOf<Map<String, Any?>>()
            val originalCol = cursor.getColumnIndexOrThrow(
                BlockedNumberContract.BlockedNumbers.COLUMN_ORIGINAL_NUMBER
            )
            val e164Col = cursor.getColumnIndexOrThrow(
                BlockedNumberContract.BlockedNumbers.COLUMN_E164_NUMBER
            )
            while (cursor.moveToNext()) {
                out.add(
                    mapOf(
                        "number" to (cursor.getString(originalCol) ?: ""),
                        "normalizedNumber" to (cursor.getString(e164Col) ?: ""),
                        "label" to "blocked",
                        "customLabel" to "",
                        "isPrimary" to false
                    )
                )
            }
            return out
        }
    }

    /** Blocks every number, storing the original plus the E.164 form. */
    fun blockAll(resolver: ContentResolver, context: Context, numbers: List<String>) {
        val countryIso = (context.getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager)
            ?.networkCountryIso?.uppercase()
        for (number in numbers) {
            val values = ContentValues()
            values.put(BlockedNumberContract.BlockedNumbers.COLUMN_ORIGINAL_NUMBER, number)
            val e164 = if (countryIso != null) {
                PhoneNumberUtils.formatNumberToE164(number, countryIso)
            } else {
                null
            }
            if (e164 != null) {
                values.put(BlockedNumberContract.BlockedNumbers.COLUMN_E164_NUMBER, e164)
            }
            resolver.insert(BlockedNumberContract.BlockedNumbers.CONTENT_URI, values)
        }
    }

    /** Unblocks every number (both stored forms). */
    fun unblockAll(resolver: ContentResolver, numbers: List<String>) {
        for (number in numbers) {
            resolver.delete(
                BlockedNumberContract.BlockedNumbers.CONTENT_URI,
                "${BlockedNumberContract.BlockedNumbers.COLUMN_ORIGINAL_NUMBER}=? OR " +
                    "${BlockedNumberContract.BlockedNumbers.COLUMN_E164_NUMBER}=?",
                arrayOf(number, number)
            )
        }
    }

    /** Opens the system screen where the user picks a default dialer. */
    fun openDefaultAppSettings(context: Context) {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            Intent(android.provider.Settings.ACTION_MANAGE_DEFAULT_APPS_SETTINGS)
        } else {
            Intent(android.provider.Settings.ACTION_SETTINGS)
        }
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
    }
}
