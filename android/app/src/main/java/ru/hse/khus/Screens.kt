package ru.hse.khus

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ExitToApp
import androidx.compose.material.icons.automirrored.filled.OpenInNew
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import coil.compose.AsyncImage
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.util.Locale

private val MSK: ZoneId = ZoneId.of("Europe/Moscow")
private val RU = Locale("ru")
private fun iso(s: String): ZonedDateTime? = runCatching { Instant.parse(s).atZone(MSK) }.getOrNull()
private fun hm(z: ZonedDateTime) = z.format(DateTimeFormatter.ofPattern("HH:mm"))
private fun dayTitle(d: LocalDate) = d.format(DateTimeFormatter.ofPattern("EEEE, d MMMM", RU)).replaceFirstChar { it.uppercase() }
private fun dmy(z: ZonedDateTime) = z.format(DateTimeFormatter.ofPattern("d MMM", RU))
private fun isoDay(d: LocalDate) = d.toString()
private fun startOfWeek(d: LocalDate) = d.minusDays((d.dayOfWeek.value - 1).toLong())

sealed class Ld<out T> {
    data object Loading : Ld<Nothing>()
    data class Ok<T>(val v: T) : Ld<T>()
    data class Err(val m: String) : Ld<Nothing>()
}

@Composable
fun <T> loadState(vararg keys: Any?, block: suspend () -> T): Ld<T> {
    var s by remember(*keys) { mutableStateOf<Ld<T>>(Ld.Loading) }
    LaunchedEffect(*keys) {
        s = Ld.Loading
        s = try { Ld.Ok(block()) } catch (e: Exception) { Ld.Err(e.message ?: "ошибка") }
    }
    return s
}

@Composable
fun <T> Loader(state: Ld<T>, content: @Composable (T) -> Unit) {
    when (state) {
        is Ld.Loading -> Box(Modifier.fillMaxWidth().padding(40.dp), Alignment.Center) { CircularProgressIndicator() }
        is Ld.Err -> Box(Modifier.fillMaxWidth().padding(40.dp), Alignment.Center) {
            Text(state.m, color = MaterialTheme.colorScheme.onSurfaceVariant, textAlign = TextAlign.Center)
        }
        is Ld.Ok -> content(state.v)
    }
}

@Composable
fun Glass(modifier: Modifier = Modifier, radius: Int = 18, content: @Composable ColumnScope.() -> Unit) {
    Column(modifier.then(glassModifier(radius)).padding(14.dp), content = content)
}

