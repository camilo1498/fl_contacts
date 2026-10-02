package co.quis.fl_contacts

import android.database.Cursor
import android.provider.ContactsContract.CommonDataKinds.Email
import android.provider.ContactsContract.CommonDataKinds.Event
import android.provider.ContactsContract.CommonDataKinds.Im
import android.provider.ContactsContract.CommonDataKinds.Phone
import android.provider.ContactsContract.CommonDataKinds.StructuredPostal
import android.provider.ContactsContract.CommonDataKinds.Website

/** Bidirectional mappings between provider type codes and channel labels.
 *
 * Labels travel as plain strings over the channel; these helpers keep the
 * conversion in one place instead of scattered through queries and writes. */
internal fun getPhoneLabel(cursor: Cursor): String {
    val type = cursor.getInt(cursor.getColumnIndexOrThrow(Phone.TYPE))
    return when (type) {
        Phone.TYPE_ASSISTANT -> "assistant"
        Phone.TYPE_CALLBACK -> "callback"
        Phone.TYPE_CAR -> "car"
        Phone.TYPE_COMPANY_MAIN -> "companyMain"
        Phone.TYPE_FAX_HOME -> "faxHome"
        Phone.TYPE_FAX_WORK -> "faxWork"
        Phone.TYPE_HOME -> "home"
        Phone.TYPE_ISDN -> "isdn"
        Phone.TYPE_MAIN -> "main"
        Phone.TYPE_MMS -> "mms"
        Phone.TYPE_MOBILE -> "mobile"
        Phone.TYPE_OTHER -> "other"
        Phone.TYPE_OTHER_FAX -> "faxOther"
        Phone.TYPE_PAGER -> "pager"
        Phone.TYPE_RADIO -> "radio"
        Phone.TYPE_TELEX -> "telex"
        Phone.TYPE_TTY_TDD -> "ttyTtd"
        Phone.TYPE_WORK -> "work"
        Phone.TYPE_WORK_MOBILE -> "workMobile"
        Phone.TYPE_WORK_PAGER -> "workPager"
        Phone.TYPE_CUSTOM -> "custom"
        else -> "mobile"
    }
}


internal fun getPhoneCustomLabel(cursor: Cursor): String {
    return cursor.getString(cursor.getColumnIndexOrThrow(Phone.LABEL)) ?: ""
}

internal data class PhoneLabelPair(val label: Int, val customLabel: String)
internal fun getPhoneLabelInv(label: String, customLabel: String): PhoneLabelPair {
    return when (label) {
        "assistant" -> PhoneLabelPair(Phone.TYPE_ASSISTANT, "")
        "callback" -> PhoneLabelPair(Phone.TYPE_CALLBACK, "")
        "car" -> PhoneLabelPair(Phone.TYPE_CAR, "")
        "companyMain" -> PhoneLabelPair(Phone.TYPE_COMPANY_MAIN, "")
        "faxHome" -> PhoneLabelPair(Phone.TYPE_FAX_HOME, "")
        "faxOther" -> PhoneLabelPair(Phone.TYPE_OTHER_FAX, "")
        "faxWork" -> PhoneLabelPair(Phone.TYPE_FAX_WORK, "")
        "home" -> PhoneLabelPair(Phone.TYPE_HOME, "")
        "isdn" -> PhoneLabelPair(Phone.TYPE_ISDN, "")
        "main" -> PhoneLabelPair(Phone.TYPE_MAIN, "")
        "mms" -> PhoneLabelPair(Phone.TYPE_MMS, "")
        "mobile" -> PhoneLabelPair(Phone.TYPE_MOBILE, "")
        "other" -> PhoneLabelPair(Phone.TYPE_OTHER, "")
        "pager" -> PhoneLabelPair(Phone.TYPE_PAGER, "")
        "radio" -> PhoneLabelPair(Phone.TYPE_RADIO, "")
        "telex" -> PhoneLabelPair(Phone.TYPE_TELEX, "")
        "ttyTtd" -> PhoneLabelPair(Phone.TYPE_TTY_TDD, "")
        "work" -> PhoneLabelPair(Phone.TYPE_WORK, "")
        "workMobile" -> PhoneLabelPair(Phone.TYPE_WORK_MOBILE, "")
        "workPager" -> PhoneLabelPair(Phone.TYPE_WORK_PAGER, "")
        "custom" -> PhoneLabelPair(Phone.TYPE_CUSTOM, customLabel)
        else -> PhoneLabelPair(Phone.TYPE_CUSTOM, label)
    }
}

