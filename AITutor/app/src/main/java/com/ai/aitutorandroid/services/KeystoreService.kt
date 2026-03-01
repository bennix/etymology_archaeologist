package com.ai.aitutorandroid.services

import android.content.Context
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class KeystoreService @Inject constructor(
    @param:ApplicationContext private val context: Context
) {
    private val prefs by lazy {
        val masterKey = MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
        EncryptedSharedPreferences.create(
            context,
            "ai_tutor_secure_prefs",
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    }

    fun save(value: String, account: String) {
        prefs.edit().putString(account, value).apply()
    }

    fun load(account: String): String? = prefs.getString(account, null)

    fun delete(account: String) {
        prefs.edit().remove(account).apply()
    }

    companion object {
        const val ZENMUX_API_KEY = "zenmux_api_key"
        const val TUZI_API_KEY = "tuzi_api_key"
    }
}
