package ru.hse.khus

import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.net.URLEncoder

object Api {
    private const val HOST = "https://api.hseapp.ru"
    private val gson = Gson()
    private val JSON = "application/json".toMediaType()

    private suspend fun raw(path: String, ver: String, method: String, bodyJson: String?): String =
        withContext(Dispatchers.IO) {
            fun build(token: String): Request {
                val b = Request.Builder().url(HOST + ver + path)
                    .header("Authorization", "Bearer $token")
                    .header("Accept-Language", "ru")
                if (method == "POST") b.post((bodyJson ?: "{}").toRequestBody(JSON))
                return b.build()
            }
            var resp = Auth.http.newCall(build(Auth.validToken())).execute()
            if (resp.code == 401) {
                resp.close()
                Auth.forceRefresh()
                resp = Auth.http.newCall(build(Auth.validToken())).execute()
            }
            resp.use {
                if (!it.isSuccessful) throw RuntimeException("HTTP ${it.code}")
                it.body?.string().orEmpty()
            }
        }

    private inline fun <reified T> parse(s: String): T =
        gson.fromJson(s, object : TypeToken<T>() {}.type)

    private fun enc(s: String) = URLEncoder.encode(s, "UTF-8")

    suspend fun profile(): Profile = parse(raw("dump/me", "/v3/", "GET", null))

    suspend fun person(email: String): Profile =
        parse(raw("dump/email/${enc(email)}", "/v3/", "GET", null))

    suspend fun timetable(start: String, end: String, email: String? = null, group: String? = null, auditorium: String? = null): List<Lesson> {
        var q = "ruz/lessons?start=$start&end=$end"
        if (email != null) q += "&email=${enc(email)}"
        if (group != null) q += "&group=$group"
        if (auditorium != null) q += "&auditorium=$auditorium"
        return parse(raw(q, "/v3/", "GET", null))
    }

    suspend fun search(query: String, type: String? = null): List<SearchResult> {
        var q = "dump/search?q=${enc(query)}"
        if (type != null) q += "&type=$type"
        return parse(raw(q, "/v3/", "GET", null))
    }

    suspend fun grades(): GradesResponse = parse(raw("grades", "/v2/", "GET", null))

    suspend fun deadlines(): DeadlinesResponse =
        parse(raw("deadlines", "/v2/", "POST", "{\"is_completed\":false}"))

    suspend fun notifications(): NotificationsResponse = parse(raw("notifications/feed", "/v2/", "GET", null))

    suspend fun cafes(): List<CafeGroup> = parse(raw("food/cafes", "/", "GET", null))
}
