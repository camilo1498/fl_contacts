package co.quis.fl_contacts

import android.app.Activity
import android.content.ContentProviderOperation
import android.content.ContentResolver
import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.res.AssetFileDescriptor
import android.database.Cursor
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.provider.ContactsContract
import android.provider.ContactsContract.CommonDataKinds.Email
import android.provider.ContactsContract.CommonDataKinds.Event
import android.provider.ContactsContract.CommonDataKinds.GroupMembership
import android.provider.ContactsContract.CommonDataKinds.Im
import android.provider.ContactsContract.CommonDataKinds.Nickname
import android.provider.ContactsContract.CommonDataKinds.Note
import android.provider.ContactsContract.CommonDataKinds.Organization
import android.provider.ContactsContract.CommonDataKinds.Phone
import android.provider.ContactsContract.CommonDataKinds.Photo
import android.provider.ContactsContract.CommonDataKinds.StructuredName
import android.provider.ContactsContract.CommonDataKinds.StructuredPostal
import android.provider.ContactsContract.CommonDataKinds.Website
import android.provider.ContactsContract.Contacts
import android.provider.ContactsContract.Data
import android.provider.ContactsContract.Groups
import android.provider.ContactsContract.RawContacts
import java.io.ByteArrayOutputStream
import java.io.FileNotFoundException
import java.io.InputStream
import java.io.OutputStream
import co.quis.fl_contacts.properties.Account as PAccount
import co.quis.fl_contacts.properties.Address as PAddress
import co.quis.fl_contacts.properties.Email as PEmail
import co.quis.fl_contacts.properties.Event as PEvent
import co.quis.fl_contacts.properties.Group as PGroup
import co.quis.fl_contacts.properties.Name as PName
import co.quis.fl_contacts.properties.Note as PNote
import co.quis.fl_contacts.properties.Organization as POrganization
import co.quis.fl_contacts.properties.Phone as PPhone
import co.quis.fl_contacts.properties.SocialMedia as PSocialMedia
import co.quis.fl_contacts.properties.Website as PWebsite

