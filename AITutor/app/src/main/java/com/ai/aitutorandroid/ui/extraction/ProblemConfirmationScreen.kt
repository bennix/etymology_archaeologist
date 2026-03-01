package com.ai.aitutorandroid.ui.extraction

import android.graphics.Bitmap
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.rememberTransformableState
import androidx.compose.foundation.gestures.transformable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.MergeType
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.graphicsLayer
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.ai.aitutorandroid.models.Problem
import com.ai.aitutorandroid.viewmodels.AppViewModel

// ─── Segment model ─────────────────────────────────────────────────────────

private sealed class ProblemSegment {
    data class Body(val text: String) : ProblemSegment()
    data class MetaPost(val code: String) : ProblemSegment()
    data class FigureDesc(val desc: String) : ProblemSegment()
}

/**
 * Split fullLatexText into segments:
 *   ```metapost … ```  → MetaPost code block
 *   【图形描述】…【/图形描述】 → FigureDesc block
 *   everything else    → Body text
 */
private fun parseSegments(raw: String): List<ProblemSegment> {
    val result = mutableListOf<ProblemSegment>()
    val combined = Regex(
        """(```metapost\s*\n[\s\S]*?\n?```)|(【图形描述】[\s\S]*?【/图形描述】)""",
        RegexOption.IGNORE_CASE
    )
    var cursor = 0
    for (match in combined.findAll(raw)) {
        val before = raw.substring(cursor, match.range.first).trim()
        if (before.isNotEmpty()) result += ProblemSegment.Body(before)
        when {
            match.value.startsWith("```metapost", ignoreCase = true) -> {
                val code = match.value
                    .removePrefix("```metapost").removeSuffix("```").trim()
                result += ProblemSegment.MetaPost(code)
            }
            match.value.startsWith("【图形描述】") -> {
                val desc = match.value
                    .removePrefix("【图形描述】").removeSuffix("【/图形描述】").trim()
                result += ProblemSegment.FigureDesc(desc)
            }
        }
        cursor = match.range.last + 1
    }
    val tail = raw.substring(cursor).trim()
    if (tail.isNotEmpty()) result += ProblemSegment.Body(tail)
    return result
}

// ─── Screen ────────────────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ProblemConfirmationScreen(
    viewModel: AppViewModel,
    onStartSolving: () -> Unit,
    onBack: () -> Unit
) {
    val problems by viewModel.problems.collectAsState()
    val images   by viewModel.capturedImages.collectAsState()
    val selectedCount = problems.count { it.isSelected }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("确认题目") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, null)
                    }
                }
            )
        },
        bottomBar = {
            Surface(shadowElevation = 4.dp) {
                Button(
                    onClick = onStartSolving,
                    enabled = selectedCount > 0,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp)
                        .height(52.dp)
                ) {
                    Text("开始解题 ($selectedCount 题)", fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
                }
            }
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(top = padding.calculateTopPadding(), bottom = padding.calculateBottomPadding())
        ) {
            // ── Top viewport: extracted / edit content ───────────────────
            LazyColumn(
                contentPadding = PaddingValues(
                    start = 16.dp, end = 16.dp,
                    top = 8.dp, bottom = 8.dp
                ),
                verticalArrangement = Arrangement.spacedBy(12.dp),
                modifier = Modifier.weight(1f)
            ) {
                itemsIndexed(problems) { index, problem ->
                    ProblemCard(
                        problem = problem,
                        showMergeButton = index < problems.size - 1,
                        onToggleSelect = { viewModel.toggleProblemSelection(problem.id) },
                        onMergeWithNext = { viewModel.mergeProblems(index, index + 1) },
                        onSaveEdit = { newText -> viewModel.updateProblemText(problem.id, newText) }
                    )
                }
            }

            // ── Bottom viewport: original images ─────────────────────────
            if (images.isNotEmpty()) {
                HorizontalDivider()
                ImageViewerPanel(
                    images = images,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(240.dp)
                )
            }
        }
    }
}

// ─── Problem card ──────────────────────────────────────────────────────────

