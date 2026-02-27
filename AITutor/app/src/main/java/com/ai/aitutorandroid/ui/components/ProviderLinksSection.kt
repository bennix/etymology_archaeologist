package com.ai.aitutorandroid.ui.components

import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Launch
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

private val PROVIDERS = listOf(
    Triple("兔子",   "推荐 · 国内稳定高速", "https://store.tu-zi.com?from=1304"),
    Triple("ZenMux", "支持图片提取",        "https://zenmux.ai/invite/GBQMC5")
)

/**
 * A ready-made block that lists the two recommended API providers with
 * one-tap "注册获取 Key" buttons.  Drop it anywhere — APIKeySetupScreen
 * or SettingsScreen — it brings its own UriHandler.
 */
@Composable
fun ProviderLinksSection(modifier: Modifier = Modifier) {
    val uriHandler = LocalUriHandler.current
    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(2.dp)) {
        PROVIDERS.forEach { (name, tagline, url) ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(name, fontWeight = FontWeight.Medium, fontSize = 14.sp)
                    Text(
                        tagline,
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                TextButton(onClick = { uriHandler.openUri(url) }) {
                    Text("注册获取 Key", fontSize = 12.sp)
                    Spacer(Modifier.width(2.dp))
                    Icon(
                        Icons.Filled.Launch, null,
                        modifier = Modifier.size(13.dp)
                    )
                }
            }
        }
    }
}