class FlContacts {
    companion object {
        private val YYYY_MM_DD = """\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|30|31)""".toRegex()
        private val MM_DD = """--(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|30|31)""".toRegex()

        val REQUEST_CODE_VIEW = 77881
        val REQUEST_CODE_EDIT = 77882
        val REQUEST_CODE_PICK = 77883
        val REQUEST_CODE_INSERT = 77884
        val REQUEST_CODE_RINGTONE_PICK = 77885

        /** Queries the provider and aggregates rows into contact maps. */
        fun select(
            resolver: ContentResolver,
            id: String?,
            withProperties: Boolean,
            withThumbnail: Boolean,
            withPhoto: Boolean,
            withGroups: Boolean,
            withAccounts: Boolean,
            returnUnifiedContacts: Boolean,
            includeNonVisible: Boolean,
            idIsRawContactId: Boolean = false,
            filter: Map<String, Any?>? = null,
            limit: Int? = null,
            thumbnailMaxSize: Int = 0
        ): List<Map<String, Any?>> {
            // Phone/email/group filters need hydrated rows; fetch properties
            // so a single provider round trip still suffices.
            var fetchProperties = withProperties
            var fetchGroups = withGroups
            val filterIds = (filter?.get("ids") as? List<*>)?.mapNotNull { it as? String }
            val filterGroup = filter?.get("groupId") as? String
            val filterName = filter?.get("name") as? String
            val filterPhone = (filter?.get("phone") as? String)?.filter { it.isDigit() }
            val filterEmail = filter?.get("email") as? String
            if (!filterPhone.isNullOrEmpty() || !filterEmail.isNullOrEmpty()) {
                fetchProperties = true
            }
            if (filterGroup != null) {
                fetchGroups = true
            }
            if (id == null && !fetchProperties && !withThumbnail && !withPhoto &&
                returnUnifiedContacts && filter == null && limit == null
            ) {
                return getQuick(resolver, includeNonVisible)
            }

            var projection = mutableListOf(
                Data.CONTACT_ID,
                Data.MIMETYPE,
                Contacts.DISPLAY_NAME_PRIMARY,
                Contacts.STARRED
            )
            if (withThumbnail) {
                projection.add(Photo.PHOTO)
            }
            if (fetchProperties) {
                projection.addAll(
                    listOf(
                        StructuredName.PREFIX,
                        StructuredName.GIVEN_NAME,
                        StructuredName.MIDDLE_NAME,
                        StructuredName.FAMILY_NAME,
                        StructuredName.SUFFIX,
                        Nickname.NAME,
                        StructuredName.PHONETIC_GIVEN_NAME,
                        StructuredName.PHONETIC_FAMILY_NAME,
                        StructuredName.PHONETIC_MIDDLE_NAME,
                        Phone.NUMBER,
                        Phone.NORMALIZED_NUMBER,
                        Phone.TYPE,
                        Phone.LABEL,
                        Phone.IS_PRIMARY,
                        Email.ADDRESS,
                        Email.TYPE,
                        Email.LABEL,
                        Email.IS_PRIMARY,
                        StructuredPostal.FORMATTED_ADDRESS,
                        StructuredPostal.STREET,
                        StructuredPostal.POBOX,
                        StructuredPostal.NEIGHBORHOOD,
                        StructuredPostal.CITY,
                        StructuredPostal.REGION,
                        StructuredPostal.POSTCODE,
                        StructuredPostal.COUNTRY,
                        StructuredPostal.TYPE,
                        StructuredPostal.LABEL,
                        Organization.COMPANY,
                        Organization.TITLE,
                        Organization.DEPARTMENT,
                        Organization.JOB_DESCRIPTION,
                        Organization.SYMBOL,
                        Organization.PHONETIC_NAME,
                        Organization.OFFICE_LOCATION,
                        Website.URL,
                        Website.TYPE,
                        Website.LABEL,
                        Im.DATA,
                        Im.PROTOCOL,
                        Im.CUSTOM_PROTOCOL,
                        Event.START_DATE,
                        Event.TYPE,
                        Event.LABEL,
                        Note.NOTE
                    )
                )
            }
            if (withAccounts || !returnUnifiedContacts) {
                projection.addAll(
                    listOf(
                        Data.RAW_CONTACT_ID,
                        RawContacts.ACCOUNT_TYPE,
                        RawContacts.ACCOUNT_NAME
                    )
                )
            }
            if (fetchGroups) {
                projection.add(GroupMembership.GROUP_ROW_ID)
            }

            val groups = if (fetchGroups) fetchGroups(resolver) else mapOf<String, PGroup>()

            var selectionClauses = mutableListOf<String>()
            if (!includeNonVisible) {
                selectionClauses.add("${Data.IN_VISIBLE_GROUP} = 1")
            }
            var selectionArgs = mutableListOf<String>()

            if (id != null) {
                if (idIsRawContactId || !returnUnifiedContacts) {
                    selectionClauses.add("${Data.RAW_CONTACT_ID} = ?")
                } else {
                    selectionClauses.add("${Data.CONTACT_ID} = ?")
                }
                selectionArgs.add(id)
            }
            if (!filterIds.isNullOrEmpty()) {
                val placeholders = filterIds.joinToString(",") { "?" }
                selectionClauses.add("${Data.CONTACT_ID} IN ($placeholders)")
                selectionArgs.addAll(filterIds)
            }
            if (!filterName.isNullOrEmpty()) {
                selectionClauses.add("${Contacts.DISPLAY_NAME_PRIMARY} LIKE ? ESCAPE '\\'")
                selectionArgs.add("%${filterName.replace("%", "\\%").replace("_", "\\_")}%")
            }
            val selection: String? = if (selectionClauses.isEmpty()) null else selectionClauses.joinToString(separator = " AND ")
            // LIMIT rides in sortOrder; a null order means unordered + capped.
            val sortOrder: String? = if (limit != null && limit >= 0) "LIMIT $limit" else null

            val cursor = resolver.query(
                Data.CONTENT_URI,
                projection.toTypedArray(),
                selection,
                selectionArgs.toTypedArray(),
                sortOrder
            ) ?: return listOf()

            // Closed automatically on success and on failure; column indexes
            // are resolved once instead of per row.
            cursor.use {
                var contacts = mutableListOf<Contact>()

                var index = mutableMapOf<String, Int>()
                val colIndexes = mutableMapOf<String, Int>()
                fun col(col: String): Int =
                    colIndexes.getOrPut(col) { cursor.getColumnIndexOrThrow(col) }
                fun getString(col: String): String = cursor.getString(col(col)) ?: ""
                fun getInt(col: String): Int = cursor.getInt(col(col)) ?: 0
                fun getBool(col: String): Boolean = getInt(col) == 1

            while (cursor.moveToNext()) {
                val id = if (returnUnifiedContacts) getString(Data.CONTACT_ID) else getString(Data.RAW_CONTACT_ID)
                if (id !in index) {
                    var contact = Contact(
                        /*id=*/id,
                        /*displayName=*/getString(Contacts.DISPLAY_NAME_PRIMARY),
                        isStarred = getBool(Contacts.STARRED)
                    )

                    if (withPhoto) {
                        val contactUri: Uri =
                            ContentUris.withAppendedId(Contacts.CONTENT_URI, id.toLong())
                        val displayPhotoUri: Uri =
                            Uri.withAppendedPath(contactUri, Contacts.Photo.DISPLAY_PHOTO)
                        try {
                            var fis: InputStream? = resolver.openInputStream(displayPhotoUri)
                            contact.photo = fis?.readBytes()
                        } catch (e: FileNotFoundException) {
                            // Missing hi-res photo is the common case, not an error.
                        }
                    }

                    index[id] = contacts.size
                    contacts.add(contact)
                }
                var contact: Contact = contacts[index[id]!!]

                val mimetype = getString(Data.MIMETYPE)

                if (withThumbnail && mimetype == Photo.CONTENT_ITEM_TYPE) {
                    contact.thumbnail = downsampleThumbnail(
                        cursor.getBlob(col(Photo.PHOTO)),
                        thumbnailMaxSize
                    )
                }

                if (fetchProperties) {
                    if (withAccounts) {
                        val rawId = getString(Data.RAW_CONTACT_ID)
                        val accountType = getString(RawContacts.ACCOUNT_TYPE)
                        val accountName = getString(RawContacts.ACCOUNT_NAME)
                        var accountSeen = false
                        for (account in contact.accounts) {
                            if (account.rawId == rawId) {
                                accountSeen = true
                                account.mimetypes =
                                    (account.mimetypes + mimetype).toSortedSet().toList()
                            }
                        }
                        if (!accountSeen) {
                            val account = PAccount(
                                rawId,
                                accountType,
                                accountName,
                                listOf(mimetype)
                            )
                            contact.accounts += account
                        }
                    }

                    when (mimetype) {
                        StructuredName.CONTENT_ITEM_TYPE -> {
                            val nickname: String = contact.name.nickname
                            contact.name = PName(
                                getString(StructuredName.GIVEN_NAME),
                                getString(StructuredName.FAMILY_NAME),
                                getString(StructuredName.MIDDLE_NAME),
                                getString(StructuredName.PREFIX),
                                getString(StructuredName.SUFFIX),
                                nickname,
                                getString(StructuredName.PHONETIC_GIVEN_NAME),
                                getString(StructuredName.PHONETIC_FAMILY_NAME),
                                getString(StructuredName.PHONETIC_MIDDLE_NAME)
                            )
                        }
                        Nickname.CONTENT_ITEM_TYPE ->
                            contact.name.nickname = getString(Nickname.NAME)
                        Phone.CONTENT_ITEM_TYPE -> {
                            val label: String = getPhoneLabel(cursor)
                            val customLabel: String =
                                if (label == "custom") getPhoneCustomLabel(cursor) else ""
                            val phone = PPhone(
                                getString(Phone.NUMBER),
                                getString(Phone.NORMALIZED_NUMBER),
                                label,
                                customLabel,
                                getInt(Phone.IS_PRIMARY) == 1
                            )
                            contact.phones += phone
                        }
                        Email.CONTENT_ITEM_TYPE -> {
                            val label: String = getEmailLabel(cursor)
                            val customLabel: String =
                                if (label == "custom") getEmailCustomLabel(cursor) else ""
                            val email = PEmail(
                                getString(Email.ADDRESS),
                                label,
                                customLabel,
                                getInt(Email.IS_PRIMARY) == 1
                            )
                            contact.emails += email
                        }
                        StructuredPostal.CONTENT_ITEM_TYPE -> {
                            val label: String = getAddressLabel(cursor)
                            val customLabel: String =
                                if (label == "custom") getAddressCustomLabel(cursor) else ""
                            val address = PAddress(
                                getString(StructuredPostal.FORMATTED_ADDRESS),
                                label,
                                customLabel,
                                getString(StructuredPostal.STREET),
                                getString(StructuredPostal.POBOX),
                                getString(StructuredPostal.NEIGHBORHOOD),
                                getString(StructuredPostal.CITY),
                                getString(StructuredPostal.REGION),
                                getString(StructuredPostal.POSTCODE),
                                getString(StructuredPostal.COUNTRY),
                                "",
                                "",
                                ""
                            )
                            contact.addresses += address
                        }
                        Organization.CONTENT_ITEM_TYPE -> {
                            val organization = POrganization(
                                getString(Organization.COMPANY),
                                getString(Organization.TITLE),
                                getString(Organization.DEPARTMENT),
                                getString(Organization.JOB_DESCRIPTION),
                                getString(Organization.SYMBOL),
                                getString(Organization.PHONETIC_NAME),
                                getString(Organization.OFFICE_LOCATION)
                            )
                            contact.organizations += organization
                        }
                        Website.CONTENT_ITEM_TYPE -> {
                            val label: String = getWebsiteLabel(cursor)
                            val customLabel: String =
                                if (label == "custom") getWebsiteCustomLabel(cursor) else ""
                            val website = PWebsite(
                                getString(Website.URL),
                                label,
                                customLabel
                            )
                            contact.websites += website
                        }
                        Im.CONTENT_ITEM_TYPE -> {
                            val label: String = getSocialMediaLabel(cursor)
                            val customLabel: String =
                                if (label == "custom") getSocialMediaCustomLabel(cursor) else ""
                            val socialMedia = PSocialMedia(
                                getString(Im.DATA),
                                label,
                                customLabel
                            )
                            contact.socialMedias += socialMedia
                        }
                        Event.CONTENT_ITEM_TYPE -> {
                            val date = getString(Event.START_DATE)
                            var year: Int? = null
                            var month: Int? = null
                            var day: Int? = null
                            if (YYYY_MM_DD matches date) {
                                year = date.substring(0, 4).toInt()
                                month = date.substring(5, 7).toInt()
                                day = date.substring(8, 10).toInt()
                            } else if (MM_DD matches date) {
                                month = date.substring(2, 4).toInt()
                                day = date.substring(5, 7).toInt()
                            }
                            if (month != null && day != null) {
                                val label: String = getEventLabel(cursor)
                                val customLabel: String =
                                    if (label == "custom") getEventCustomLabel(cursor) else ""
                                val event = PEvent(
                                    year,
                                    month!!,
                                    day!!,
                                    label,
                                    customLabel
                                )
                                contact.events += event
                            }
                        }
                        Note.CONTENT_ITEM_TYPE -> {
                            val note: String = getString(Note.NOTE)
                            if (!note.isEmpty()) {
                                val note = PNote(getString(Note.NOTE))
                                contact.notes += note
                            }
                        }
                        GroupMembership.CONTENT_ITEM_TYPE -> {
                            if (fetchGroups) {
                                val groupId: String = getString(GroupMembership.GROUP_ROW_ID)
                                if (groups.containsKey(groupId)) {
                                    contact.groups += groups[groupId]!!
                                }
                            }
                        }
                    }
                }
            }

                var result = contacts.map { it.toMap() }
                // Group/phone/email narrow the hydrated result in one pass.
                if (filterGroup != null) {
                    result = result.filter { c ->
                        @Suppress("UNCHECKED_CAST")
                        ((c["groups"] as? List<*>) ?: emptyList<Map<String, Any?>>())
                            .any { (it as? Map<*, *>)?.get("id") == filterGroup }
                    }
                }
                if (!filterPhone.isNullOrEmpty()) {
                    result = result.filter { c ->
                        @Suppress("UNCHECKED_CAST")
                        ((c["phones"] as? List<*>) ?: emptyList<Map<String, Any?>>())
                            .any {
                                val phone = it as? Map<*, *> ?: return@any false
                                val number = (phone["number"] as? String ?: "").filter { ch -> ch.isDigit() }
                                val normalized = (phone["normalizedNumber"] as? String ?: "").filter { ch -> ch.isDigit() }
                                number.contains(filterPhone) || normalized.contains(filterPhone)
                            }
                    }
                }
                if (!filterEmail.isNullOrEmpty()) {
                    result = result.filter { c ->
                        @Suppress("UNCHECKED_CAST")
                        ((c["emails"] as? List<*>) ?: emptyList<Map<String, Any?>>())
                            .any {
                                ((it as? Map<*, *>)?.get("address") as? String ?: "")
                                    .contains(filterEmail, ignoreCase = true)
                            }
                    }
                }
                return result
            }
        }

        /** Persists a new contact batch and returns it as stored. */
        fun insert(
            resolver: ContentResolver,
            contactMap: Map<String, Any?>
        ): Map<String, Any?>? {
            val ops = mutableListOf<ContentProviderOperation>()

            val contact = Contact.fromMap(contactMap)

            if (contact.accounts.isEmpty()) {
                ops.add(
                    ContentProviderOperation.newInsert(RawContacts.CONTENT_URI)
                        .withValue(RawContacts.ACCOUNT_TYPE, null)
                        .withValue(RawContacts.ACCOUNT_NAME, null)
                        .build()
                )
            } else {
                ops.add(
                    ContentProviderOperation.newInsert(RawContacts.CONTENT_URI)
                        .withValue(RawContacts.ACCOUNT_TYPE, contact.accounts.first().type)
                        .withValue(RawContacts.ACCOUNT_NAME, contact.accounts.first().name)
                        .build()
                )
            }

            buildOpsForContact(contact, ops)

            val addContactResults =
                resolver.applyBatch(ContactsContract.AUTHORITY, ArrayList(ops))
            val rawId: Long = ContentUris.parseId(addContactResults[0].uri!!)

            if (contact.photo != null) {
                buildOpsForPhoto(resolver, contact.photo!!, ops, rawId)
            }

            val contentValues = ContentValues()
            contentValues.put(ContactsContract.RawContacts.STARRED, if (contact.isStarred) 1 else 0)
            resolver.update(
                ContactsContract.RawContacts.CONTENT_URI,
                contentValues,
                ContactsContract.RawContacts._ID + "=?",
                /*selectionArgs=*/arrayOf(rawId.toString())
            )

            val insertedContacts: List<Map<String, Any?>> = select(
                resolver,
                rawId.toString(),
                /*withProperties=*/ true,
                /*withThumbnail=*/true,
                /*withPhoto=*/true,
                /*withGroups=*/false, // slower, usually not needed
                /*withAccounts=*/true,
                /*returnUnifiedContacts=*/true,
                /*includeNonVisible=*/true,
                /*idIsRawContactId=*/true
            )

            if (insertedContacts.isEmpty()) {
                return null
            }
            return insertedContacts[0]
        }

        /** Inserts every map sequentially and returns the stored contacts. */
        fun insertAll(
            resolver: ContentResolver,
            contactMaps: List<Map<String, Any?>>
        ): List<Map<String, Any?>> {
            return contactMaps.mapNotNull { insert(resolver, it) }
        }

        /** Rewrites a contact's properties and returns it as stored. */
        fun update(
            resolver: ContentResolver,
            contactMap: Map<String, Any?>,
            withGroups: Boolean
        ): Map<String, Any?>? {
            val ops = mutableListOf<ContentProviderOperation>()

            val contact = Contact.fromMap(contactMap)

            val contactId = contact.id
            val rawContactId = contact.accounts.first().rawId

            ops.add(
                ContentProviderOperation.newDelete(Data.CONTENT_URI)
                    .withSelection(
                        "${RawContacts.CONTACT_ID}=? and ${Data.MIMETYPE} in (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                        arrayOf(
                            contactId,
                            StructuredName.CONTENT_ITEM_TYPE,
                            Nickname.CONTENT_ITEM_TYPE,
                            Phone.CONTENT_ITEM_TYPE,
                            Email.CONTENT_ITEM_TYPE,
                            StructuredPostal.CONTENT_ITEM_TYPE,
                            Organization.CONTENT_ITEM_TYPE,
                            Website.CONTENT_ITEM_TYPE,
                            Im.CONTENT_ITEM_TYPE,
                            Event.CONTENT_ITEM_TYPE,
                            Note.CONTENT_ITEM_TYPE
                        )
                    )
                    .build()
            )
            if (contact.photo == null && contact.thumbnail == null) {
                ops.add(
                    ContentProviderOperation.newDelete(Data.CONTENT_URI)
                        .withSelection(
                            "${RawContacts.CONTACT_ID}=? and ${Data.MIMETYPE}=?",
                            arrayOf(
                                contactId,
                                Photo.CONTENT_ITEM_TYPE
                            )
                        )
                        .build()
                )
            }
            if (withGroups) {
                ops.add(
                    ContentProviderOperation.newDelete(Data.CONTENT_URI)
                        .withSelection(
                            "${RawContacts.CONTACT_ID}=? and ${Data.MIMETYPE}=?",
                            arrayOf(
                                contactId,
                                GroupMembership.CONTENT_ITEM_TYPE
                            )
                        )
                        .build()
                )
            }

            buildOpsForContact(contact, ops, rawContactId)
            if (contact.photo != null) {
                buildOpsForPhoto(resolver, contact.photo!!, ops, rawContactId.toLong())
            }

            resolver.applyBatch(ContactsContract.AUTHORITY, ArrayList(ops))

            val contentValues = ContentValues()
            contentValues.put(ContactsContract.Contacts.STARRED, if (contact.isStarred) 1 else 0)
            resolver.update(
                ContactsContract.Contacts.CONTENT_URI,
                contentValues,
                ContactsContract.Contacts._ID + "=?",
                /*selectionArgs=*/arrayOf(contactId)
            )

            val updatedContacts: List<Map<String, Any?>> = select(
                resolver,
                rawContactId,
                /*withProperties=*/ true,
                /*withThumbnail=*/true,
                /*withPhoto=*/true,
                /*withGroups=*/false, // slower, usually not needed
                /*withAccounts=*/true,
                /*returnUnifiedContacts=*/true,
                /*includeNonVisible=*/true,
                /*idIsRawContactId=*/true
            )

            if (updatedContacts.isEmpty()) {
                return null
            }
            return updatedContacts[0]
        }

