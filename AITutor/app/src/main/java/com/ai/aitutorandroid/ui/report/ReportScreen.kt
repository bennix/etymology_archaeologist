package com.ai.aitutorandroid.ui.report

import android.content.Intent
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.ai.aitutorandroid.models.ExpertType
import com.ai.aitutorandroid.ui.components.KaTeXView
import com.ai.aitutorandroid.ui.solving.StreamingSolutionView
import com.ai.aitutorandroid.viewmodels.AppViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ReportScreen(viewModel: AppViewModel, onHome: () -> Unit) {
    val problems by viewModel.problems.collectAsState()
    val settings by viewModel.settings.collectAsState()
    val selectedProblems = problems.filter { it.isSelected }
    val context = LocalContext.current

    var selectedProblemIndex by remember { mutableIntStateOf(0) }
    var selectedTab by remember { mutableIntStateOf(0) }
    val currentProblem = selectedProblems.getOrNull(selectedProblemIndex)

    val tabs = listOf("⭐ 专家点评", "📐 解题详情", "💬 追问")

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("解题报告") },
                navigationIcon = {
                    IconButton(onClick = onHome) { Icon(Icons.Default.Home, null) }
                },
                actions = {
                    IconButton(onClick = {
                        val report = viewModel.fullReport()
                        val intent = Intent(Intent.ACTION_SEND).apply {
                            type = "text/plain"
                            putExtra(Intent.EXTRA_TEXT, report)
                        }
                        context.startActivity(Intent.createChooser(intent, "导出报告"))
                    }) { Icon(Icons.Default.Share, null) }
                }
            )
        }
    ) { padding ->
        Column(modifier = Modifier.fillMaxSize().padding(padding)) {

            if (selectedProblems.size > 1) {
                ScrollableTabRow(selectedTabIndex = selectedProblemIndex) {
                    selectedProblems.forEachIndexed { i, p ->
                        Tab(selected = selectedProblemIndex == i,
                            onClick = { selectedProblemIndex = i },
                            text = { Text("题目 ${p.number}") })
                    }
                }
            }

            TabRow(selectedTabIndex = selectedTab) {
                tabs.forEachIndexed { i, title ->
                    Tab(selected = selectedTab == i, onClick = { selectedTab = i },
                        text = { Text(title) })
                }
            }

            currentProblem?.let { problem ->
                when (selectedTab) {
                    0 -> {
                        val cSol = viewModel.solution(problem.id, ExpertType.C)
                        StreamingSolutionView(
                            solution = cSol,
                            modelName = settings.expertCDisplayName,
                            modifier = Modifier.fillMaxSize()
                        )
                    }
                    1 -> {
                        Column(modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
                            val aSol = viewModel.solution(problem.id, ExpertType.A)
                            val bSol = viewModel.solution(problem.id, ExpertType.B)
                            Text("解法一 · ${settings.expertADisplayName}",
                                style = MaterialTheme.typography.titleSmall,
                                modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp))
                            aSol?.content?.let { content ->
                                KaTeXView(content = content, modifier = Modifier.fillMaxWidth().heightIn(min = 100.dp))
                            }
                            HorizontalDivider(modifier = Modifier.padding(vertical = 8.dp))
                            Text("解法二 · ${settings.expertBDisplayName}",
                                style = MaterialTheme.typography.titleSmall,
                                modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp))
                            bSol?.content?.let { content ->
                                KaTeXView(content = content, modifier = Modifier.fillMaxWidth().heightIn(min = 100.dp))
                            }
                        }
                    }
                    2 -> {
                        ChatFollowUpScreen(viewModel = viewModel, modifier = Modifier.fillMaxSize())
                    }
                }
            }
        }
    }
}
