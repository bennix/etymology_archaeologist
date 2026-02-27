package com.ai.aitutorandroid.ui.extraction

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.ai.aitutorandroid.viewmodels.AppViewModel

@Composable
fun ExtractionLoadingScreen(
    viewModel: AppViewModel,
    onSuccess: () -> Unit,
    onBack: () -> Unit
) {
    val isExtracting by viewModel.isExtracting.collectAsState()
    val error by viewModel.extractionError.collectAsState()
    val images by viewModel.capturedImages.collectAsState()

    // Single navigation trigger: extractProblems calls onSuccess exactly once via
    // its callback. The previous LaunchedEffect(problems) was a duplicate that issued
    // a second navigate() racing with this one, sometimes popping the back stack
    // unexpectedly and sending the user back to the extraction/input screen.
    LaunchedEffect(Unit) {
        viewModel.extractProblems(onSuccess = onSuccess)
    }

    Scaffold { padding ->
        Box(modifier = Modifier.fillMaxSize().padding(padding), contentAlignment = Alignment.Center) {
            when {
                error != null -> {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.Center
                    ) {
                        Text("提取失败", fontSize = 18.sp, fontWeight = FontWeight.SemiBold,
                            color = MaterialTheme.colorScheme.error)
                        Spacer(Modifier.height(12.dp))
                        Text(error ?: "", color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.padding(horizontal = 24.dp))
                        Spacer(Modifier.height(24.dp))
                        Button(onClick = {
                            viewModel.clearExtractionError()
                            onBack()
                        }) { Text("返回") }
                    }
                }
                isExtracting -> {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.Center
                    ) {
                        CircularProgressIndicator(modifier = Modifier.size(56.dp), strokeWidth = 4.dp)
                        Spacer(Modifier.height(24.dp))
                        Text("正在识别题目…", fontSize = 18.sp, fontWeight = FontWeight.SemiBold)
                        Spacer(Modifier.height(8.dp))
                        Text("识别内容 · 提取题目结构 · 拆分题号",
                            fontSize = 14.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        if (images.size > 1) {
                            Spacer(Modifier.height(8.dp))
                            Text("共 ${images.size} 张图片", fontSize = 13.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                }
            }
        }
    }
}