        /** Rewrites every map sequentially and returns the stored contacts. */
        fun updateAll(
            resolver: ContentResolver,
            contactMaps: List<Map<String, Any?>>,
            withGroups: Boolean
        ): List<Map<String, Any?>> {
            return contactMaps.mapNotNull { update(resolver, it, withGroups) }
        }

        /** Deletes every listed contact in one batch. */
        fun delete(resolver: ContentResolver, contactIds: List<String>) {
            val ops = mutableListOf<ContentProviderOperation>()

            for (contactId in contactIds) {
                ops.add(
                    ContentProviderOperation.newDelete(RawContacts.CONTENT_URI)
                        .withSelection("${RawContacts.CONTACT_ID}=?", arrayOf(contactId))
                        .build()
                )
            }

            resolver.applyBatch(ContactsContract.AUTHORITY, ArrayList(ops))
        }

        /** Loads labels keyed by row ID. */
        private fun fetchGroups(resolver: ContentResolver): Map<String, PGroup> {
            val projection = listOf(
                Groups._ID,
                Groups.TITLE
            )
            val cursor = resolver.query(
                Groups.CONTENT_URI,
                projection.toTypedArray(),
                null,
                null,
                null
            ) ?: return mapOf()

            cursor.use {
                var groups = mutableMapOf<String, PGroup>()
                val idCol = cursor.getColumnIndexOrThrow(Groups._ID)
                val titleCol = cursor.getColumnIndexOrThrow(Groups.TITLE)
                while (cursor.moveToNext()) {
                    val groupId = cursor.getString(idCol) ?: ""
                    val groupName = cursor.getString(titleCol) ?: ""
                    groups[groupId] = PGroup(id = groupId, name = groupName)
                }
                return groups
            }
        }

