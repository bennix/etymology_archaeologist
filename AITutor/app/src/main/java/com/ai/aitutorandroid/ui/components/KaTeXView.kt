package com.ai.aitutorandroid.ui.components

import android.annotation.SuppressLint
import android.webkit.JavascriptInterface
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.AndroidView

@SuppressLint("SetJavaScriptEnabled")
@Composable
fun KaTeXView(
    content: String,
    modifier: Modifier = Modifier,
    darkMode: Boolean = false
) {
    var webViewRef by remember { mutableStateOf<WebView?>(null) }
    var contentLoaded by remember { mutableStateOf(false) }
    var pendingContent by remember { mutableStateOf(content) }

    // When content changes after load, inject via JS
    LaunchedEffect(content, contentLoaded) {
        if (contentLoaded) {
            webViewRef?.injectContent(content)
        } else {
            pendingContent = content
        }
    }

    AndroidView(
        factory = { ctx ->
            WebView(ctx).apply {
                settings.javaScriptEnabled = true
                settings.allowFileAccess = true
                settings.domStorageEnabled = true
                setBackgroundColor(0x00000000) // transparent

                addJavascriptInterface(object {
                    @JavascriptInterface
                    fun setHeight(height: Int) {
                        // Height reporting available for future use
                    }
                }, "AndroidBridge")

                webViewClient = object : WebViewClient() {
                    override fun onPageFinished(view: WebView?, url: String?) {
                        contentLoaded = true
                        view?.injectContent(pendingContent)
                    }
                }

                loadUrl("file:///android_asset/katex/katex_template_android.html")
                webViewRef = this
            }
        },
        update = { /* updates handled via LaunchedEffect */ },
        modifier = modifier
    )
}

private fun WebView.injectContent(content: String) {
    val escaped = content
        .replace("\\", "\\\\")
        .replace("`", "\\`")
        .replace("$", "\\$")
    evaluateJavascript("window.updateContent(`$escaped`)", null)
}