internal fun getEmailLabel(cursor: Cursor): String {
    val type = cursor.getInt(cursor.getColumnIndexOrThrow(Email.TYPE))
    return when (type) {
        Email.TYPE_CUSTOM -> "custom"
        Email.TYPE_HOME -> "home"
        Email.TYPE_MOBILE -> "mobile"
        Email.TYPE_OTHER -> "other"
        Email.TYPE_WORK -> "work"
        else -> "home"
    }
}

internal fun getEmailCustomLabel(cursor: Cursor): String {
    return cursor.getString(cursor.getColumnIndexOrThrow(Email.LABEL)) ?: ""
}

internal data class EmailLabelPair(val label: Int, val customLabel: String)
internal fun getEmailLabelInv(label: String, customLabel: String): EmailLabelPair {
    return when (label) {
        "home" -> EmailLabelPair(Email.TYPE_HOME, "")
        "mobile" -> EmailLabelPair(Email.TYPE_MOBILE, "")
        "other" -> EmailLabelPair(Email.TYPE_OTHER, "")
        "work" -> EmailLabelPair(Email.TYPE_WORK, "")
        "custom" -> EmailLabelPair(Email.TYPE_CUSTOM, customLabel)
        else -> EmailLabelPair(Email.TYPE_CUSTOM, label)
    }
}

internal fun getAddressLabel(cursor: Cursor): String {
    val type = cursor.getInt(cursor.getColumnIndexOrThrow(StructuredPostal.TYPE))
    return when (type) {
        StructuredPostal.TYPE_HOME -> "home"
        StructuredPostal.TYPE_OTHER -> "other"
        StructuredPostal.TYPE_WORK -> "work"
        StructuredPostal.TYPE_CUSTOM -> "custom"
        else -> ""
    }
}

internal fun getAddressCustomLabel(cursor: Cursor): String {
    return cursor.getString(cursor.getColumnIndexOrThrow(StructuredPostal.LABEL)) ?: ""
}

internal data class AddressLabelPair(val label: Int, val customLabel: String)
internal fun getAddressLabelInv(label: String, customLabel: String): AddressLabelPair {
    return when (label) {
        "home" -> AddressLabelPair(StructuredPostal.TYPE_HOME, "")
        "other" -> AddressLabelPair(StructuredPostal.TYPE_OTHER, "")
        "work" -> AddressLabelPair(StructuredPostal.TYPE_WORK, "")
        "custom" -> AddressLabelPair(StructuredPostal.TYPE_CUSTOM, customLabel)
        else -> AddressLabelPair(StructuredPostal.TYPE_CUSTOM, label)
    }
}

internal fun getWebsiteLabel(cursor: Cursor): String {
    val type = cursor.getInt(cursor.getColumnIndexOrThrow(Website.TYPE))
    return when (type) {
        Website.TYPE_BLOG -> "blog"
        Website.TYPE_FTP -> "ftp"
        Website.TYPE_HOME -> "home"
        Website.TYPE_HOMEPAGE -> "homepage"
        Website.TYPE_OTHER -> "other"
        Website.TYPE_PROFILE -> "profile"
        Website.TYPE_WORK -> "work"
        Website.TYPE_CUSTOM -> "custom"
        else -> ""
    }
}

internal fun getWebsiteCustomLabel(cursor: Cursor): String {
    return cursor.getString(cursor.getColumnIndexOrThrow(Website.LABEL)) ?: ""
}