        fun getGroups(resolver: ContentResolver): List<Map<String, Any>> {
            val groups = fetchGroups(resolver)
            return groups.values.map { it.toMap() }
        }

        /** Creates a label and returns it with its new ID. */
        fun insertGroup(resolver: ContentResolver, groupMap: Map<String, Any>): Map<String, Any> {
            val ops = mutableListOf<ContentProviderOperation>()

            var group = PGroup.fromMap(groupMap)

            ops.add(
                ContentProviderOperation.newInsert(Groups.CONTENT_URI)
                    .withValue(Groups.TITLE, group.name)
                    .build()
            )

            val addGroupResults =
                resolver.applyBatch(ContactsContract.AUTHORITY, ArrayList(ops))
            val id: Long = ContentUris.parseId(addGroupResults[0].uri!!)

            group.id = id.toString()
            return group.toMap()
        }

        /** Renames a label in place. */
        fun updateGroup(resolver: ContentResolver, groupMap: Map<String, Any>): Map<String, Any> {
            val ops = mutableListOf<ContentProviderOperation>()

            val group = PGroup.fromMap(groupMap)

            ops.add(
                ContentProviderOperation.newUpdate(Groups.CONTENT_URI)
                    .withSelection("${Groups._ID}=?", arrayOf(group.id))
                    .withValue(Groups.TITLE, group.name)
                    .build()
            )
            resolver.applyBatch(ContactsContract.AUTHORITY, ArrayList(ops))

            return groupMap
        }

