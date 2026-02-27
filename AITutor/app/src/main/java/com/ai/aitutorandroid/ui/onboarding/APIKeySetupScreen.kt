package com.ai.aitutorandroid.ui.onboarding

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.ai.aitutorandroid.models.APIConfig
import com.ai.aitutorandroid.viewmodels.AppViewModel

@Composable
fun APIKeySetupScreen(viewModel: AppViewModel, onComplete: () -> Unit) {
    val settings by viewModel.settings.collectAsState()
    var tuziKey by remember { mutableStateOf(settings.tuziApiKey) }
    var zenmuxKey by remember { mutableStateOf(settings.zenmuxApiKey) }
    var testResult by remember { mutableStateOf<String?>(null) }
    val testConnectionResult by viewModel.testConnectionResult.collectAsState()

    LaunchedEffect(testConnectionResult) {
        testConnectionResult?.let {
            testResult = if (it) "✓ 连接成功" else "✗ 连接失败，请检查 API Key"
            viewModel.clearTestResult()
        }
    }

    Scaffold { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Spacer(Modifier.height(40.dp))
            Text("AI Tutor", fontSize = 32.sp, fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.primary)
            Text("配置 API Key 开始使用", fontSize = 16.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(top = 8.dp))

            Spacer(Modifier.height(40.dp))

            // Tu-zi Card (recommended)
            ProviderCard(
                title = "Tu-zi API Key",
                subtitle = "推荐 · 稳定高速",
                keyValue = tuziKey,
                onKeyChange = { tuziKey = it },
                onTest = {
                    viewModel.updateSettings { it.copy(tuziApiKey = tuziKey) }
                    viewModel.testConnection(APIConfig.tuzi(tuziKey))
                }
            )

            Spacer(Modifier.height(16.dp))

            // Zenmux Card
            ProviderCard(
                title = "Zenmux API Key",
                subtitle = "备用 · 支持图片提取",
                keyValue = zenmuxKey,
                onKeyChange = { zenmuxKey = it },
                onTest = {
                    viewModel.updateSettings { it.copy(zenmuxApiKey = zenmuxKey) }
                    viewModel.testConnection(APIConfig.zenmux(zenmuxKey))
                }
            )

            testResult?.let {
                Spacer(Modifier.height(12.dp))
                Text(it, color = if (it.startsWith("✓")) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.error)
            }

            Spacer(Modifier.height(32.dp))

            val hasAnyKey = tuziKey.isNotBlank() || zenmuxKey.isNotBlank()
            Button(
                onClick = {
                    viewModel.updateSettings { it.copy(tuziApiKey = tuziKey, zenmuxApiKey = zenmuxKey) }
                    onComplete()
                },
                enabled = hasAnyKey,
                modifier = Modifier.fillMaxWidth().height(52.dp)
            ) {
                Text("开始使用", fontSize = 16.sp)
            }
        }
    }
}

@Composable
private fun ProviderCard(
    title: String, subtitle: String, keyValue: String,
    onKeyChange: (String) -> Unit, onTest: () -> Unit
) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(title, fontWeight = FontWeight.SemiBold)
            Text(subtitle, fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Spacer(Modifier.height(12.dp))
            OutlinedTextField(
                value = keyValue,
                onValueChange = onKeyChange,
                placeholder = { Text("粘贴你的 API Key") },
                visualTransformation = PasswordVisualTransformation(),
                modifier = Modifier.fillMaxWidth(),
                singleLine = true
            )
            if (keyValue.isNotBlank()) {
                Spacer(Modifier.height(8.dp))
                TextButton(onClick = onTest) { Text("测试连接") }
            }
        }
    }
}
