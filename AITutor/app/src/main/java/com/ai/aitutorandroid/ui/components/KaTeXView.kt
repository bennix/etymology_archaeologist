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
    // Always holds the latest content regardless of composition timing.
    // SideEffect runs after every successful recomposition, so this ref is
    // never stale — even when onPageFinished fires after a WebView renderer
    // restart (which happens after the screen turns off and the system reclaims
    // the renderer process).
    val latestContent = remember { mutableStateOf(content) }
    SideEffect { latestContent.value = content }

    var webViewRef by remember { mutableStateOf<WebView?>(null) }
    var pageReady  by remember { mutableStateOf(false) }

    // Re-inject whenever content changes and the page is already loaded
    LaunchedEffect(content) {
        if (pageReady) webViewRef?.injectContent(content)
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
                    fun setHeight(height: Int) { }
                }, "AndroidBridge")

                webViewClient = object : WebViewClient() {
                    override fun onPageFinished(view: WebView?, url: String?) {
                        pageReady = true
                        // Use latestContent.value (not a stale captured variable)
                        // so content is correct even if the page reloaded after
                        // the WebView renderer was killed during screen-off.
                        view?.injectContent(latestContent.value)
                    }
                }

                loadUrl("file:///android_asset/katex/katex_template_android.html")
                webViewRef = this
            }
        },
        update = { },
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