        /** Deletes a label as sync adapter to bypass account scoping. */
        fun deleteGroup(resolver: ContentResolver, groupMap: Map<String, Any>) {
            val ops = mutableListOf<ContentProviderOperation>()

            val group = PGroup.fromMap(groupMap)

            ops.add(
                ContentProviderOperation.newDelete(
                    Groups.CONTENT_URI.buildUpon().appendQueryParameter(ContactsContract.CALLER_IS_SYNCADAPTER, "true").build()
                )
                    .withSelection("${Groups._ID}=?", arrayOf(group.id))
                    .build()
            )
            val results = resolver.applyBatch(ContactsContract.AUTHORITY, ArrayList(ops))
        }

        /** Adds contacts to a label without touching the contacts themselves. */
        fun addContactsToGroup(resolver: ContentResolver, groupId: String, contactIds: List<String>) {
            val ops = mutableListOf<ContentProviderOperation>()
            for (contactId in contactIds) {
                ops.add(
                    ContentProviderOperation.newInsert(Data.CONTENT_URI)
                        .withValue(Data.RAW_CONTACT_ID, contactId)
                        .withValue(Data.MIMETYPE, GroupMembership.CONTENT_ITEM_TYPE)
                        .withValue(GroupMembership.GROUP_ROW_ID, groupId)
                        .build()
                )
            }
            resolver.applyBatch(ContactsContract.AUTHORITY, ArrayList(ops))
        }

        /** Removes contacts from a label. */
        fun removeContactsFromGroup(resolver: ContentResolver, groupId: String, contactIds: List<String>) {
            val ops = mutableListOf<ContentProviderOperation>()
            for (contactId in contactIds) {
                ops.add(
                    ContentProviderOperation.newDelete(Data.CONTENT_URI)
                        .withSelection(
                            "${Data.RAW_CONTACT_ID}=? AND ${Data.MIMETYPE}=? AND ${GroupMembership.GROUP_ROW_ID}=?",
                            arrayOf(contactId, GroupMembership.CONTENT_ITEM_TYPE, groupId)
                        )
                        .build()
                )
            }
            resolver.applyBatch(ContactsContract.AUTHORITY, ArrayList(ops))
        }

