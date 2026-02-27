package com.ai.aitutorandroid.navigation

import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.ai.aitutorandroid.ui.extraction.ExtractionLoadingScreen
import com.ai.aitutorandroid.ui.extraction.ProblemConfirmationScreen
import com.ai.aitutorandroid.ui.main.MainTabScreen
import com.ai.aitutorandroid.ui.onboarding.APIKeySetupScreen
import com.ai.aitutorandroid.ui.report.ReportScreen
import com.ai.aitutorandroid.ui.solving.SolvingContainerScreen
import com.ai.aitutorandroid.viewmodels.AppViewModel

object Route {
    const val API_KEY_SETUP = "api_key_setup"
    const val MAIN = "main"
    const val EXTRACTION_LOADING = "extraction_loading"
    const val PROBLEM_CONFIRMATION = "problem_confirmation"
    const val SOLVING_CONTAINER = "solving_container"
    const val REPORT = "report"
}

@Composable
fun AppNavigation() {
    val navController = rememberNavController()
    val viewModel: AppViewModel = hiltViewModel()
    val settings by viewModel.settings.collectAsState()

    val startDestination = if (settings.hasAnyApiKey) Route.MAIN else Route.API_KEY_SETUP

    NavHost(navController = navController, startDestination = startDestination) {
        composable(Route.API_KEY_SETUP) {
            APIKeySetupScreen(
                viewModel = viewModel,
                onComplete = { navController.navigate(Route.MAIN) { popUpTo(0) { inclusive = true } } }
            )
        }
        composable(Route.MAIN) {
            MainTabScreen(
                viewModel = viewModel,
                onAnalyze = { navController.navigate(Route.EXTRACTION_LOADING) }
            )
        }
        composable(Route.EXTRACTION_LOADING) {
            ExtractionLoadingScreen(
                viewModel = viewModel,
                onSuccess = { navController.navigate(Route.PROBLEM_CONFIRMATION) { popUpTo(Route.EXTRACTION_LOADING) { inclusive = true } } },
                onBack = { navController.popBackStack() }
            )
        }
        composable(Route.PROBLEM_CONFIRMATION) {
            ProblemConfirmationScreen(
                viewModel = viewModel,
                onStartSolving = { navController.navigate(Route.SOLVING_CONTAINER) },
                onBack = { navController.popBackStack() }
            )
        }
        composable(Route.SOLVING_CONTAINER) {
            SolvingContainerScreen(
                viewModel = viewModel,
                onReportReady = { navController.navigate(Route.REPORT) },
                onBack = {
                    viewModel.cancelSolving()
                    navController.navigate(Route.MAIN) { popUpTo(0) { inclusive = true } }
                }
            )
        }
        composable(Route.REPORT) {
            ReportScreen(
                viewModel = viewModel,
                onHome = {
                    viewModel.resetToInput()
                    navController.navigate(Route.MAIN) { popUpTo(0) { inclusive = true } }
                }
            )
        }
    }
}
