package com.ai.aitutorandroid.ui.extraction

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.MergeType
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.ai.aitutorandroid.models.Problem
import com.ai.aitutorandroid.viewmodels.AppViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ProblemConfirmationScreen(
    viewModel: AppViewModel,
    onStartSolving: () -> Unit,
    onBack: () -> Unit
) {
    val problems by viewModel.problems.collectAsState()
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
        LazyColumn(
            contentPadding = PaddingValues(
                start = 16.dp, end = 16.dp,
                top = padding.calculateTopPadding() + 8.dp,
                bottom = padding.calculateBottomPadding()
            ),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            itemsIndexed(problems) { index, problem ->
                ProblemCard(
                    problem = problem,
                    showMergeButton = index < problems.size - 1,
                    onToggleSelect = { viewModel.toggleProblemSelection(problem.id) },
                    onMergeWithNext = { viewModel.mergeProblems(index, index + 1) }
                )
            }
        }
    }
}

@Composable
private fun ProblemCard(
    problem: Problem,
    showMergeButton: Boolean,
    onToggleSelect: () -> Unit,
    onMergeWithNext: () -> Unit
) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Checkbox(checked = problem.isSelected, onCheckedChange = { onToggleSelect() })
                Spacer(Modifier.width(8.dp))
                Text("题目 ${problem.number}", fontWeight = FontWeight.SemiBold, fontSize = 16.sp)
            }
            Spacer(Modifier.height(8.dp))
            Text(
                text = problem.fullLatexText.take(200) + if (problem.fullLatexText.length > 200) "…" else "",
                fontSize = 14.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                lineHeight = 20.sp
            )
            if (showMergeButton) {
                Spacer(Modifier.height(8.dp))
                TextButton(
                    onClick = onMergeWithNext,
                    modifier = Modifier.align(Alignment.End)
                ) {
                    Icon(Icons.AutoMirrored.Filled.MergeType, null, modifier = Modifier.size(16.dp))
                    Spacer(Modifier.width(4.dp))
                    Text("与下一题合并", fontSize = 13.sp)
                }
            }
        }
    }
}