        /** Returns the labels a contact belongs to. */
        fun getGroupsOf(resolver: ContentResolver, contactId: String): List<Map<String, Any>> {
            val groups = fetchGroups(resolver)
            val cursor = resolver.query(
                Data.CONTENT_URI,
                arrayOf(GroupMembership.GROUP_ROW_ID),
                "${Data.CONTACT_ID}=? AND ${Data.MIMETYPE}=?",
                arrayOf(contactId, GroupMembership.CONTENT_ITEM_TYPE),
                null
            ) ?: return listOf()
            cursor.use {
                val ids = mutableSetOf<String>()
                val col = cursor.getColumnIndexOrThrow(GroupMembership.GROUP_ROW_ID)
                while (cursor.moveToNext()) {
                    (cursor.getString(col) ?: "").takeIf { it.isNotEmpty() }?.let { ids.add(it) }
                }
                return ids.mapNotNull { groups[it]?.toMap() }
            }
        }

        /** Reads contacts stored on the SIM card (name + numbers only). */
        fun getSimContacts(resolver: ContentResolver): List<Map<String, Any?>> {
            val cursor = resolver.query(
                Uri.parse("content://icc/adn"),
                arrayOf("_id", "name", "number"),
                null,
                null,
                null
            ) ?: return listOf()
            cursor.use {
                val contacts = mutableListOf<Contact>()
                val idCol = cursor.getColumnIndexOrThrow("_id")
                val nameCol = cursor.getColumnIndexOrThrow("name")
                val numberCol = cursor.getColumnIndexOrThrow("number")
                while (cursor.moveToNext()) {
                    val name = cursor.getString(nameCol) ?: ""
                    val number = cursor.getString(numberCol) ?: ""
                    if (name.isEmpty() && number.isEmpty()) continue
                    val contact = Contact(
                        cursor.getString(idCol) ?: "",
                        name
                    )
                    if (number.isNotEmpty()) {
                        contact.phones += PPhone(number, "", "mobile", "", false)
                    }
                    contacts.add(contact)
                }
                return contacts.map { it.toMap() }
            }
        }

        /** Reads the device owner's profile contact, if one exists. */
        fun getProfile(
            resolver: ContentResolver,
            withProperties: Boolean,
            withPhoto: Boolean
        ): Map<String, Any?>? {
            val cursor = resolver.query(
                android.provider.ContactsContract.Profile.CONTENT_URI,
                arrayOf(android.provider.ContactsContract.Profile._ID),
                null,
                null,
                null
            ) ?: return null
            cursor.use {
                if (!cursor.moveToFirst()) return null
                val id = cursor.getString(
                    cursor.getColumnIndexOrThrow(android.provider.ContactsContract.Profile._ID)
                ) ?: return null
                val contacts = select(
                    resolver,
                    id,
                    withProperties,
                    withPhoto,
                    withPhoto,
                    false,
                    false,
                    true,
                    true
                )
                return contacts.firstOrNull()
            }
        }

        @Suppress("DEPRECATION") // startActivityForResult: still the Flutter-plugin canonical path
        /** Launches the system viewer or editor for a contact. */
        fun openExternalViewOrEdit(activity: Activity?, context: Context?, id: String, edit: Boolean) {
            if (activity == null && context == null) return
            val uri = Uri.withAppendedPath(Contacts.CONTENT_URI, id)
            var intent = Intent(if (edit) Intent.ACTION_EDIT else Intent.ACTION_VIEW)
            intent.setDataAndType(uri, Contacts.CONTENT_ITEM_TYPE)
            intent.putExtra("finishActivityOnSaveCompleted", true)
            if (activity != null) {
                activity!!.startActivityForResult(intent, if (edit) REQUEST_CODE_EDIT else REQUEST_CODE_VIEW)
            } else {
                intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context!!.startActivity(intent)
            }
        }

        @Suppress("DEPRECATION") // startActivityForResult: still the Flutter-plugin canonical path
        /** Launches the system picker or prefilled creator. */
        fun openExternalPickOrInsert(activity: Activity?, context: Context?, insert: Boolean, contact: Map<String, Any?>?) {
            if (activity == null && context == null) return
            var intent = Intent(if (insert) Intent.ACTION_INSERT else Intent.ACTION_PICK, Contacts.CONTENT_URI)

            if (contact != null) {
                val parsedContact = Contact.fromMap(contact)

                var fullName = parsedContact.displayName
                if (fullName.isEmpty()) {
                    fullName = (parsedContact.name.first + " " + parsedContact.name.last).trim()
                }
                if (fullName.isNotEmpty()) {
                    intent.putExtra(ContactsContract.Intents.Insert.NAME, fullName)
                }

                if (parsedContact.phones.isNotEmpty()) {
                    intent.putExtra(ContactsContract.Intents.Insert.PHONE, parsedContact.phones.first().number)
                }

                if (parsedContact.emails.isNotEmpty()) {
                    intent.putExtra(ContactsContract.Intents.Insert.EMAIL, parsedContact.emails.first().address)
                }

                if (parsedContact.addresses.isNotEmpty()) {
                    intent.putExtra(ContactsContract.Intents.Insert.POSTAL, parsedContact.addresses.first().address)
                }

                if (parsedContact.organizations.isNotEmpty()) {
                    intent.putExtra(ContactsContract.Intents.Insert.COMPANY, parsedContact.organizations.first().company)
                    intent.putExtra(ContactsContract.Intents.Insert.JOB_TITLE, parsedContact.organizations.first().title)
                }

                if (parsedContact.notes.isNotEmpty()) {
                    intent.putExtra(ContactsContract.Intents.Insert.NOTES, parsedContact.notes.first().note)
                }
            }

            intent.putExtra("finishActivityOnSaveCompleted", true)
            if (activity != null) {
                activity!!.startActivityForResult(intent, if (insert) REQUEST_CODE_INSERT else REQUEST_CODE_PICK)
            } else {
                intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context!!.startActivity(intent)
            }
        }

        fun openExternalPickOrInsert(activity: Activity?, context: Context?, insert: Boolean) {
            openExternalPickOrInsert(activity, context, insert, null)
        }