internal data class WebsiteLabelPair(val label: Int, val customLabel: String)
internal fun getWebsiteLabelInv(label: String, customLabel: String): WebsiteLabelPair {
    return when (label) {
        "blog" -> WebsiteLabelPair(Website.TYPE_BLOG, "")
        "ftp" -> WebsiteLabelPair(Website.TYPE_FTP, "")
        "home" -> WebsiteLabelPair(Website.TYPE_HOME, "")
        "homepage" -> WebsiteLabelPair(Website.TYPE_HOMEPAGE, "")
        "other" -> WebsiteLabelPair(Website.TYPE_OTHER, "")
        "profile" -> WebsiteLabelPair(Website.TYPE_PROFILE, "")
        "work" -> WebsiteLabelPair(Website.TYPE_WORK, "")
        "custom" -> WebsiteLabelPair(StructuredPostal.TYPE_CUSTOM, customLabel)
        else -> WebsiteLabelPair(StructuredPostal.TYPE_CUSTOM, label)
    }
}

internal fun getSocialMediaLabel(cursor: Cursor): String {
    val type = cursor.getInt(cursor.getColumnIndexOrThrow(Im.PROTOCOL))
    return when (type) {
        Im.PROTOCOL_AIM -> "aim"
        Im.PROTOCOL_GOOGLE_TALK -> "googleTalk"
        Im.PROTOCOL_ICQ -> "icq"
        Im.PROTOCOL_JABBER -> "jabber"
        Im.PROTOCOL_MSN -> "msn"
        Im.PROTOCOL_NETMEETING -> "netmeeting"
        Im.PROTOCOL_QQ -> "qqchat"
        Im.PROTOCOL_SKYPE -> "skype"
        Im.PROTOCOL_YAHOO -> "yahoo"
        Im.PROTOCOL_CUSTOM -> "custom"
        else -> ""
    }
}

internal fun getSocialMediaCustomLabel(cursor: Cursor): String {
    return cursor.getString(cursor.getColumnIndexOrThrow(Im.CUSTOM_PROTOCOL)) ?: ""
}

internal data class SocialMediaLabelPair(val label: Int, val customLabel: String)
internal fun getSocialMediaLabelInv(label: String, customLabel: String): SocialMediaLabelPair {
    return when (label) {
        "aim" -> SocialMediaLabelPair(Im.PROTOCOL_AIM, "")
        "googleTalk" -> SocialMediaLabelPair(Im.PROTOCOL_GOOGLE_TALK, "")
        "icq" -> SocialMediaLabelPair(Im.PROTOCOL_ICQ, "")
        "jabber" -> SocialMediaLabelPair(Im.PROTOCOL_JABBER, "")
        "msn" -> SocialMediaLabelPair(Im.PROTOCOL_MSN, "")
        "netmeeting" -> SocialMediaLabelPair(Im.PROTOCOL_NETMEETING, "")
        "qqchat" -> SocialMediaLabelPair(Im.PROTOCOL_QQ, "")
        "skype" -> SocialMediaLabelPair(Im.PROTOCOL_SKYPE, "")
        "yahoo" -> SocialMediaLabelPair(Im.PROTOCOL_YAHOO, "")
        "custom" -> SocialMediaLabelPair(Im.PROTOCOL_CUSTOM, customLabel)
        else -> SocialMediaLabelPair(Im.PROTOCOL_CUSTOM, label)
    }
}

internal fun getEventLabel(cursor: Cursor): String {
    val type = cursor.getInt(cursor.getColumnIndexOrThrow(Event.TYPE))
    return when (type) {
        Event.TYPE_ANNIVERSARY -> "anniversary"
        Event.TYPE_BIRTHDAY -> "birthday"
        Event.TYPE_OTHER -> "other"
        Event.TYPE_CUSTOM -> "custom"
        else -> ""
    }
}

internal fun getEventCustomLabel(cursor: Cursor): String {
    return cursor.getString(cursor.getColumnIndexOrThrow(Event.LABEL)) ?: ""
}

internal data class EventLabelPair(val label: Int, val customLabel: String)
internal fun getEventLabelInv(label: String, customLabel: String): EventLabelPair {
    return when (label) {
        "anniversary" -> EventLabelPair(Event.TYPE_ANNIVERSARY, "")
        "birthday" -> EventLabelPair(Event.TYPE_BIRTHDAY, "")
        "other" -> EventLabelPair(Event.TYPE_OTHER, "")
        "custom" -> EventLabelPair(StructuredPostal.TYPE_CUSTOM, customLabel)
        else -> EventLabelPair(StructuredPostal.TYPE_CUSTOM, label)
    }
}
