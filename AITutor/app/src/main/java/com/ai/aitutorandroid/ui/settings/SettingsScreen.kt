package com.ai.aitutorandroid.ui.settings

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import com.ai.aitutorandroid.viewmodels.AppViewModel

@Composable
fun SettingsScreen(viewModel: AppViewModel, innerPadding: PaddingValues) {
    Box(Modifier.fillMaxSize().padding(innerPadding), contentAlignment = Alignment.Center) {
        Text("Settings — coming in Task 18")
    }
}