        /** Shrinks a provider thumbnail to [maxSize] px on its longest side.
         *
         * Provider blobs are often full-size photos; decoding megabytes per
         * list row drops frames. Already-small, empty or undecodable blobs
         * pass through untouched, and the original format is preserved, so
         * this never fails a fetch. A non-positive [maxSize] disables it. */
        private fun downsampleThumbnail(bytes: ByteArray?, maxSize: Int): ByteArray? {
            if (bytes == null || bytes.isEmpty() || maxSize <= 0) return bytes
            return try {
                val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
                val longest = maxOf(bounds.outWidth, bounds.outHeight)
                if (longest <= 0 || longest <= maxSize) return bytes
                var sample = 1
                while (longest / (sample * 2) >= maxSize) sample *= 2
                val opts = BitmapFactory.Options().apply { inSampleSize = sample }
                val decoded = BitmapFactory.decodeByteArray(bytes, 0, bytes.size, opts)
                    ?: return bytes
                val scale = maxSize.toFloat() / maxOf(decoded.width, decoded.height)
                val scaled = Bitmap.createScaledBitmap(
                    decoded,
                    (decoded.width * scale).toInt().coerceAtLeast(1),
                    (decoded.height * scale).toInt().coerceAtLeast(1),
                    true
                )
                if (scaled !== decoded) decoded.recycle()
                val out = ByteArrayOutputStream()
                val png = bytes.size >= 8 &&
                    bytes[0] == 0x89.toByte() && bytes[1] == 0x50.toByte() &&
                    bytes[2] == 0x4E.toByte() && bytes[3] == 0x47.toByte()
                scaled.compress(
                    if (png) Bitmap.CompressFormat.PNG else Bitmap.CompressFormat.JPEG,
                    85,
                    out
                )
                scaled.recycle()
                out.toByteArray()
            } catch (e: Exception) {
                bytes
            } catch (e: OutOfMemoryError) {
                bytes
            }
        }

        /** Fast ID-and-name listing without property joins. */
        private fun getQuick(resolver: ContentResolver, includeNonVisible: Boolean): List<Map<String, Any?>> {            val selection: String? = if (includeNonVisible) null else "${Data.IN_VISIBLE_GROUP} = 1"

            // Narrow projection: only the three columns this path reads.
            val cursor = resolver.query(
                Contacts.CONTENT_URI,
                arrayOf(
                    Contacts._ID,
                    Contacts.DISPLAY_NAME_PRIMARY,
                    Contacts.STARRED
                ),
                selection,
                null,
                null
            ) ?: return listOf()

            cursor.use {
                var contacts = mutableListOf<Contact>()
                val idCol = cursor.getColumnIndexOrThrow(Contacts._ID)
                val nameCol = cursor.getColumnIndexOrThrow(Contacts.DISPLAY_NAME_PRIMARY)
                val starredCol = cursor.getColumnIndexOrThrow(Contacts.STARRED)

                while (cursor.moveToNext()) {
                    contacts.add(
                        Contact(
                            cursor.getString(idCol) ?: "",
                            cursor.getString(nameCol) ?: "",
                            // STARRED reads 1 for starred contacts, 0 otherwise.
                            isStarred = (cursor.getInt(starredCol) ?: 0) == 1
                        )
                    )
                }

                return contacts.map { it.toMap() }
            }
        }


