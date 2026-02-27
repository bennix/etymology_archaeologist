package com.ai.aitutorandroid.models

import java.util.UUID

enum class ChatRole { USER, ASSISTANT }

data class ChatMessage(
    val id: String = UUID.randomUUID().toString(),
    val role: ChatRole,
    val content: String,
    val isStreaming: Boolean = false
)
