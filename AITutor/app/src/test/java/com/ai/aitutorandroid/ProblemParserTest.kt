package com.ai.aitutorandroid

import com.ai.aitutorandroid.services.ProblemParser
import org.junit.Assert.*
import org.junit.Test

class ProblemParserTest {

    @Test
    fun `parse valid JSON returns problems`() {
        val json = """[{"number":1,"fullLatexText":"求 x^2+1=0 的解","knownDataMarkdown":""}]"""
        val problems = ProblemParser.parse(json)
        assertEquals(1, problems.size)
        assertEquals(1, problems[0].number)
        assertTrue(problems[0].fullLatexText.contains("x^2"))
    }

    @Test
    fun `parse JSON with unescaped backslashes succeeds`() {
        val json = """[{"number":1,"fullLatexText":"\frac{1}{2}","knownDataMarkdown":""}]"""
        val problems = ProblemParser.parse(json)
        assertEquals(1, problems.size)
    }

    @Test
    fun `parse multiple problems`() {
        val json = """[{"number":1,"fullLatexText":"题目1","knownDataMarkdown":"条件1"},{"number":2,"fullLatexText":"题目2","knownDataMarkdown":""}]"""
        val problems = ProblemParser.parse(json)
        assertEquals(2, problems.size)
        assertEquals("条件1", problems[0].knownDataMarkdown)
    }

    @Test
    fun `parse invalid JSON falls back to single problem`() {
        val garbage = "这根本不是JSON，但是一道题目"
        val problems = ProblemParser.parse(garbage)
        assertEquals(1, problems.size)
        assertEquals(garbage.trim(), problems[0].fullLatexText)
    }

    @Test
    fun `parse JSON wrapped in markdown code block`() {
        val json = "```json\n[{\"number\":1,\"fullLatexText\":\"题目\",\"knownDataMarkdown\":\"\"}]\n```"
        val problems = ProblemParser.parse(json)
        assertEquals(1, problems.size)
    }
}