        private fun buildOpsForContact(
            contact: Contact,
            ops: MutableList<ContentProviderOperation>,
            rawContactId: String? = null
        ) {
            fun emptyToNull(s: String): String? = if (s.isEmpty()) "" else s
            fun eventToDate(e: PEvent): String =
                (if (e.year == null) "--" else "${e.year.toString().padStart(4, '0')}-") +
                    "${e.month.toString().padStart(2, '0')}-" +
                    "${e.day.toString().padStart(2, '0')}"
            fun newInsert(): ContentProviderOperation.Builder =
                if (rawContactId != null)
                    ContentProviderOperation
                        .newInsert(Data.CONTENT_URI)
                        .withValue(Data.RAW_CONTACT_ID, rawContactId)
                else
                    ContentProviderOperation
                        .newInsert(Data.CONTENT_URI)
                        .withValueBackReference(Data.RAW_CONTACT_ID, 0)

            val name: PName = contact.name
            ops.add(
                newInsert()
                    .withValue(Data.MIMETYPE, StructuredName.CONTENT_ITEM_TYPE)
                    .withValue(StructuredName.GIVEN_NAME, emptyToNull(name.first))
                    .withValue(StructuredName.MIDDLE_NAME, emptyToNull(name.middle))
                    .withValue(StructuredName.FAMILY_NAME, emptyToNull(name.last))
                    .withValue(StructuredName.PREFIX, emptyToNull(name.prefix))
                    .withValue(StructuredName.SUFFIX, emptyToNull(name.suffix))
                    .withValue(StructuredName.PHONETIC_GIVEN_NAME, emptyToNull(name.firstPhonetic))
                    .withValue(StructuredName.PHONETIC_MIDDLE_NAME, emptyToNull(name.middlePhonetic))
                    .withValue(StructuredName.PHONETIC_FAMILY_NAME, emptyToNull(name.lastPhonetic))
                    .build()
            )
            if (!name.nickname.isEmpty()) {
                ops.add(
                    newInsert()
                        .withValue(Data.MIMETYPE, Nickname.CONTENT_ITEM_TYPE)
                        .withValue(Nickname.NAME, name.nickname)
                        .build()
                )
            }
            for ((i, phone) in contact.phones.withIndex()) {
                val labelPair: PhoneLabelPair = getPhoneLabelInv(phone.label, phone.customLabel)
                ops.add(
                    newInsert()
                        .withValue(Data.MIMETYPE, Phone.CONTENT_ITEM_TYPE)
                        .withValue(Phone.NUMBER, emptyToNull(phone.number))
                        .withValue(Phone.TYPE, labelPair.label)
                        .withValue(Phone.LABEL, emptyToNull(labelPair.customLabel))
                        .withValue(Data.IS_PRIMARY, if (phone.isPrimary) 1 else 0)
                        .build()
                )
            }
            for ((i, email) in contact.emails.withIndex()) {
                val labelPair: EmailLabelPair = getEmailLabelInv(email.label, email.customLabel)
                ops.add(
                    newInsert()
                        .withValue(Data.MIMETYPE, Email.CONTENT_ITEM_TYPE)
                        .withValue(Email.ADDRESS, emptyToNull(email.address))
                        .withValue(Email.TYPE, labelPair.label)
                        .withValue(Email.LABEL, emptyToNull(labelPair.customLabel))
                        .withValue(Data.IS_PRIMARY, if (email.isPrimary) 1 else 0)
                        .build()
                )
            }
            for (address in contact.addresses) {
                val labelPair: AddressLabelPair =
                    getAddressLabelInv(address.label, address.customLabel)
                ops.add(
                    newInsert()
                        .withValue(Data.MIMETYPE, StructuredPostal.CONTENT_ITEM_TYPE)
                        .withValue(StructuredPostal.FORMATTED_ADDRESS, emptyToNull(address.address))
                        .withValue(StructuredPostal.TYPE, labelPair.label)
                        .withValue(StructuredPostal.LABEL, emptyToNull(labelPair.customLabel))
                        .withValue(StructuredPostal.STREET, emptyToNull(address.street))
                        .withValue(StructuredPostal.POBOX, emptyToNull(address.pobox))
                        .withValue(StructuredPostal.NEIGHBORHOOD, emptyToNull(address.neighborhood))
                        .withValue(StructuredPostal.CITY, emptyToNull(address.city))
                        .withValue(StructuredPostal.REGION, emptyToNull(address.state))
                        .withValue(StructuredPostal.POSTCODE, emptyToNull(address.postalCode))
                        .withValue(StructuredPostal.COUNTRY, emptyToNull(address.country))
                        .build()
                )
            }
            for (organization in contact.organizations) {
                ops.add(
                    newInsert()
                        .withValue(Data.MIMETYPE, Organization.CONTENT_ITEM_TYPE)
                        .withValue(Organization.COMPANY, emptyToNull(organization.company))
                        .withValue(Organization.TITLE, emptyToNull(organization.title))
                        .withValue(Organization.DEPARTMENT, emptyToNull(organization.department))
                        .withValue(Organization.JOB_DESCRIPTION, emptyToNull(organization.jobDescription))
                        .withValue(Organization.SYMBOL, emptyToNull(organization.symbol))
                        .withValue(Organization.PHONETIC_NAME, emptyToNull(organization.phoneticName))
                        .withValue(Organization.OFFICE_LOCATION, emptyToNull(organization.officeLocation))
                        .build()
                )
            }
            for (website in contact.websites) {
                val labelPair: WebsiteLabelPair =
                    getWebsiteLabelInv(website.label, website.customLabel)
                ops.add(
                    newInsert()
                        .withValue(Data.MIMETYPE, Website.CONTENT_ITEM_TYPE)
                        .withValue(Website.URL, emptyToNull(website.url))
                        .withValue(Website.TYPE, labelPair.label)
                        .withValue(Website.LABEL, emptyToNull(labelPair.customLabel))
                        .build()
                )
            }
            for (socialMedia in contact.socialMedias) {
                val labelPair: SocialMediaLabelPair =
                    getSocialMediaLabelInv(socialMedia.label, socialMedia.customLabel)
                ops.add(
                    newInsert()
                        .withValue(Data.MIMETYPE, Im.CONTENT_ITEM_TYPE)
                        .withValue(Im.DATA, emptyToNull(socialMedia.userName))
                        .withValue(Im.PROTOCOL, labelPair.label)
                        .withValue(Im.CUSTOM_PROTOCOL, emptyToNull(labelPair.customLabel))
                        .build()
                )
            }
            for (event in contact.events) {
                val labelPair: EventLabelPair =
                    getEventLabelInv(event.label, event.customLabel)
                ops.add(
                    newInsert()
                        .withValue(Data.MIMETYPE, Event.CONTENT_ITEM_TYPE)
                        .withValue(Event.START_DATE, eventToDate(event))
                        .withValue(Event.TYPE, labelPair.label)
                        .withValue(Event.LABEL, emptyToNull(labelPair.customLabel))
                        .build()
                )
            }
            for (note in contact.notes) {
                if (!note.note.isEmpty()) {
                    ops.add(
                        newInsert()
                            .withValue(Data.MIMETYPE, Note.CONTENT_ITEM_TYPE)
                            .withValue(Note.NOTE, note.note)
                            .build()
                    )
                }
            }
            for (group in contact.groups) {
                ops.add(
                    newInsert()
                        .withValue(Data.MIMETYPE, GroupMembership.CONTENT_ITEM_TYPE)
                        .withValue(GroupMembership.GROUP_ROW_ID, group.id)
                        .build()
                )
            }
        }

        private fun buildOpsForPhoto(
            resolver: ContentResolver,
            photo: ByteArray,
            ops: MutableList<ContentProviderOperation>,
            rawContactId: Long
        ) {
            val photoUri: Uri = Uri.withAppendedPath(
                ContentUris.withAppendedId(RawContacts.CONTENT_URI, rawContactId),
                RawContacts.DisplayPhoto.CONTENT_DIRECTORY
            )
            var fd: AssetFileDescriptor? = resolver.openAssetFileDescriptor(photoUri, "rw")
            if (fd != null) {
                val os: OutputStream = fd.createOutputStream()
                os.write(photo)
                os.close()
                fd.close()
            }
        }
    }
}
