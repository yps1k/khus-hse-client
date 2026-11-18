package ru.hse.khus

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    private var loggedIn by mutableStateOf(false)
    private var authBusy by mutableStateOf(false)
    private var authError by mutableStateOf<String?>(null)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Auth.init(this)
        loggedIn = Auth.isLoggedIn
        enableEdgeToEdge()
        handleIntent(intent)
        setContent {
            KhusTheme {
                AppBackground {
                    if (loggedIn) {
                        MainScreen(onLogout = { Auth.logout(); loggedIn = false })
                    } else {
                        LoginScreen(
                            busy = authBusy,
                            error = authError,
                            onLogin = { authError = null; Auth.launchLogin(this) },
                        )
                    }
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        val uri = intent?.data ?: return
        if (uri.scheme != "ru.hse.hseappx") return
        authBusy = true
        lifecycleScope.launch {
            try {
                if (Auth.handleRedirect(uri)) loggedIn = true
            } catch (e: Exception) {
                authError = e.message ?: "ошибка входа"
            } finally {
                authBusy = false
            }
        }
    }
}
