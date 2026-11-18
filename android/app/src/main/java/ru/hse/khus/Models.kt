package ru.hse.khus

import com.google.gson.annotations.SerializedName

data class TokenResponse(
    @SerializedName("access_token") val accessToken: String?,
    @SerializedName("refresh_token") val refreshToken: String?,
    @SerializedName("expires_in") val expiresIn: Long = 300,
    val error: String? = null,
)

data class Education(
    @SerializedName("program_title") val programTitle: String? = null,
    @SerializedName("faculty_title") val facultyTitle: String? = null,
    @SerializedName("start_year") val startYear: String? = null,
    @SerializedName("degree_level") val degreeLevel: String? = null,
    @SerializedName("group_title") val groupTitle: String? = null,
) {
    val admissionYear: String?
        get() {
            val g = groupTitle ?: return startYear
            val digits = g.dropWhile { !it.isDigit() }.takeWhile { it.isDigit() }
            return if (digits.length >= 2) "20" + digits.take(2) else startYear
        }
}

data class Profile(
    val id: String? = null,
    @SerializedName("full_name") val fullName: String? = null,
    val email: String? = null,
    val description: String? = null,
    val type: String? = null,
    @SerializedName("avatar_url") val avatarUrl: String? = null,
    val campus: String? = null,
    @SerializedName("staff_email_personal") val staffEmailPersonal: String? = null,
    @SerializedName("staff_phone_mobile") val staffPhoneMobile: String? = null,
    @SerializedName("staff_positions") val staffPositions: List<StaffPosition>? = null,
    val education: List<Education>? = null,
)

data class StaffPosition(
    val title: String? = null,
    val department: String? = null,
    val subdivision: String? = null,
)

data class Lesson(
    val id: String = "",
    val discipline: String? = null,
    val type: String? = null,
    val building: String? = null,
    val auditorium: String? = null,
    @SerializedName("date_start") val dateStart: String = "",
    @SerializedName("date_end") val dateEnd: String = "",
    val lecturer: String? = null,
    @SerializedName("lecturer_email") val lecturerEmail: String? = null,
)

data class GradesResponse(
    val items: List<Grade> = emptyList(),
    @SerializedName("selected_academic_year") val selectedAcademicYear: String? = null,
)

data class Grade(
    val id: String = "",
    val discipline: String = "",
    @SerializedName("type_raw") val typeRaw: String? = null,
    @SerializedName("module_name") val moduleName: String? = null,
    val credits: Int? = null,
)

data class DeadlinesResponse(
    val items: List<Deadline> = emptyList(),
    @SerializedName("next_cursor") val nextCursor: String? = null,
)

data class Deadline(
    val id: String = "",
    val title: String = "",
    @SerializedName("expires_at") val expiresAt: String? = null,
)

data class SearchResult(
    val id: String = "",
    val email: String? = null,
    @SerializedName("full_name") val fullName: String? = null,
    val label: String? = null,
    val room: String? = null,
    val description: String? = null,
    val type: String? = null,
    @SerializedName("auditorium_type") val auditoriumType: String? = null,
) {
    val title: String get() = fullName ?: label ?: room ?: id
}

data class NotificationsResponse(
    val items: List<Notice> = emptyList(),
)

data class Notice(
    @SerializedName("external_id") val externalId: String? = null,
    val title: String? = null,
    val content: String? = null,
    val image: String? = null,
)

data class CafeGroup(val cafes: List<Cafe> = emptyList())

data class Cafe(
    @SerializedName("cafe_id") val cafeId: String = "",
    @SerializedName("cafe_name") val cafeName: String = "",
    @SerializedName("opening_hours") val openingHours: List<OpeningHour>? = null,
)

data class OpeningHour(
    @SerializedName("day_of_week") val dayOfWeek: String = "",
    @SerializedName("is_open") val isOpen: Boolean = false,
    @SerializedName("start_time") val startTime: String? = null,
    @SerializedName("end_time") val endTime: String? = null,
)
