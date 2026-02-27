package com.ai.aitutorandroid.ui.main

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.*
import androidx.compose.runtime.*
import com.ai.aitutorandroid.ui.settings.SettingsScreen
import com.ai.aitutorandroid.viewmodels.AppViewModel

@Composable
fun MainTabScreen(viewModel: AppViewModel, onAnalyze: () -> Unit) {
    var selectedTab by remember { mutableIntStateOf(0) }

    Scaffold(
        bottomBar = {
            NavigationBar {
                NavigationBarItem(
                    selected = selectedTab == 0,
                    onClick = { selectedTab = 0 },
                    icon = { Icon(Icons.Default.Search, "分析") },
                    label = { Text("分析") }
                )
                NavigationBarItem(
                    selected = selectedTab == 1,
                    onClick = { selectedTab = 1 },
                    icon = { Icon(Icons.Default.Settings, "设置") },
                    label = { Text("设置") }
                )
            }
        }
    ) { padding ->
        when (selectedTab) {
            0 -> ImageInputScreen(viewModel = viewModel, onAnalyze = onAnalyze, innerPadding = padding)
            1 -> SettingsScreen(viewModel = viewModel, innerPadding = padding)
        }
    }
}