@Composable
fun Pill(text: String) {
    Text(text, Modifier
        .clip(RoundedCornerShape(50))
        .background(Accent.copy(alpha = 0.22f))
        .padding(horizontal = 12.dp, vertical = 5.dp),
        fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
}

/* ---------------- login ---------------- */
@Composable
fun LoginScreen(busy: Boolean, error: String?, onLogin: () -> Unit) {
    Box(Modifier.fillMaxSize().padding(24.dp), Alignment.Center) {
        Glass(Modifier.widthIn(max = 420.dp), radius = 26) {
            Column(Modifier.fillMaxWidth().padding(16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                Box(Modifier.size(76.dp).clip(RoundedCornerShape(22.dp))
                    .background(Brush.verticalGradient(listOf(Accent, Accent2))), Alignment.Center) {
                    Icon(Icons.Default.School, null, tint = Color.White, modifier = Modifier.size(40.dp))
                }
                Spacer(Modifier.height(16.dp))
                Text("Khus HSE Client", fontSize = 24.sp, fontWeight = FontWeight.ExtraBold)
                Text("Неофициальный клиент HSE App X", color = MaterialTheme.colorScheme.onSurfaceVariant)
                Spacer(Modifier.height(20.dp))
                Button(onClick = onLogin, enabled = !busy, modifier = Modifier.fillMaxWidth()) {
                    if (busy) { CircularProgressIndicator(Modifier.size(18.dp), color = Color.White, strokeWidth = 2.dp); Spacer(Modifier.width(8.dp)) }
                    Text(if (busy) "Завершаем вход…" else "Войти через ВШЭ")
                }
                if (error != null) { Spacer(Modifier.height(12.dp)); Text(error, color = MaterialTheme.colorScheme.error, fontSize = 14.sp, textAlign = TextAlign.Center) }
            }
        }
    }
}

/* ---------------- main scaffold ---------------- */
enum class Tab(val title: String, val icon: ImageVector) {
    SCHEDULE("Расписание", Icons.Default.CalendarMonth),
    SEARCH("Поиск", Icons.Default.Search),
    GRADES("Оценки", Icons.Default.Grade),
    DEADLINES("Дедлайны", Icons.Default.Checklist),
    NOTIFS("Уведомления", Icons.Default.Notifications),
    INFO("Полезное", Icons.Default.Lightbulb),
    LECTURES("Конспекты", Icons.Default.Description),
    FOOD("Столовые", Icons.Default.Restaurant),
    PROFILE("Профиль", Icons.Default.Person),
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MainScreen(onLogout: () -> Unit) {
    var tab by rememberSaveable { mutableStateOf(Tab.SCHEDULE) }
    var avatar by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(Unit) { avatar = runCatching { Api.profile().avatarUrl }.getOrNull() }

    Box(Modifier.fillMaxSize()) {
    MainScaffold(tab, { tab = it }, avatar, onLogout)
    var last by remember { mutableStateOf<Lecture?>(null) }
    PdfOverlay.lecture?.let { last = it }
    androidx.compose.animation.AnimatedVisibility(
        visible = PdfOverlay.lecture != null,
        enter = androidx.compose.animation.slideInVertically { it } + androidx.compose.animation.fadeIn(),
        exit = androidx.compose.animation.slideOutVertically { it } + androidx.compose.animation.fadeOut(),
    ) {
        last?.let { l -> LecturePdfScreen(l) { PdfOverlay.lecture = null } }
    }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun MainScaffold(tab: Tab, setTab: (Tab) -> Unit, avatar: String?, onLogout: () -> Unit) {
    Scaffold(
        containerColor = Color.Transparent,
        topBar = {
            TopAppBar(
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
                navigationIcon = {
                    Box(Modifier.padding(start = 12.dp).size(38.dp).clip(CircleShape)
                        .clickable { setTab(Tab.PROFILE) }, Alignment.Center) {
                        if (avatar != null) AsyncImage(avatar, null, Modifier.size(38.dp).clip(CircleShape))
                        else Icon(Icons.Default.AccountCircle, null, Modifier.size(38.dp), tint = Accent)
                    }
                },
                title = { Text("Khus HSE", fontWeight = FontWeight.Bold) },
                actions = { IconButton(onClick = onLogout) { Icon(Icons.AutoMirrored.Filled.ExitToApp, "Выйти") } },
            )
        },
    ) { pad ->
        Column(Modifier.padding(pad).fillMaxSize()) {
            ScrollableTabRow(
                selectedTabIndex = tab.ordinal,
                containerColor = Color.Transparent,
                edgePadding = 12.dp,
                divider = {},
            ) {
                Tab.entries.forEach { t ->
                    Tab(selected = tab == t, onClick = { setTab(t) },
                        text = { Text(t.title, fontSize = 13.sp) })
                }
            }
            Box(Modifier.fillMaxSize()) {
                when (tab) {
                    Tab.SCHEDULE -> TimetableScreen()
                    Tab.SEARCH -> SearchScreen()
                    Tab.GRADES -> GradesScreen()
                    Tab.DEADLINES -> DeadlinesScreen()
                    Tab.NOTIFS -> NotificationsScreen()
                    Tab.INFO -> InfoScreen()
                    Tab.LECTURES -> LecturesScreen()
                    Tab.FOOD -> FoodScreen()
                    Tab.PROFILE -> ProfileScreen()
                }
            }
        }
    }
}

/* ---------------- timetable ---------------- */
@Composable
fun TimetableScreen(email: String? = null, group: String? = null, auditorium: String? = null, roomMode: Boolean = false) {
    var week by remember { mutableStateOf(startOfWeek(LocalDate.now(MSK))) }
    var teacher by remember { mutableStateOf<Pair<String, String>?>(null) }
    val end = week.plusDays(6)
    Column(Modifier.fillMaxSize()) {
        Row(Modifier.fillMaxWidth().padding(12.dp), verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center) {
            IconButton(onClick = { week = week.minusDays(7) }) { Icon(Icons.Default.ChevronLeft, null) }
            Text("${dmy(week.atStartOfDay(MSK))} – ${dmy(end.atStartOfDay(MSK))}", fontWeight = FontWeight.Medium)
            IconButton(onClick = { week = week.plusDays(7) }) { Icon(Icons.Default.ChevronRight, null) }
            IconButton(onClick = { week = startOfWeek(LocalDate.now(MSK)) }) { Icon(Icons.Default.Today, null) }
        }
        val st = loadState(week, email, group, auditorium) {
            Api.timetable(isoDay(week), isoDay(end), email, group, auditorium).sortedBy { it.dateStart }
        }
        Loader(st) { list ->
            if (list.isEmpty()) {
                Box(Modifier.fillMaxSize(), Alignment.Center) {
                    Text(if (roomMode) "Аудитория свободна всю неделю" else "Нет занятий",
                        color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            } else {
                val byDay = list.groupBy { iso(it.dateStart)?.toLocalDate() }
                LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(16.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    byDay.forEach { (day, lessons) ->
                        item { if (day != null) { Pill(dayTitle(day)); Spacer(Modifier.height(2.dp)) } }
                        items(lessons) { LessonCard(it) { e, n -> teacher = e to n } }
                    }
                }
            }
        }
    }
    teacher?.let { (e, n) -> PersonDialog(e, n) { teacher = null } }
}

@Composable
fun LessonCard(l: Lesson, onTeacher: (String, String) -> Unit) {
    val start = iso(l.dateStart); val endZ = iso(l.dateEnd)
    val now = start != null && endZ != null &&
        !ZonedDateTime.now(MSK).isBefore(start) && !ZonedDateTime.now(MSK).isAfter(endZ)
    val mod = if (now) glassModifier().then(Modifier.padding(0.dp)) else glassModifier()
    Row(Modifier.fillMaxWidth().then(mod).padding(14.dp)) {
        Column(horizontalAlignment = Alignment.End, modifier = Modifier.width(48.dp)) {
            Text(start?.let { hm(it) } ?: "", fontWeight = FontWeight.Bold, fontSize = 14.sp)
            Text(endZ?.let { hm(it) } ?: "", color = MaterialTheme.colorScheme.onSurfaceVariant, fontSize = 13.sp)
        }
        Box(Modifier.padding(horizontal = 10.dp).width(4.dp).heightIn(min = 40.dp)
            .clip(RoundedCornerShape(2.dp)).background(Accent))
        Column(Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(l.discipline ?: "—", fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f, false))
                if (now) { Spacer(Modifier.width(6.dp)); Pill("сейчас") }
            }
            l.type?.let { Text(it, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant) }
            if (!l.lecturer.isNullOrBlank()) {
                val email = l.lecturerEmail
                Text("👤 ${l.lecturer}", fontSize = 12.sp,
                    color = if (email.isNullOrBlank()) MaterialTheme.colorScheme.onSurfaceVariant else Accent,
                    modifier = if (email.isNullOrBlank()) Modifier else Modifier.clickable { onTeacher(email, l.lecturer) })
            }
            Text(listOfNotNull(l.auditorium, l.building).joinToString(" · "),
                fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

/* ---------------- search ---------------- */
@Composable
fun SearchScreen() {
    var kind by remember { mutableStateOf(0) } // 0 people 1 groups 2 rooms
    var query by remember { mutableStateOf("") }
    var submitted by remember { mutableStateOf<Pair<String, Int>?>(null) }
    var openResult by remember { mutableStateOf<SearchResult?>(null) }
    val kinds = listOf("Люди", "Группы", "Аудитории")

    Column(Modifier.fillMaxSize().padding(16.dp)) {
        TabRow(selectedTabIndex = kind, containerColor = Color.Transparent) {
            kinds.forEachIndexed { i, n -> Tab(selected = kind == i, onClick = { kind = i }, text = { Text(n) }) }
        }
        Spacer(Modifier.height(12.dp))
        OutlinedTextField(
            value = query, onValueChange = { query = it }, singleLine = true,
            label = { Text("ФИО, группа или аудитория") },
            trailingIcon = {
                IconButton(onClick = { if (query.trim().length >= 2) submitted = query.trim() to kind }) {
                    Icon(Icons.Default.Search, null)
                }
            },
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(12.dp))
        val sub = submitted
        if (sub != null) {
            val type = when (sub.second) { 1 -> "GROUP"; 2 -> "AUDITORIUM"; else -> null }
            val st = loadState(sub) { Api.search(sub.first, type) }
            Loader(st) { list ->
                if (list.isEmpty()) Box(Modifier.fillMaxWidth().padding(30.dp), Alignment.Center) { Text("Ничего не найдено", color = MaterialTheme.colorScheme.onSurfaceVariant) }
                else LazyColumn(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    items(list) { r ->
                        Row(Modifier.fillMaxWidth().then(glassModifier()).clickable { openResult = r }.padding(14.dp),
                            verticalAlignment = Alignment.CenterVertically) {
                            Column(Modifier.weight(1f)) {
                                Text(r.title, fontWeight = FontWeight.SemiBold)
                                val s = if (r.type == "AUDITORIUM") listOfNotNull(r.auditoriumType, r.description).joinToString(" · ") else r.description
                                if (!s.isNullOrBlank()) Text(s, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                            Icon(Icons.Default.ChevronRight, null, tint = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                }
            }
        } else {
            Box(Modifier.fillMaxSize(), Alignment.Center) {
                Text("Найдите студента, преподавателя,\nгруппу или аудиторию",
                    color = MaterialTheme.colorScheme.onSurfaceVariant, textAlign = TextAlign.Center)
            }
        }
    }
    openResult?.let { r ->
        when (r.type) {
            "AUDITORIUM" -> TimetableDialog("Аудитория ${r.room ?: r.title}", auditorium = r.id, roomMode = true) { openResult = null }
            "GROUP" -> TimetableDialog(r.label ?: r.title, group = r.id) { openResult = null }
            else -> PersonDialog(r.email ?: "", r.title) { openResult = null }
        }
    }
}

/* ---------------- dialogs ---------------- */
@Composable
fun TimetableDialog(title: String, email: String? = null, group: String? = null, auditorium: String? = null, roomMode: Boolean = false, onClose: () -> Unit) {
    Dialog(onDismissRequest = onClose) {
        Surface(shape = RoundedCornerShape(20.dp), color = MaterialTheme.colorScheme.background,
            modifier = Modifier.fillMaxWidth().fillMaxHeight(0.9f)) {
            Column {
                DialogHeader(title, onClose)
                TimetableScreen(email = email, group = group, auditorium = auditorium, roomMode = roomMode)
            }
        }
    }
}

@Composable
fun PersonDialog(email: String, name: String, onClose: () -> Unit) {
    Dialog(onDismissRequest = onClose) {
        Surface(shape = RoundedCornerShape(20.dp), color = MaterialTheme.colorScheme.background,
            modifier = Modifier.fillMaxWidth()) {
            Column(Modifier.padding(bottom = 12.dp)) {
                DialogHeader(name, onClose)
                if (email.isBlank()) { Text("Нет почты", Modifier.padding(16.dp)); return@Column }
                val st = loadState(email) { Api.person(email) }
                Loader(st) { p ->
                    Column(Modifier.verticalScroll(rememberScrollState()).padding(horizontal = 16.dp),
                        horizontalAlignment = Alignment.CenterHorizontally) {
                        if (p.avatarUrl != null) AsyncImage(p.avatarUrl, null, Modifier.size(84.dp).clip(CircleShape))
                        Spacer(Modifier.height(8.dp))
                        Text(p.fullName ?: name, fontWeight = FontWeight.Bold, fontSize = 18.sp)
                        Pill(if (p.type == "STAFF") "Сотрудник" else "Студент")
                        p.email?.let { Spacer(Modifier.height(6.dp)); Text("✉ $it", fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant) }
                        val edu = p.education?.firstOrNull()
                        if (edu != null) {
                            Spacer(Modifier.height(12.dp))
                            Glass(Modifier.fillMaxWidth()) {
                                kv("Программа", edu.programTitle); kv("Факультет", edu.facultyTitle); kv("Год поступления", edu.admissionYear)
                            }
                        }
                        p.staffPositions?.takeIf { it.isNotEmpty() }?.let { pos ->
                            Spacer(Modifier.height(10.dp))
                            Glass(Modifier.fillMaxWidth()) {
                                Text("Должности", fontWeight = FontWeight.Bold); Spacer(Modifier.height(4.dp))
                                pos.forEach { Text(listOfNotNull(it.title, it.department).joinToString(" · "), fontSize = 13.sp) }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun DialogHeader(title: String, onClose: () -> Unit) {
    Row(Modifier.fillMaxWidth().padding(start = 16.dp, end = 4.dp, top = 8.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(title, fontWeight = FontWeight.Bold, fontSize = 17.sp, modifier = Modifier.weight(1f))
        IconButton(onClick = onClose) { Icon(Icons.Default.Close, "Закрыть") }
    }
}

@Composable
private fun ColumnScope.kv(k: String, v: String?) {
    if (!v.isNullOrBlank()) Row(Modifier.fillMaxWidth().padding(vertical = 2.dp)) {
        Text(k, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.weight(1f), fontSize = 14.sp)
        Text(v, fontSize = 14.sp, textAlign = TextAlign.End)
    }
}

/* ---------------- grades ---------------- */
@Composable
fun GradesScreen() {
    var tab by remember { mutableStateOf(1) }
    Column(Modifier.fillMaxSize().padding(16.dp)) {
        TabRow(selectedTabIndex = tab, containerColor = Color.Transparent) {
            Tab(selected = tab == 0, onClick = { tab = 0 }, text = { Text("Ведомости") })
            Tab(selected = tab == 1, onClick = { tab = 1 }, text = { Text("Итоговые") })
        }
        Spacer(Modifier.height(12.dp))
        if (tab == 1) {
            val st = loadState { Api.grades() }
            Loader(st) { r ->
                LazyColumn(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    r.selectedAcademicYear?.let { item { Pill("Учебный год $it") } }
                    items(r.items) { g ->
                        Glass(Modifier.fillMaxWidth()) {
                            Text(g.discipline, fontWeight = FontWeight.Medium)
                            Text(listOfNotNull(g.typeRaw, g.moduleName, g.credits?.let { "$it кр." }).joinToString(" · "),
                                fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                    if (r.items.isEmpty()) item { Text("Оценок нет", color = MaterialTheme.colorScheme.onSurfaceVariant) }
                }
            }
        } else {
            Glass(Modifier.fillMaxWidth()) {
                Text("Ведомости", fontWeight = FontWeight.SemiBold)
                Text("Подключение Google-таблиц и пуши — в десктоп-версии. В Android добавим в следующей итерации.",
                    fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

/* ---------------- deadlines ---------------- */
@Composable
fun DeadlinesScreen() {
    val st = loadState { Api.deadlines().items.sortedBy { it.expiresAt ?: "" } }
    Loader(st) { items ->
        if (items.isEmpty()) Center("Активных дедлайнов нет")
        else LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            items(items) { d ->
                Row(Modifier.fillMaxWidth().then(glassModifier()).padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.RadioButtonUnchecked, null, tint = Accent)
                    Spacer(Modifier.width(10.dp))
                    Column {
                        Text(d.title, fontWeight = FontWeight.Medium)
                        d.expiresAt?.let { iso(it)?.let { z ->
                            val over = z.isBefore(ZonedDateTime.now(MSK))
                            Text("до " + z.format(DateTimeFormatter.ofPattern("d MMMM, HH:mm", RU)),
                                fontSize = 12.sp, color = if (over) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurfaceVariant)
                        } }
                    }
                }
            }
        }
    }
}

/* ---------------- notifications ---------------- */
@Composable
fun NotificationsScreen() {
    val st = loadState { Api.notifications().items }
    Loader(st) { items ->
        if (items.isEmpty()) Center("Уведомлений нет")
        else LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            items(items) { n ->
                Glass(Modifier.fillMaxWidth()) {
                    n.title?.let { Text(it, fontWeight = FontWeight.SemiBold) }
                    n.content?.let { Text(it, fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant) }
                }
            }
        }
    }
}

/* ---------------- food ---------------- */
@Composable
fun FoodScreen() {
    val st = loadState { Api.cafes().flatMap { it.cafes } }
    val wd = listOf("sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday")[LocalDate.now(MSK).dayOfWeek.value % 7]
    Loader(st) { cafes ->
        LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            items(cafes) { c ->
                val t = c.openingHours?.firstOrNull { it.dayOfWeek == wd }
                Row(Modifier.fillMaxWidth().then(glassModifier()).padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.Restaurant, null, tint = Accent)
                    Spacer(Modifier.width(10.dp))
                    Column(Modifier.weight(1f)) {
                        Text(c.cafeName, fontWeight = FontWeight.Medium)
                        if (t != null) Text(if (t.isOpen) "Сегодня ${t.startTime}–${t.endTime}" else "Сегодня закрыто",
                            fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }
        }
    }
}

/* ---------------- profile ---------------- */
@Composable
fun ProfileScreen() {
    val st = loadState { Api.profile() }
    Loader(st) { p ->
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp)) {
            Glass(Modifier.fillMaxWidth(), radius = 24) {
                Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
                    if (p.avatarUrl != null) AsyncImage(p.avatarUrl, null, Modifier.size(92.dp).clip(CircleShape))
                    Spacer(Modifier.height(8.dp))
                    Text(p.fullName ?: "", fontWeight = FontWeight.Bold, fontSize = 20.sp)
                    p.email?.let { Text("✉ $it", color = MaterialTheme.colorScheme.onSurfaceVariant, fontSize = 13.sp) }
                    p.description?.let { Spacer(Modifier.height(8.dp)); Pill(it) }
                }
            }
            val edu = p.education?.firstOrNull()
            if (edu != null) {
                Spacer(Modifier.height(12.dp))
                Glass(Modifier.fillMaxWidth(), radius = 24) {
                    Text("Обучение", fontWeight = FontWeight.Bold); Spacer(Modifier.height(4.dp))
                    kv("Программа", edu.programTitle); kv("Факультет", edu.facultyTitle); kv("Год поступления", edu.admissionYear)
                }
            }
        }
    }
}

/* ---------------- static tabs ---------------- */
@Composable
fun InfoScreen() {
    val posts = listOf(
        "7 ноября 2026" to "Поздравляю всех с написанием Алгебры!!!! Отдыхаем 🫶🏻",
        "30 октября 2026" to "Поздравляю всех с окончанием первого модуля, первой сессии. А теперь вновь дедлайны…",
        "8 сентября 2026" to "Выбор НИСов (до 10.09 09:00).",
        "4 сентября 2026" to "Открылся SmartWay для выбора факультатива по английскому. ❗️НИСы не выбирать❗️",
        "3 сентября 2026" to "Формула оценивания Алгебра, 1 семестр.",
    )
    LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        item {
            Row(Modifier.fillMaxWidth().then(glassModifier()).padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Default.Send, null, tint = Accent)
                Spacer(Modifier.width(10.dp))
                Column { Text("ПИ объявления", fontWeight = FontWeight.Bold); Text("Связь: @mrs_revival", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant) }
            }
        }
        items(posts) { (d, t) -> Glass(Modifier.fillMaxWidth()) { Pill(d); Spacer(Modifier.height(8.dp)); Text(t) } }
        item { Text("By Renata Ilyasova", Modifier.fillMaxWidth(), color = MaterialTheme.colorScheme.onSurfaceVariant, fontSize = 11.sp, textAlign = TextAlign.Center) }
    }
}

private fun subjectIcon(s: String): ImageVector = when (s) {
    "Алгебра" -> Icons.Default.Functions
    "Матанализ" -> Icons.Default.Calculate
    else -> Icons.Default.Tag
}

@Composable
fun LecturesScreen() {
    var subject by rememberSaveable { mutableStateOf<String?>(null) }
    val uri = androidx.compose.ui.platform.LocalUriHandler.current
    val subjects = remember { lectures.map { it.subject }.distinct() }
    val shown = remember(subject) {
        lectures.filter { subject == null || it.subject == subject }
            .sortedWith(compareBy<Lecture> { it.subject }.thenByDescending { it.number }.thenByDescending { it.file })
    }

    LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        item {
            Row(Modifier.fillMaxWidth().then(glassModifier()).clickable { uri.openUri("https://t.me/marusya_pishet_konspecty") }.padding(14.dp),
                verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.AutoMirrored.Filled.Send, null, tint = Accent)
                Spacer(Modifier.width(10.dp))
                Column(Modifier.weight(1f)) {
                    Text("Маруся Конспектовна", fontWeight = FontWeight.Bold)
                    Text("${lectures.size} конспектов · ФКН ПИ 26", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                Icon(Icons.AutoMirrored.Filled.OpenInNew, "Открыть канал", tint = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.size(18.dp))
            }
        }
        item {
            Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                FilterChip(selected = subject == null, onClick = { subject = null }, label = { Text("Все") })
                subjects.forEach { s ->
                    FilterChip(selected = subject == s, onClick = { subject = if (subject == s) null else s },
                        label = { Text(s) }, leadingIcon = { Icon(subjectIcon(s), null, Modifier.size(16.dp)) })
                }
            }
        }
        shown.groupBy { it.subject }.forEach { (subj, list) ->
            item(key = "h-$subj") {
                Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top = 4.dp)) {
                    Icon(subjectIcon(subj), null, tint = Accent, modifier = Modifier.size(18.dp))
                    Spacer(Modifier.width(6.dp))
                    Text(subj, fontWeight = FontWeight.Bold, fontSize = 16.sp)
                }
            }
            items(list, key = { it.file }) { l ->
                Row(Modifier.fillMaxWidth().then(glassModifier()).clickable { PdfOverlay.lecture = l }.padding(14.dp),
                    verticalAlignment = Alignment.CenterVertically) {
                    Box(Modifier.size(42.dp).clip(RoundedCornerShape(12.dp)).background(Accent.copy(alpha = 0.15f)), Alignment.Center) {
                        Text("№${l.number}", fontWeight = FontWeight.Bold, fontSize = 13.sp, color = Accent)
                    }
                    Spacer(Modifier.width(12.dp))
                    Column(Modifier.weight(1f)) {
                        Text("Лекция ${l.number}", fontWeight = FontWeight.SemiBold)
                        if (l.topic.isNotBlank()) Text(l.topic, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 2)
                        Text(l.date, fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    Icon(Icons.Default.PictureAsPdf, null, tint = Accent)
                }
            }
        }
        item { Text("By Mariya Savonik", Modifier.fillMaxWidth().padding(top = 8.dp), color = MaterialTheme.colorScheme.onSurfaceVariant, fontSize = 11.sp, textAlign = TextAlign.Center) }
    }

}

/** Full-screen layer drawn above the whole app (set from LecturesScreen, rendered in MainScreen). */
object PdfOverlay { var lecture by mutableStateOf<Lecture?>(null) }

@Composable
fun LecturePdfScreen(l: Lecture, onClose: () -> Unit) {
    androidx.activity.compose.BackHandler(onBack = onClose)
    run {
        Surface(Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
            Column(Modifier.fillMaxSize().systemBarsPadding()) {
                Row(Modifier.fillMaxWidth().padding(start = 16.dp, end = 4.dp, top = 6.dp, bottom = 6.dp),
                    verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text("${l.subject} · Лекция №${l.number}", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                        if (l.topic.isNotBlank()) Text(l.topic, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1)
                    }
                    IconButton(onClick = onClose) { Icon(Icons.Default.Close, "Закрыть") }
                }
                PdfViewer(l.file, Modifier.weight(1f))
            }
        }
    }
}

@Composable
private fun Center(text: String) {
    Box(Modifier.fillMaxSize(), Alignment.Center) { Text(text, color = MaterialTheme.colorScheme.onSurfaceVariant) }
}
