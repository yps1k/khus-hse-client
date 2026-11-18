package ru.hse.khus

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color as AColor
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.calculatePan
import androidx.compose.foundation.gestures.calculateZoom
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import java.io.File

/** Thin wrapper over PdfRenderer. PdfRenderer allows one open page at a time, hence the mutex. */
class PdfDoc private constructor(
    private val pfd: ParcelFileDescriptor,
    private val renderer: PdfRenderer,
    /** width / height of each page, so placeholders have the right size before rendering. */
    val ratios: List<Float>,
) {
    private val lock = Mutex()
    val pageCount get() = ratios.size

    suspend fun render(index: Int, widthPx: Int): Bitmap = lock.withLock {
        withContext(Dispatchers.IO) {
            renderer.openPage(index).use { page ->
                val w = widthPx.coerceIn(1, 2000)
                val h = (w.toFloat() * page.height / page.width).toInt().coerceAtLeast(1)
                val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
                bmp.eraseColor(AColor.WHITE)
                page.render(bmp, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                bmp
            }
        }
    }

    fun close() {
        runCatching { renderer.close() }
        runCatching { pfd.close() }
    }

    companion object {
        /** Copies the asset into cache (PdfRenderer needs a seekable file) and opens it. */
        suspend fun openAsset(ctx: Context, name: String): PdfDoc = withContext(Dispatchers.IO) {
            val dir = File(ctx.cacheDir, "lectures").apply { mkdirs() }
            val file = File(dir, name)
            if (!file.exists() || file.length() == 0L) {
                val tmp = File(dir, "$name.part")
                ctx.assets.open(name).use { input -> tmp.outputStream().use { input.copyTo(it) } }
                tmp.renameTo(file)
            }
            val pfd = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
            val renderer = PdfRenderer(pfd)
            val ratios = (0 until renderer.pageCount).map { i ->
                renderer.openPage(i).use { it.width.toFloat() / it.height.coerceAtLeast(1) }
            }
            PdfDoc(pfd, renderer, ratios)
        }
    }
}

@Composable
fun PdfViewer(assetName: String, modifier: Modifier = Modifier) {
    val ctx = LocalContext.current
    var state by remember(assetName) { mutableStateOf<Ld<PdfDoc>>(Ld.Loading) }
    LaunchedEffect(assetName) {
        state = try { Ld.Ok(PdfDoc.openAsset(ctx, assetName)) }
        catch (e: Exception) { Ld.Err("Не удалось открыть PDF: ${e.message ?: "ошибка"}") }
    }
    DisposableEffect(assetName) {
        onDispose { (state as? Ld.Ok)?.v?.close() }
    }

    Loader(state) { doc -> PdfPages(doc, modifier) }
}

@Composable
private fun PdfPages(doc: PdfDoc, modifier: Modifier) {
    val list = rememberLazyListState()
    var widthPx by remember { mutableStateOf(0) }
    var scale by remember { mutableStateOf(1f) }
    var offsetX by remember { mutableStateOf(0f) }
    val animScale by animateFloatAsState(scale, label = "zoom")

    fun clampX(x: Float, s: Float) = x.coerceIn(-(s - 1f) * widthPx / 2f, (s - 1f) * widthPx / 2f)

    Box(
        modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f))
            .onSizeChanged { widthPx = it.width }
            // Pinch to zoom (2 fingers); one finger pans sideways when zoomed, list still scrolls vertically.
            .pointerInput(Unit) {
                awaitEachGesture {
                    awaitFirstDown(requireUnconsumed = false)
                    do {
                        val event = awaitPointerEvent()
                        val pressed = event.changes.count { it.pressed }
                        if (pressed >= 2) {
                            val z = event.calculateZoom()
                            val s = (scale * z).coerceIn(1f, 4f)
                            scale = s
                            offsetX = clampX(offsetX + event.calculatePan().x, s)
                            event.changes.forEach { it.consume() }
                        } else if (scale > 1f) {
                            offsetX = clampX(offsetX + event.calculatePan().x, scale)
                        }
                    } while (event.changes.any { it.pressed })
                }
            }
            .pointerInput(Unit) {
                detectTapGestures(onDoubleTap = {
                    if (scale > 1f) { scale = 1f; offsetX = 0f } else scale = 2.5f
                })
            }
    ) {
        if (widthPx > 0) {
            val pageWidth = widthPx - with(androidx.compose.ui.platform.LocalDensity.current) { 24.dp.roundToPx() }
            LazyColumn(
                state = list,
                modifier = Modifier
                    .fillMaxSize()
                    .graphicsLayer {
                        scaleX = animScale; scaleY = animScale
                        translationX = offsetX
                    },
                contentPadding = PaddingValues(12.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                items(doc.pageCount) { i -> PdfPage(doc, i, pageWidth) }
            }
        }

        // page counter
        val current by remember { derivedStateOf { list.firstVisibleItemIndex + 1 } }
        Text(
            "$current / ${doc.pageCount}",
            Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = 18.dp)
                .clip(RoundedCornerShape(50))
                .background(Color.Black.copy(alpha = 0.55f))
                .padding(horizontal = 14.dp, vertical = 6.dp),
            color = Color.White, fontSize = 13.sp,
        )
    }
}

@Composable
private fun PdfPage(doc: PdfDoc, index: Int, widthPx: Int) {
    var bmp by remember(index, widthPx) { mutableStateOf<Bitmap?>(null) }
    LaunchedEffect(index, widthPx) {
        bmp = runCatching { doc.render(index, widthPx) }.getOrNull()
    }
    val ratio = doc.ratios[index]
    Box(
        Modifier
            .fillMaxWidth()
            .aspectRatio(ratio)
            .clip(RoundedCornerShape(6.dp))
            .background(Color.White),
        contentAlignment = Alignment.Center,
    ) {
        val b = bmp
        if (b != null) {
            Image(b.asImageBitmap(), "Страница ${index + 1}", Modifier.fillMaxSize(), contentScale = ContentScale.FillBounds)
        } else {
            CircularProgressIndicator(Modifier.size(28.dp), strokeWidth = 2.dp, color = Accent)
        }
    }
}
