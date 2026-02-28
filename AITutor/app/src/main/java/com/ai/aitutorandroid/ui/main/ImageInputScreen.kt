package com.ai.aitutorandroid.ui.main

import android.Manifest
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.itemsIndexed
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AddAPhoto
import androidx.compose.material.icons.filled.AddPhotoAlternate
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.FolderOpen
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import com.ai.aitutorandroid.models.Subject
import com.ai.aitutorandroid.viewmodels.AppViewModel
import java.io.File

@Composable
fun ImageInputScreen(
    viewModel: AppViewModel,
    onAnalyze: () -> Unit,
    innerPadding: PaddingValues
) {
    val settings by viewModel.settings.collectAsState()
    val images by viewModel.capturedImages.collectAsState()
    val context = LocalContext.current

    var tempCameraUri by remember { mutableStateOf<Uri?>(null) }
    var showCameraPermissionDenied by remember { mutableStateOf(false) }

    // ── Camera permission launcher ──────────────────────────────────────────
    val requestCameraPermission = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) {
            val file = File(context.cacheDir, "camera_capture_${System.currentTimeMillis()}.jpg")
            val uri = FileProvider.getUriForFile(context, "${context.packageName}.provider", file)
            tempCameraUri = uri
        } else {
            showCameraPermissionDenied = true
        }
    }

    // ── Camera capture launcher ─────────────────────────────────────────────
    val takePicture = rememberLauncherForActivityResult(
        ActivityResultContracts.TakePicture()
    ) { success ->
        if (success) tempCameraUri?.let {
            viewModel.loadBitmapFromUri(it)?.let { bmp -> viewModel.addImages(listOf(bmp)) }
        }
    }

    // Watch tempCameraUri — when it's set after permission granted, launch camera
    LaunchedEffect(tempCameraUri) {
        tempCameraUri?.let { uri ->
            takePicture.launch(uri)
        }
    }

    fun launchCamera() {
        val alreadyGranted = ContextCompat.checkSelfPermission(
            context, Manifest.permission.CAMERA
        ) == PackageManager.PERMISSION_GRANTED
        if (alreadyGranted) {
            val file = File(context.cacheDir, "camera_capture_${System.currentTimeMillis()}.jpg")
            val uri = FileProvider.getUriForFile(context, "${context.packageName}.provider", file)
            tempCameraUri = uri
        } else {
            requestCameraPermission.launch(Manifest.permission.CAMERA)
        }
    }

    // ── Gallery photo picker ────────────────────────────────────────────────
    val pickFromGallery = rememberLauncherForActivityResult(
        ActivityResultContracts.PickMultipleVisualMedia(5)
    ) { uris ->
        val bitmaps = uris.mapNotNull { viewModel.loadBitmapFromUri(it) }
        viewModel.addImages(bitmaps)
    }

    // ── File system picker ──────────────────────────────────────────────────
    val pickFromFiles = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenMultipleDocuments()
    ) { uris ->
        val bitmaps = uris.mapNotNull { viewModel.loadBitmapFromUri(it) }
        viewModel.addImages(bitmaps)
    }

    if (showCameraPermissionDenied) {
        AlertDialog(
            onDismissRequest = { showCameraPermissionDenied = false },
            title = { Text("需要相机权限") },
            text = { Text("拍照功能需要相机权限。请在系统设置中授予权限。") },
            confirmButton = {
                TextButton(onClick = { showCameraPermissionDenied = false }) { Text("好") }
            }
        )
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(innerPadding)
            .padding(horizontal = 16.dp)
    ) {
        Spacer(Modifier.height(16.dp))

        Text(
            "选择学科", fontSize = 13.sp,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(bottom = 8.dp)
        )

        // Subject selector — horizontal scroll pills
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .horizontalScroll(rememberScrollState()),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Subject.entries.forEach { subject ->
                val selected = settings.selectedSubject == subject
                FilterChip(
                    selected = selected,
                    onClick = { viewModel.updateSettings { it.copy(selectedSubject = subject) } },
                    label = { Text(subject.rawValue, fontSize = 13.sp) }
                )
            }
        }

        Spacer(Modifier.height(20.dp))

        // Input buttons — 3 columns: camera / gallery / files
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            OutlinedButton(
                onClick = { launchCamera() },
                modifier = Modifier.weight(1f).height(52.dp),
                enabled = images.size < 5
            ) {
                Icon(Icons.Default.AddAPhoto, null, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(4.dp))
                Text("拍照", fontSize = 13.sp)
            }
            Button(
                onClick = {
                    pickFromGallery.launch(
                        PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)
                    )
                },
                modifier = Modifier.weight(1f).height(52.dp),
                enabled = images.size < 5
            ) {
                Icon(Icons.Default.AddPhotoAlternate, null, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(4.dp))
                Text("相册", fontSize = 13.sp)
            }
            OutlinedButton(
                onClick = { pickFromFiles.launch(arrayOf("image/*")) },
                modifier = Modifier.weight(1f).height(52.dp),
                enabled = images.size < 5
            ) {
                Icon(Icons.Default.FolderOpen, null, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(4.dp))
                Text("文件", fontSize = 13.sp)
            }
        }

        if (images.isNotEmpty()) {
            Text(
                "已选 ${images.size}/5 张",
                fontSize = 12.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(top = 6.dp)
            )
        }

        Spacer(Modifier.height(12.dp))

        // Image grid
        if (images.isNotEmpty()) {
            LazyVerticalGrid(
                columns = GridCells.Fixed(3),
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f),
                verticalArrangement = Arrangement.spacedBy(8.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                itemsIndexed(images) { index, bitmap ->
                    ImageThumbnail(bitmap = bitmap, onRemove = { viewModel.removeImage(index) })
                }
            }
        } else {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f),
                contentAlignment = Alignment.Center
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(
                        Icons.Default.AddPhotoAlternate, null,
                        modifier = Modifier.size(64.dp),
                        tint = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Text(
                        "拍照、从相册或文件中选取题目图片",
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(top = 12.dp)
                    )
                }
            }
        }

        Spacer(Modifier.height(16.dp))

        Button(
            onClick = { onAnalyze() },
            enabled = images.isNotEmpty(),
            modifier = Modifier
                .fillMaxWidth()
                .height(52.dp)
        ) {
            Text("分析题目", fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
        }

        Spacer(Modifier.height(16.dp))
    }
}

@Composable
private fun ImageThumbnail(bitmap: Bitmap, onRemove: () -> Unit) {
    Box(modifier = Modifier.aspectRatio(1f)) {
        Image(
            bitmap = bitmap.asImageBitmap(),
            contentDescription = null,
            contentScale = ContentScale.Crop,
            modifier = Modifier
                .fillMaxSize()
                .clip(RoundedCornerShape(8.dp))
        )
        IconButton(
            onClick = onRemove,
            modifier = Modifier
                .align(Alignment.TopEnd)
                .size(28.dp)
                .padding(4.dp)
                .background(MaterialTheme.colorScheme.surface.copy(alpha = 0.8f), CircleShape)
        ) {
            Icon(Icons.Default.Close, null, modifier = Modifier.size(16.dp))
        }
    }
}
