package com.ai.aitutorandroid.models

import java.util.UUID

enum class ExpertType { A, B, C }

data class ExpertSolution(
    val id: String = UUID.randomUUID().toString(),
    val expert: ExpertType,
    val content: String = "",
    val isStreaming: Boolean = false,
    val isComplete: Boolean = false,
    val errorMessage: String? = null
)
