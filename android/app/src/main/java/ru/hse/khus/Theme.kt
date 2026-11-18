package ru.hse.khus

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

val Accent = Color(0xFF1E53D8)
val Accent2 = Color(0xFF062A86)

private val DarkColors = darkColorScheme(
    primary = Color(0xFF6E97FF), onPrimary = Color.White,
    background = Color(0xFF0B1020), onBackground = Color(0xFFEEF1F8),
    surface = Color(0xFF131A33), onSurface = Color(0xFFEEF1F8),
    surfaceVariant = Color(0xFF1B2440), onSurfaceVariant = Color(0xFF9AA3BD),
)
private val LightColors = lightColorScheme(
    primary = Accent, onPrimary = Color.White,
    background = Color(0xFFEEF2FB), onBackground = Color(0xFF101422),
    surface = Color(0xFFFFFFFF), onSurface = Color(0xFF101422),
    surfaceVariant = Color(0xFFE6ECFA), onSurfaceVariant = Color(0xFF5B6478),
)

@Composable
fun KhusTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = if (isSystemInDarkTheme()) DarkColors else LightColors,
        typography = MaterialTheme.typography,
        content = content,
    )
}

@Composable
fun AppBackground(content: @Composable () -> Unit) {
    val dark = isSystemInDarkTheme()
    val brush = if (dark)
        Brush.linearGradient(listOf(Color(0xFF0B1020), Color(0xFF0E1733)))
    else
        Brush.linearGradient(listOf(Color(0xFFEEF2FB), Color(0xFFDFE7FB)))
    Box(Modifier.fillMaxSize().background(brush)) { content() }
}

/** Translucent frosted card. */
@Composable
fun glassModifier(radius: Int = 18): Modifier {
    val dark = isSystemInDarkTheme()
    val fill = if (dark) Color(0x4D1E2A4E) else Color(0x8CFFFFFF)
    val stroke = if (dark) Color(0x2E8CA6FF) else Color(0xA6FFFFFF)
    return Modifier
        .border(1.dp, stroke, RoundedCornerShape(radius.dp))
        .background(fill, RoundedCornerShape(radius.dp))
}