@Composable
private fun ProblemCard(
    problem: Problem,
    showMergeButton: Boolean,
    onToggleSelect: () -> Unit,
    onMergeWithNext: () -> Unit,
    onSaveEdit: (String) -> Unit
) {
    var isEditing by remember { mutableStateOf(false) }
    var editText by remember(problem.id) { mutableStateOf(problem.fullLatexText) }
    val segments = remember(problem.id, problem.fullLatexText) { parseSegments(problem.fullLatexText) }

    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {

            // ── Header row ──────────────────────────────────────────────
            Row(verticalAlignment = Alignment.CenterVertically) {
                Checkbox(
                    checked = problem.isSelected,
                    onCheckedChange = { onToggleSelect() }
                )
                Spacer(Modifier.width(8.dp))
                Text(
                    "题目 ${problem.number}",
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 16.sp,
                    modifier = Modifier.weight(1f)
                )
                IconButton(onClick = {
                    if (isEditing) {
                        onSaveEdit(editText)
                        isEditing = false
                    } else {
                        editText = problem.fullLatexText
                        isEditing = true
                    }
                }) {
                    Icon(
                        imageVector = if (isEditing) Icons.Filled.Check else Icons.Filled.Edit,
                        contentDescription = if (isEditing) "保存" else "编辑",
                        tint = if (isEditing) MaterialTheme.colorScheme.primary
                               else MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }

            Spacer(Modifier.height(8.dp))

            // ── Inline LaTeX editor ──────────────────────────────────────
            if (isEditing) {
                OutlinedTextField(
                    value = editText,
                    onValueChange = { editText = it },
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(min = 140.dp),
                    label = { Text("LaTeX / Markdown 原文", fontSize = 12.sp) },
                    textStyle = LocalTextStyle.current.copy(
                        fontFamily = FontFamily.Monospace,
                        fontSize = 13.sp,
                        lineHeight = 20.sp
                    ),
                    minLines = 6
                )
                Spacer(Modifier.height(8.dp))
            }

            // ── Segments ────────────────────────────────────────────────
            segments.forEach { seg ->
                when (seg) {
                    is ProblemSegment.Body -> {
                        Text(
                            text = seg.text,
                            fontSize = 14.sp,
                            lineHeight = 22.sp,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                    }
                    is ProblemSegment.MetaPost -> {
                        CollapsibleBlock(
                            label = "MetaPost 图形代码",
                            icon = {
                                Icon(
                                    Icons.Filled.Code, null,
                                    modifier = Modifier.size(15.dp),
                                    tint = MaterialTheme.colorScheme.primary
                                )
                            }
                        ) {
                            Text(
                                text = seg.code,
                                fontFamily = FontFamily.Monospace,
                                fontSize = 12.sp,
                                lineHeight = 18.sp,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .horizontalScroll(rememberScrollState())
                                    .padding(horizontal = 12.dp, vertical = 8.dp)
                            )
                        }
                    }
                    is ProblemSegment.FigureDesc -> {
                        CollapsibleBlock(
                            label = "图形描述",
                            icon = {
                                Icon(
                                    Icons.Filled.Image, null,
                                    modifier = Modifier.size(15.dp),
                                    tint = MaterialTheme.colorScheme.secondary
                                )
                            }
                        ) {
                            Text(
                                text = seg.desc,
                                fontSize = 13.sp,
                                lineHeight = 20.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp)
                            )
                        }
                    }
                }
                Spacer(Modifier.height(6.dp))
            }

            // ── Known data ───────────────────────────────────────────────
            if (problem.knownDataMarkdown.isNotEmpty()) {
                HorizontalDivider(modifier = Modifier.padding(vertical = 6.dp))
                Text(
                    "已知条件",
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Medium,
                    color = MaterialTheme.colorScheme.primary
                )
                Spacer(Modifier.height(4.dp))
                Text(
                    text = problem.knownDataMarkdown,
                    fontSize = 13.sp,
                    lineHeight = 20.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            // ── Merge button ─────────────────────────────────────────────
            if (showMergeButton) {
                Spacer(Modifier.height(8.dp))
                TextButton(
                    onClick = onMergeWithNext,
                    modifier = Modifier.align(Alignment.End)
                ) {
                    Icon(
                        Icons.AutoMirrored.Filled.MergeType, null,
                        modifier = Modifier.size(16.dp)
                    )
                    Spacer(Modifier.width(4.dp))
                    Text("与下一题合并", fontSize = 13.sp)
                }
            }
        }
    }
}

// ─── Collapsible block ─────────────────────────────────────────────────────

@Composable
private fun CollapsibleBlock(
    label: String,
    icon: @Composable () -> Unit,
    content: @Composable () -> Unit
) {
    var expanded by remember { mutableStateOf(false) }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(6.dp))
            .background(MaterialTheme.colorScheme.surfaceVariant)
    ) {
        // ── Tap header to expand / collapse ──────────────────────────────
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clickable { expanded = !expanded }
                .padding(horizontal = 10.dp, vertical = 7.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            icon()
            Spacer(Modifier.width(6.dp))
            Text(
                text = label,
                fontSize = 12.sp,
                fontWeight = FontWeight.Medium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.weight(1f)
            )
            Icon(
                imageVector = if (expanded) Icons.Default.ExpandLess else Icons.Default.ExpandMore,
                contentDescription = if (expanded) "收起" else "展开",
                modifier = Modifier.size(16.dp),
                tint = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }

        // ── Animated body ─────────────────────────────────────────────────
        AnimatedVisibility(visible = expanded) {
            Column {
                HorizontalDivider(color = MaterialTheme.colorScheme.outline.copy(alpha = 0.3f))
                content()
            }
        }
    }
}

// ─── Image viewer panel ────────────────────────────────────────────────────

@OptIn(androidx.compose.foundation.ExperimentalFoundationApi::class)
@Composable
private fun ImageViewerPanel(
    images: List<Bitmap>,
    modifier: Modifier = Modifier
) {
    // Per-page transform state — keyed by page index
    val scaleMap  = remember { mutableStateMapOf<Int, Float>() }
    val offsetMap = remember { mutableStateMapOf<Int, Offset>() }

    val pagerState   = rememberPagerState(pageCount = { images.size })
    val currentPage  = pagerState.currentPage
    val currentScale = scaleMap[currentPage] ?: 1f

    Box(modifier = modifier.background(Color(0xFF111111))) {

        HorizontalPager(
            state = pagerState,
            modifier = Modifier.fillMaxSize(),
            // Disable horizontal swipe while zoomed in so pan gesture wins
            userScrollEnabled = currentScale <= 1.05f
        ) { page ->
            val scale  = scaleMap[page]  ?: 1f
            val offset = offsetMap[page] ?: Offset.Zero

            val transformState = rememberTransformableState { zoomChange, panChange, _ ->
                val prevScale  = scaleMap[page]  ?: 1f
                val prevOffset = offsetMap[page] ?: Offset.Zero
                val newScale   = (prevScale * zoomChange).coerceIn(1f, 5f)
                scaleMap[page]  = newScale
                offsetMap[page] = if (newScale > 1f) prevOffset + panChange else Offset.Zero
            }

            Image(
                bitmap = images[page].asImageBitmap(),
                contentDescription = "原图 ${page + 1}",
                contentScale = ContentScale.Fit,
                modifier = Modifier
                    .fillMaxSize()
                    .graphicsLayer {
                        scaleX = scale
                        scaleY = scale
                        translationX = offset.x
                        translationY = offset.y
                    }
                    .transformable(state = transformState)
            )
        }

        // ── Zoom controls (top-right) ────────────────────────────────────
        Column(
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(6.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            ZoomIconButton(Icons.Filled.ZoomIn) {
                val pg = pagerState.currentPage
                scaleMap[pg] = ((scaleMap[pg] ?: 1f) * 1.5f).coerceAtMost(5f)
            }
            ZoomIconButton(Icons.Filled.ZoomOut) {
                val pg = pagerState.currentPage
                val ns = ((scaleMap[pg] ?: 1f) / 1.5f).coerceAtLeast(1f)
                scaleMap[pg]  = ns
                if (ns <= 1f) offsetMap[pg] = Offset.Zero
            }
            ZoomIconButton(Icons.Filled.ZoomOutMap) {
                val pg = pagerState.currentPage
                scaleMap[pg]  = 1f
                offsetMap[pg] = Offset.Zero
            }
        }

        // ── Page counter badge (top-left, only when multiple images) ──────
        if (images.size > 1) {
            Text(
                text = "${currentPage + 1} / ${images.size}",
                color = Color.White,
                fontSize = 11.sp,
                modifier = Modifier
                    .align(Alignment.TopStart)
                    .padding(6.dp)
                    .background(Color.Black.copy(alpha = 0.55f), RoundedCornerShape(4.dp))
                    .padding(horizontal = 6.dp, vertical = 2.dp)
            )

            // ── Page dots (bottom-center) ─────────────────────────────────
            Row(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(bottom = 8.dp),
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                images.indices.forEach { i ->
                    val active = pagerState.currentPage == i
                    Box(
                        modifier = Modifier
                            .size(if (active) 8.dp else 5.dp)
                            .background(
                                if (active) Color.White else Color.White.copy(alpha = 0.4f),
                                CircleShape
                            )
                    )
                }
            }
        }
    }
}

@Composable
private fun ZoomIconButton(icon: ImageVector, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .size(32.dp)
            .background(Color.Black.copy(alpha = 0.55f), CircleShape)
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = Color.White,
            modifier = Modifier.size(18.dp)
        )
    }
}
