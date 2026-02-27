package com.ai.aitutorandroid.ui.solving

import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.ai.aitutorandroid.models.ExpertType
import com.ai.aitutorandroid.viewmodels.AppViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SolvingContainerScreen(
    viewModel: AppViewModel,
    onReportReady: () -> Unit,
    onBack: () -> Unit
) {
    val problems by viewModel.problems.collectAsState()
    val solutions by viewModel.solutions.collectAsState()
    val settings by viewModel.settings.collectAsState()
    val selectedProblems = problems.filter { it.isSelected }

    var selectedProblemIndex by remember { mutableIntStateOf(0) }
    var selectedExpert by remember { mutableIntStateOf(0) }

    val currentProblem = selectedProblems.getOrNull(selectedProblemIndex)

    val context = LocalContext.current
    DisposableEffect(Unit) {
        val window = (context as ComponentActivity).window
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        onDispose { window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON) }
    }

    LaunchedEffect(Unit) {
        viewModel.startSolving(onAllComplete = onReportReady)
    }

    LaunchedEffect(solutions) {
        if (selectedProblems.isNotEmpty() && selectedProblems.all { p ->
            val cSol = viewModel.solution(p.id, ExpertType.C)
            cSol?.isComplete == true || cSol?.errorMessage != null
        }) { onReportReady() }
    }

    val allABDone = selectedProblems.all { p ->
        val a = viewModel.solution(p.id, ExpertType.A)
        val b = viewModel.solution(p.id, ExpertType.B)
        (a?.isComplete == true || a?.errorMessage != null) &&
        (b?.isComplete == true || b?.errorMessage != null)
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(if (allABDone) "生成专家点评中…" else "解题中…", fontWeight = FontWeight.SemiBold)
                },
                actions = {
                    IconButton(onClick = onBack) { Icon(Icons.Default.Close, null) }
                }
            )
        }
    ) { padding ->
        Column(modifier = Modifier.fillMaxSize().padding(padding)) {

            if (selectedProblems.size > 1) {
                ScrollableTabRow(selectedTabIndex = selectedProblemIndex) {
                    selectedProblems.forEachIndexed { i, p ->
                        Tab(
                            selected = selectedProblemIndex == i,
                            onClick = { selectedProblemIndex = i },
                            text = { Text("题目 ${p.number}") }
                        )
                    }
                }
            }

            TabRow(selectedTabIndex = selectedExpert) {
                Tab(selected = selectedExpert == 0, onClick = { selectedExpert = 0 },
                    text = { Text("解法一 · ${settings.expertADisplayName}") })
                Tab(selected = selectedExpert == 1, onClick = { selectedExpert = 1 },
                    text = { Text("解法二 · ${settings.expertBDisplayName}") })
            }

            currentProblem?.let { problem ->
                val expertType = if (selectedExpert == 0) ExpertType.A else ExpertType.B
                val modelName = if (selectedExpert == 0) settings.expertADisplayName else settings.expertBDisplayName
                StreamingSolutionView(
                    solution = viewModel.solution(problem.id, expertType),
                    modelName = modelName,
                    modifier = Modifier.fillMaxSize()
                )
            }
        }
    }
}
