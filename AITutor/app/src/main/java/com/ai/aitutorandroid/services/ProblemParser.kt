package com.ai.aitutorandroid.services

import com.ai.aitutorandroid.models.Problem
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

object ProblemParser {

    private val json = Json { ignoreUnknownKeys = true }

    fun parse(rawText: String): List<Problem> {
        val stripped = rawText.trim()
            .removePrefix("```json").removePrefix("```")
            .removeSuffix("```")
            .trim()

        return tryParseJsonArray(stripped)
            ?: listOf(Problem(number = 1, fullLatexText = rawText.trim(), knownDataMarkdown = ""))
    }

    private fun tryParseJsonArray(text: String): List<Problem>? {
        val start = text.indexOf('[')
        val end = text.lastIndexOf(']')
        if (start < 0 || end < 0 || end <= start) return null

        val jsonStr = text.substring(start, end + 1)
        val fixedJson = fixBackslashes(jsonStr)

        return try {
            val arr = json.parseToJsonElement(fixedJson) as? JsonArray ?: return null
            arr.mapIndexed { i, element ->
                val obj = element.jsonObject
                Problem(
                    number = obj["number"]?.jsonPrimitive?.int ?: (i + 1),
                    fullLatexText = obj["fullLatexText"]?.jsonPrimitive?.content ?: "",
                    knownDataMarkdown = obj["knownDataMarkdown"]?.jsonPrimitive?.content ?: ""
                )
            }
        } catch (e: Exception) {
            null
        }
    }

    private fun fixBackslashes(json: String): String {
        val sb = StringBuilder()
        var i = 0
        while (i < json.length) {
            val ch = json[i]
            if (ch == '\\' && i + 1 < json.length) {
                val next = json[i + 1]
                if (next in setOf('\\', '"', '/', 'n', 't', 'r', 'b', 'f', 'u')) {
                    sb.append(ch).append(next)
                    i += 2
                } else {
                    sb.append("\\\\")
                    i += 1
                }
            } else {
                sb.append(ch)
                i++
            }
        }
        return sb.toString()
    }
}
