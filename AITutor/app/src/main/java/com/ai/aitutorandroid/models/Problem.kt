package com.ai.aitutorandroid.models

import java.util.UUID

data class Problem(
    val id: String = UUID.randomUUID().toString(),
    val number: Int,
    val fullLatexText: String,
    val knownDataMarkdown: String,
    val isSelected: Boolean = true
)
