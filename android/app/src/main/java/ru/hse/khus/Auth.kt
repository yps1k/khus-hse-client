package ru.hse.khus

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.browser.customtabs.CustomTabsIntent
import com.google.gson.Gson
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.FormBody
import okhttp3.OkHttpClient
import okhttp3.Request
import java.security.MessageDigest
import java.security.SecureRandom
import java.util.concurrent.TimeUnit

object Auth {
    const val KC = "https://saml.hse.ru/realms/hse/protocol/openid-connect"
    const val CLIENT_ID = "app-x-android"
    const val REDIRECT = "ru.hse.hseappx://saml.hse.ru/authorize_callback"
    const val SCOPE = "profile email"

    private const val PREFS = "khus_auth"
    private val gson = Gson()
    val http: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(20, TimeUnit.SECONDS)
        .build()

    data class Tokens(val access: String, val refresh: String, val expiresAt: Long)

    private var tokens: Tokens? = null
    private lateinit var appCtx: Context

    fun init(ctx: Context) {
        appCtx = ctx.applicationContext
        val raw = prefs().getString("tokens", null)
        if (raw != null) tokens = runCatching { gson.fromJson(raw, Tokens::class.java) }.getOrNull()
    }

    private fun prefs() = appCtx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    val isLoggedIn: Boolean get() = tokens != null

    private fun b64(bytes: ByteArray) = android.util.Base64.encodeToString(
        bytes, android.util.Base64.URL_SAFE or android.util.Base64.NO_PADDING or android.util.Base64.NO_WRAP
    )
    private fun rand(n: Int): String { val b = ByteArray(n); SecureRandom().nextBytes(b); return b64(b) }
    private fun sha256(s: String) = b64(MessageDigest.getInstance("SHA-256").digest(s.toByteArray()))

    fun launchLogin(ctx: Context) {
        val verifier = rand(48)
        val state = rand(16)
        prefs().edit().putString("verifier", verifier).putString("state", state).apply()
        val challenge = sha256(verifier)
        val url = Uri.parse("$KC/auth").buildUpon()
            .appendQueryParameter("client_id", CLIENT_ID)
            .appendQueryParameter("redirect_uri", REDIRECT)
            .appendQueryParameter("response_type", "code")
            .appendQueryParameter("scope", SCOPE)
            .appendQueryParameter("state", state)
            .appendQueryParameter("code_challenge", challenge)
            .appendQueryParameter("code_challenge_method", "S256")
            .build()
        val intent = CustomTabsIntent.Builder().build()
        intent.intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        intent.launchUrl(ctx, url)
    }

    /** Returns true on successful login. */
    suspend fun handleRedirect(uri: Uri): Boolean {
        val code = uri.getQueryParameter("code") ?: run {
            val err = uri.getQueryParameter("error_description") ?: uri.getQueryParameter("error")
            if (err != null) throw RuntimeException(err)
            return false
        }
        val state = uri.getQueryParameter("state")
        val savedState = prefs().getString("state", null)
        val verifier = prefs().getString("verifier", null)
            ?: throw RuntimeException("данные входа не найдены, войдите ещё раз")
        if (state != savedState) throw RuntimeException("сессия входа устарела, войдите ещё раз")
        exchange(code, verifier)
        return true
    }

    private suspend fun exchange(code: String, verifier: String) = tokenRequest(
        FormBody.Builder()
            .add("grant_type", "authorization_code")
            .add("code", code)
            .add("redirect_uri", REDIRECT)
            .add("code_verifier", verifier)
    )

    private suspend fun refresh() {
        val rt = tokens?.refresh ?: throw RuntimeException("not logged in")
        tokenRequest(FormBody.Builder().add("grant_type", "refresh_token").add("refresh_token", rt))
    }

    private suspend fun tokenRequest(form: FormBody.Builder) = withContext(Dispatchers.IO) {
        form.add("client_id", CLIENT_ID)
        val req = Request.Builder().url("$KC/token").post(form.build()).build()
        http.newCall(req).execute().use { resp ->
            val body = resp.body?.string().orEmpty()
            if (resp.code == 400 || resp.code == 401) {
                tokens = null; prefs().edit().remove("tokens").apply()
                val err = runCatching { gson.fromJson(body, TokenResponse::class.java).error }.getOrNull()
                throw RuntimeException(err ?: "invalid_grant")
            }
            if (!resp.isSuccessful) throw RuntimeException("HTTP ${resp.code}")
            val t = gson.fromJson(body, TokenResponse::class.java)
            val tk = Tokens(t.accessToken!!, t.refreshToken!!, System.currentTimeMillis() + t.expiresIn * 1000)
            tokens = tk
            prefs().edit().putString("tokens", gson.toJson(tk)).apply()
        }
    }

    suspend fun validToken(): String {
        val t = tokens ?: throw RuntimeException("not logged in")
        if (System.currentTimeMillis() > t.expiresAt - 60_000) refresh()
        return tokens?.access ?: throw RuntimeException("not logged in")
    }

    suspend fun forceRefresh() = refresh()

    fun logout() {
        tokens = null
        prefs().edit().clear().apply()
    }
}
