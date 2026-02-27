package com.ai.aitutorandroid.ui.solving

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.ai.aitutorandroid.models.ExpertSolution
import com.ai.aitutorandroid.ui.components.KaTeXView

@Composable
fun StreamingSolutionView(
    solution: ExpertSolution?,
    modelName: String,
    modifier: Modifier = Modifier
) {
    Box(modifier = modifier.fillMaxSize()) {
        when {
            solution == null || (!solution.isStreaming && !solution.isComplete && solution.errorMessage == null) -> {
                Column(
                    modifier = Modifier.align(Alignment.Center),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    CircularProgressIndicator(modifier = Modifier.size(32.dp), strokeWidth = 3.dp)
                    Spacer(Modifier.height(12.dp))
                    Text(modelName, fontSize = 14.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            solution.errorMessage != null -> {
                Column(
                    modifier = Modifier.align(Alignment.Center).padding(24.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text("解题失败", color = MaterialTheme.colorScheme.error, fontSize = 16.sp)
                    Spacer(Modifier.height(8.dp))
                    Text(solution.errorMessage, color = MaterialTheme.colorScheme.onSurfaceVariant, fontSize = 14.sp)
                }
            }
            solution.isStreaming -> {
                Column(modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp)) {
                    Text(solution.content, fontSize = 15.sp, lineHeight = 24.sp)
                    Text("▌", color = MaterialTheme.colorScheme.primary)
                }
            }
            solution.isComplete -> {
                KaTeXView(
                    content = solution.content,
                    modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState())
                )
            }
        }
    }
}
