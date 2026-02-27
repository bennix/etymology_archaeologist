package com.ai.aitutorandroid.ui.settings

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.ai.aitutorandroid.models.*
import com.ai.aitutorandroid.viewmodels.AppViewModel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(viewModel: AppViewModel, innerPadding: PaddingValues) {
    val settings by viewModel.settings.collectAsState()
    val testResult by viewModel.testConnectionResult.collectAsState()
    val isTesting by viewModel.isTestingConnection.collectAsState()

    var tuziKey by remember(settings.tuziApiKey) { mutableStateOf(settings.tuziApiKey) }
    var zenmuxKey by remember(settings.zenmuxApiKey) { mutableStateOf(settings.zenmuxApiKey) }

    LaunchedEffect(tuziKey) { viewModel.updateSettings { it.copy(tuziApiKey = tuziKey) } }
    LaunchedEffect(zenmuxKey) { viewModel.updateSettings { it.copy(zenmuxApiKey = zenmuxKey) } }

    val snackbarHostState = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()

    // Show snackbar when test result arrives, then auto-clear after 3 s
    LaunchedEffect(testResult) {
        val result = testResult ?: return@LaunchedEffect
        val msg = if (result) "✓ 连接成功" else "✗ 连接失败，请检查 API Key"
        scope.launch {
            snackbarHostState.showSnackbar(
                message = msg,
                duration = SnackbarDuration.Short
            )
        }
        delay(3_000)
        viewModel.clearTestResult()
    }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbarHostState) }
    ) { scaffoldPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(scaffoldPadding)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Text(
                "设置", fontSize = 28.sp, fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(bottom = 8.dp)
            )

            SettingsSection(title = "API Keys") {
                ApiKeyField(
                    label = "Tu-zi API Key",
                    value = tuziKey,
                    onChange = { tuziKey = it },
                    isTesting = isTesting,
                    onTest = { viewModel.testConnection(APIConfig.tuzi(tuziKey)) }
                )
                Spacer(Modifier.height(8.dp))
                ApiKeyField(
                    label = "Zenmux API Key",
                    value = zenmuxKey,
                    onChange = { zenmuxKey = it },
                    isTesting = isTesting,
                    onTest = { viewModel.testConnection(APIConfig.zenmux(zenmuxKey)) }
                )
            }

            SettingsSection(title = "API 提供商") {
                APIProvider.entries.forEach { provider ->
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        RadioButton(
                            selected = settings.preferredProvider == provider,
                            onClick = { viewModel.updateSettings { it.copy(preferredProvider = provider) } }
                        )
                        Text(provider.rawValue)
                    }
                }
            }

            SettingsSection(title = "输出语言") {
                DropdownSelector(
                    options = OutputLanguage.entries,
                    selected = settings.outputLanguage,
                    label = { it.rawValue },
                    onSelect = { lang -> viewModel.updateSettings { s -> s.copy(outputLanguage = lang) } }
                )
            }

            SettingsSection(title = "Zenmux 模型") {
                ModelRow("解法一", ZenmuxModel.entries, settings.zenmuxExpertAModel) { model ->
                    viewModel.updateSettings { s -> s.copy(zenmuxExpertAModel = model) }
                }
                ModelRow("解法二", ZenmuxModel.entries, settings.zenmuxExpertBModel) { model ->
                    viewModel.updateSettings { s -> s.copy(zenmuxExpertBModel = model) }
                }
                ModelRow("专家点评", ZenmuxModel.entries, settings.zenmuxExpertCModel) { model ->
                    viewModel.updateSettings { s -> s.copy(zenmuxExpertCModel = model) }
                }
            }

            SettingsSection(title = "Tu-zi 模型") {
                ModelRow("解法一", TuziModel.entries, settings.tuziExpertAModel) { model ->
                    viewModel.updateSettings { s -> s.copy(tuziExpertAModel = model) }
                }
                ModelRow("解法二", TuziModel.entries, settings.tuziExpertBModel) { model ->
                    viewModel.updateSettings { s -> s.copy(tuziExpertBModel = model) }
                }
                ModelRow("专家点评", TuziModel.entries, settings.tuziExpertCModel) { model ->
                    viewModel.updateSettings { s -> s.copy(tuziExpertCModel = model) }
                }
            }
        }
    }
}

@Composable
private fun SettingsSection(title: String, content: @Composable ColumnScope.() -> Unit) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                title, fontWeight = FontWeight.SemiBold, fontSize = 13.sp,
                color = MaterialTheme.colorScheme.primary,
                modifier = Modifier.padding(bottom = 12.dp)
            )
            content()
        }
    }
}

@Composable
private fun ApiKeyField(
    label: String,
    value: String,
    onChange: (String) -> Unit,
    isTesting: Boolean,
    onTest: () -> Unit
) {
    Column {
        Text(label, fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Spacer(Modifier.height(4.dp))
        OutlinedTextField(
            value = value,
            onValueChange = onChange,
            visualTransformation = PasswordVisualTransformation(),
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
            trailingIcon = {
                if (value.isNotBlank()) {
                    if (isTesting) {
                        CircularProgressIndicator(modifier = Modifier.size(20.dp), strokeWidth = 2.dp)
                    } else {
                        TextButton(onClick = onTest) { Text("验证", fontSize = 12.sp) }
                    }
                }
            }
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun <T> DropdownSelector(
    options: List<T>, selected: T, label: (T) -> String, onSelect: (T) -> Unit
) {
    var expanded by remember { mutableStateOf(false) }
    ExposedDropdownMenuBox(expanded = expanded, onExpandedChange = { expanded = it }) {
        OutlinedTextField(
            value = label(selected),
            onValueChange = {},
            readOnly = true,
            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded) },
            modifier = Modifier
                .menuAnchor(MenuAnchorType.PrimaryNotEditable)
                .fillMaxWidth()
        )
        ExposedDropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            options.forEach { option ->
                DropdownMenuItem(
                    text = { Text(label(option)) },
                    onClick = { onSelect(option); expanded = false }
                )
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun <T> ModelRow(label: String, options: List<T>, selected: T, onSelect: (T) -> Unit) {
    val displayName = when (selected) {
        is ZenmuxModel -> selected.displayName
        is TuziModel -> selected.displayName
        else -> selected.toString()
    }
    Row(
        Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(label, modifier = Modifier.width(72.dp), fontSize = 13.sp)
        Spacer(Modifier.width(8.dp))
        var expanded by remember { mutableStateOf(false) }
        ExposedDropdownMenuBox(
            expanded = expanded,
            onExpandedChange = { expanded = it },
            modifier = Modifier.weight(1f)
        ) {
            OutlinedTextField(
                value = displayName, onValueChange = {}, readOnly = true,
                trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded) },
                modifier = Modifier
                    .menuAnchor(MenuAnchorType.PrimaryNotEditable)
                    .fillMaxWidth(),
                textStyle = TextStyle(fontSize = 13.sp)
            )
            ExposedDropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                options.forEach { opt ->
                    val name = when (opt) {
                        is ZenmuxModel -> opt.displayName
                        is TuziModel -> opt.displayName
                        else -> opt.toString()
                    }
                    DropdownMenuItem(
                        text = { Text(name) },
                        onClick = { onSelect(opt); expanded = false }
                    )
                }
            }
        }
    }
}
