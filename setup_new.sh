#!/bin/bash
set -e
echo "[ELAINA] setup v1.3..."

cat > "README.md" <<'__EOF__'
# ELAINA Optimasi

Turbo tap (macro klik cepat) + pembersih RAM + pelicin layar via **Shizuku**.

## Build APK
Actions → Build APK → Run workflow → download artifact.

__EOF__

mkdir -p "app"
cat > "app/build.gradle.kts" <<'__EOF__'
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}
android {
    namespace = "com.elaina.optimasi"
    compileSdk = 34
    defaultConfig {
        applicationId = "com.elaina.optimasi"
        minSdk = 29
        targetSdk = 34
        versionCode = 4
        versionName = "1.3-home"
    }
    buildTypes { release { isMinifyEnabled = false } }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
}
dependencies {
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("dev.rikka.shizuku:api:4.1.0")
    implementation("dev.rikka.shizuku:provider:4.1.0")
}

__EOF__

mkdir -p "app/src/main"
cat > "app/src/main/AndroidManifest.xml" <<'__EOF__'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />
    <uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />
    <queries>
        <package android:name="moe.shizuku.privileged.api" />
    </queries>
    <application
        android:label="ELAINA Optimasi"
        android:icon="@drawable/ic_launcher"
        android:allowBackup="false"
        android:largeHeap="true"
        android:theme="@android:style/Theme.DeviceDefault.NoActionBar">
        <activity android:name=".MainActivity" android:exported="true" android:screenOrientation="portrait">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
        <service
            android:name=".TapService"
            android:exported="false"
            android:foregroundServiceType="specialUse">
            <property
                android:name="android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE"
                android:value="game turbo tap overlay" />
        </service>
        <service
            android:name=".CrossService"
            android:exported="false"
            android:foregroundServiceType="specialUse">
            <property
                android:name="android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE"
                android:value="game crosshair overlay" />
        </service>
        <provider
            android:name="rikka.shizuku.ShizukuProvider"
            android:authorities="${applicationId}.shizuku"
            android:multiprocess="false"
            android:enabled="true"
            android:exported="true"
            android:permission="android.permission.INTERACT_ACROSS_USERS_FULL" />
    </application>
</manifest>

__EOF__

mkdir -p "app/src/main/java/com/elaina/optimasi"
cat > "app/src/main/java/com/elaina/optimasi/CrossService.kt" <<'__EOF__'
package com.elaina.optimasi

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.View
import android.view.WindowManager

class CrossService : Service() {
    companion object {
        @JvmField var running = false
    }
    private var wm: WindowManager? = null
    private var view: View? = null

    override fun onBind(i: Intent?): IBinder? = null

    override fun onStartCommand(i: Intent?, f: Int, id: Int): Int {
        if (view != null) return START_STICKY
        running = true
        startFg()
        wm = getSystemService(WINDOW_SERVICE) as WindowManager
        val cross = object : View(this) {
            private val p = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = 0xFFFF3D00.toInt() // orange-red, not plain green
                strokeWidth = 3.5f
                style = Paint.Style.STROKE
            }
            private val dot = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = 0xFFFFFFFF.toInt()
                style = Paint.Style.FILL
            }
            private val ring = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = 0xAAFF1744.toInt()
                style = Paint.Style.STROKE
                strokeWidth = 1.5f
            }
            override fun onDraw(c: Canvas) {
                val cx = width / 2f
                val cy = height / 2f
                val len = 20f
                val gap = 5f
                c.drawCircle(cx, cy, 14f, ring)
                c.drawLine(cx - len, cy, cx - gap, cy, p)
                c.drawLine(cx + gap, cy, cx + len, cy, p)
                c.drawLine(cx, cy - len, cx, cy - gap, p)
                c.drawLine(cx, cy + gap, cx, cy + len, p)
                c.drawCircle(cx, cy, 2.8f, dot)
            }
        }
        val lp = WindowManager.LayoutParams(
            140, 140,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.CENTER
            if (Build.VERSION.SDK_INT >= 28) layoutInDisplayCutoutMode =
                WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
        view = cross
        try { wm?.addView(cross, lp) } catch (_: Exception) { running = false; stopSelf() }
        return START_STICKY
    }

    private fun startFg() {
        val ch = "elaina_cross"
        if (Build.VERSION.SDK_INT >= 26) {
            getSystemService(NotificationManager::class.java).createNotificationChannel(
                NotificationChannel(ch, "ELAINA Crosshair", NotificationManager.IMPORTANCE_LOW)
            )
        }
        val pi = PendingIntent.getActivity(
            this, 1, Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val n = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, ch)
        else @Suppress("DEPRECATION") Notification.Builder(this)
        val notif = n.setContentTitle("Crosshair aktif")
            .setContentText("Overlay di tengah layar")
            .setSmallIcon(android.R.drawable.ic_menu_view)
            .setContentIntent(pi)
            .setOngoing(true)
            .build()
        startForeground(1002, notif)
    }

    override fun onDestroy() {
        running = false
        view?.let { try { wm?.removeView(it) } catch (_: Exception) {} }
        view = null
        super.onDestroy()
    }
}

__EOF__

mkdir -p "app/src/main/java/com/elaina/optimasi"
cat > "app/src/main/java/com/elaina/optimasi/MainActivity.kt" <<'__EOF__'
package com.elaina.optimasi

import android.app.Activity
import android.app.ActivityManager
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.BatteryManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.view.Gravity
import android.widget.*

class MainActivity : Activity() {
    private val h = Handler(Looper.getMainLooper())
    private var cps = 14
    private var tab = 0
    private var content: FrameLayout? = null
    private var nav: LinearLayout? = null
    private var monitorRun: Runnable? = null

    override fun onCreate(b: Bundle?) {
        super.onCreate(b)
        window.statusBarColor = BG
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(BG)
        }
        content = FrameLayout(this)
        root.addView(content, LinearLayout.LayoutParams(-1, 0, 1f))
        nav = LinearLayout(this).apply { setBackgroundColor(PANEL) }
        listOf("HOME", "TURBO", "AIM", "INFO").forEachIndexed { i, name ->
            val t = TextView(this).apply {
                text = name; textSize = 11f; gravity = Gravity.CENTER
                setPadding(0, dp(14), 0, dp(14))
                setTextColor(MUTE)
                setOnClickListener { showTab(i) }
            }
            nav!!.addView(t, LinearLayout.LayoutParams(0, -2, 1f))
        }
        root.addView(nav, LinearLayout.LayoutParams(-1, -2))
        setContentView(root)
        showTab(0)
    }

    override fun onResume() {
        super.onResume()
        if (tab == 0 || tab == 1 || tab == 3) showTab(tab)
    }

    override fun onPause() {
        super.onPause()
        monitorRun?.let { h.removeCallbacks(it) }
        monitorRun = null
    }

    private fun showTab(i: Int) {
        tab = i
        monitorRun?.let { h.removeCallbacks(it) }
        monitorRun = null
        for (k in 0 until (nav?.childCount ?: 0)) {
            (nav!!.getChildAt(k) as TextView).setTextColor(if (k == i) RED else MUTE)
        }
        val sv = ScrollView(this)
        val col = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(16), dp(18), dp(16), dp(28))
        }
        when (i) {
            0 -> buildHome(col)
            1 -> buildTurbo(col)
            2 -> buildCross(col)
            else -> buildMonitor(col)
        }
        sv.addView(col)
        content?.removeAllViews()
        content?.addView(sv)
    }

    // ================= HOME =================
    private fun buildHome(col: LinearLayout) {
        col.addView(title("ELAINA"))
        col.addView(sub("Optimasi  •  Anti-lag  •  Turbo"))

        val st = card()
        val ok = ShizukuHelper.granted()
        st.addView(label(ShizukuHelper.status(), 16, if (ok) GREEN else CYAN, true))
        st.addView(label(
            if (ok) "Siap dipakai. Buka tab TURBO untuk boost."
            else "Aktifkan Shizuku dulu (bisa lewat Debug Nirkabel).",
            12, MUTE, false
        ))
        col.addView(st, gap(12))

        col.addView(section("AKTIFKAN IZIN"))
        if (!ShizukuHelper.available()) {
            col.addView(btn("1. BUKA APLIKASI SHIZUKU") {
                try {
                    startActivity(packageManager.getLaunchIntentForPackage("moe.shizuku.privileged.api"))
                } catch (_: Exception) {
                    toast("Install Shizuku dari Play Store / GitHub")
                }
            })
        } else if (!ok) {
            col.addView(btn("2. BERI IZIN SHIZUKU DI APP INI") {
                ShizukuHelper.request { r -> h.post { toast(if (r) "Izin OK" else "Ditolak"); showTab(0) } }
            })
        } else {
            col.addView(label("Shizuku sudah OK ✓", 13, GREEN, true), gap(8))
        }

        col.addView(section("CARA DEBUG NIRKABEL (Android 11+)"))
        val guide = card()
        guide.addView(label(
            "Kalau Shizuku belum jalan, aktifkan lewat Debug Nirkabel:\n\n" +
            "1. Settings → About phone → ketuk Build number 7x\n" +
            "2. Settings → Developer options\n" +
            "3. Nyalakan USB debugging + Wireless debugging\n" +
            "4. Buka app Shizuku → Pairing → masukkan kode\n" +
            "5. Kembali ke ELAINA → beri izin\n\n" +
            "Tanpa root. Cocok untuk yang tidak support cara lain.",
            12, TEXT, false
        ))
        col.addView(guide, gap(10))
        col.addView(btn("BUKA DEVELOPER OPTIONS", false) {
            try {
                startActivity(Intent(Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS))
            } catch (_: Exception) {
                try { startActivity(Intent(Settings.ACTION_SETTINGS)) } catch (_: Exception) {}
            }
        })
        col.addView(btn("BUKA SHIZUKU", false) {
            try {
                startActivity(packageManager.getLaunchIntentForPackage("moe.shizuku.privileged.api"))
            } catch (_: Exception) { toast("Install Shizuku dulu") }
        })

        col.addView(section("IZIN LAIN"))
        col.addView(btn("IZIN OVERLAY (wajib)", false) { ensureOverlay() })
        col.addView(btn("ABAIKAN OPTIMASI BATERAI", false) { askBatteryOpt() })

        col.addView(section("PINTASAN"))
        col.addView(btn("🔥 BOOST + RAM + GRAFIS LICIN") {
            if (!ok) { toast("Shizuku belum siap — ikuti panduan di atas"); return@btn }
            toast("Menjalankan boost...")
            Thread {
                val n = ShizukuHelper.cleanRamHard(this)
                ShizukuHelper.graphicsUltraSmooth(true)
                h.post {
                    toast(if (n < 0) "Gagal" else "Selesai • $n app stop • grafis smooth")
                }
            }.start()
        })
        col.addView(btn("MODE DINGIN (suhu lebih rendah)", false) {
            if (!ok) { toast("Shizuku belum siap"); return@btn }
            Thread {
                ShizukuHelper.coolMode(true)
                val n = ShizukuHelper.cleanRamHard(this)
                h.post { toast("Mode dingin ON • background dibersihkan ($n)") }
            }.start()
        })
    }

    // ================= TURBO =================
    private fun buildTurbo(col: LinearLayout) {
        col.addView(title("TURBO"))
        col.addView(sub("Grafis  •  RAM  •  Suhu  •  Macro"))
        val ok = ShizukuHelper.granted()

        col.addView(section("GRAFIS SUPER SMOOTH"))
        col.addView(label("Animasi 0 + force GPU + coba refresh tinggi (tergantung HP).", 12, MUTE, false))
        col.addView(btn("NYALAKAN GRAFIS ULTRA SMOOTH") {
            if (!ok) { toast("Shizuku belum siap"); return@btn }
            ShizukuHelper.graphicsUltraSmooth(true)
            toast("Grafis ultra smooth ON")
        })
        col.addView(btn("MATIKAN / NORMAL", false) {
            ShizukuHelper.graphicsUltraSmooth(false)
            toast("Grafis normal")
        })

        col.addView(section("RAM ANTI NGELEK"))
        col.addView(btn("BERSIHKAN RAM KERAS") {
            if (!ok) { toast("Shizuku belum siap"); return@btn }
            toast("Force-stop app latar...")
            Thread {
                val n = ShizukuHelper.cleanRamHard(this)
                h.post { toast(if (n < 0) "Gagal" else "$n app dihentikan") }
            }.start()
        })

        col.addView(section("SUHU LEBIH RENDAH"))
        col.addView(label("Tidak bisa mendinginkan chip secara langsung. Mode ini mengurangi beban biar suhu naik lebih pelan.", 12, MUTE, false))
        col.addView(btn("MODE DINGIN ON") {
            if (!ok) { toast("Shizuku belum siap"); return@btn }
            Thread {
                ShizukuHelper.coolMode(true)
                ShizukuHelper.cleanRamHard(this)
                h.post { toast("Mode dingin aktif") }
            }.start()
        })
        col.addView(btn("MODE DINGIN OFF", false) {
            ShizukuHelper.coolMode(false)
            toast("Mode dingin off")
        })

        col.addView(section("BOOST GABUNGAN"))
        col.addView(btn("🔥 BOOST MAX (RAM+GRAFIS)") {
            if (!ok) { toast("Shizuku belum siap"); return@btn }
            Thread {
                val n = ShizukuHelper.cleanRamHard(this)
                ShizukuHelper.graphicsUltraSmooth(true)
                h.post { toast("Boost max • $n app stop") }
            }.start()
        })

        col.addView(section("MACRO KLIK CEPAT"))
        col.addView(label("Kecepatan: $cps CPS", 13, TEXT, true).also { it.id = 9001 })
        col.addView(SeekBar(this).apply {
            max = 25; progress = (cps - 5).coerceIn(0, 25)
            progressTintList = android.content.res.ColorStateList.valueOf(RED)
            thumbTintList = android.content.res.ColorStateList.valueOf(RED)
            setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
                override fun onProgressChanged(s: SeekBar?, p: Int, u: Boolean) {
                    cps = p + 5
                    findViewById<TextView>(9001)?.text = "Kecepatan: $cps CPS"
                }
                override fun onStartTrackingTouch(s: SeekBar?) {}
                override fun onStopTrackingTouch(s: SeekBar?) {}
            })
        }, gap(8))
        col.addView(btn("TAMPILKAN TOMBOL TAP") {
            if (!ensureOverlay()) return@btn
            askBatteryOpt()
            startService(Intent(this, TapService::class.java).putExtra("cps", cps))
            toast("TAP aktif (foreground)")
        })
        col.addView(btn("MATIKAN TOMBOL TAP", false) {
            stopService(Intent(this, TapService::class.java)); toast("Mati")
        })
    }

    private fun buildCross(col: LinearLayout) {
        col.addView(title("CROSSHAIR"))
        col.addView(sub("Aim di tengah layar"))
        val st = card()
        st.addView(label(if (CrossService.running) "AKTIF" else "MATI", 15, if (CrossService.running) GREEN else MUTE, true))
        st.addView(label("Foreground service — lebih stabil saat main.", 12, MUTE, false))
        col.addView(st, gap(12))
        col.addView(btn(if (CrossService.running) "MATIKAN" else "NYALAKAN") {
            if (!ensureOverlay()) return@btn
            if (CrossService.running) stopService(Intent(this, CrossService::class.java))
            else startService(Intent(this, CrossService::class.java))
            h.postDelayed({ showTab(2) }, 350)
        })
    }

    private fun buildMonitor(col: LinearLayout) {
        col.addView(title("MONITOR"))
        col.addView(sub("Status perangkat"))
        val ramT = label("RAM: ...", 14, TEXT, true)
        val batT = label("Baterai: ...", 14, TEXT, true)
        val cpuT = label("CPU: ...", 14, TEXT, true)
        val devT = label("HP: ${Build.MANUFACTURER} ${Build.MODEL}\nAndroid ${Build.VERSION.RELEASE}", 12, MUTE, false)
        listOf(ramT, batT, cpuT).forEach {
            val c = card(); c.addView(it); col.addView(c, gap(10))
        }
        col.addView(devT, gap(12))
        val r = object : Runnable {
            override fun run() {
                val am = getSystemService(ACTIVITY_SERVICE) as ActivityManager
                val mi = ActivityManager.MemoryInfo()
                am.getMemoryInfo(mi)
                val used = (mi.totalMem - mi.availMem) / 1048576
                val total = mi.totalMem / 1048576
                val pct = if (total > 0) (used * 100 / total).toInt() else 0
                ramT.text = "RAM: $used / $total MB ($pct%)"
                val i = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
                val lvl = i?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
                val sc = i?.getIntExtra(BatteryManager.EXTRA_SCALE, 100) ?: 100
                val temp = (i?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, 0) ?: 0) / 10f
                val bp = if (lvl >= 0 && sc > 0) lvl * 100 / sc else 0
                batT.text = "Baterai: $bp%  •  suhu ${"%.1f".format(temp)}°C"
                val cores = Runtime.getRuntime().availableProcessors()
                cpuT.text = "CPU: $cores core  •  " + if (ShizukuHelper.granted()) "Shizuku OK" else "Shizuku off"
                h.postDelayed(this, 2000)
            }
        }
        monitorRun = r
        r.run()
    }

    private fun ensureOverlay(): Boolean {
        if (Settings.canDrawOverlays(this)) return true
        startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName")))
        toast("Izinkan overlay")
        return false
    }

    private fun askBatteryOpt() {
        if (Build.VERSION.SDK_INT < 23) return
        try {
            val pm = getSystemService(POWER_SERVICE) as PowerManager
            if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                startActivity(Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = Uri.parse("package:$packageName")
                })
            } else toast("Sudah diabaikan")
        } catch (_: Exception) {
            try { startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)) } catch (_: Exception) {}
        }
    }

    private fun title(t: String) = label(t, 26, Color.WHITE, true).also {
        (it.layoutParams as? LinearLayout.LayoutParams)?.bottomMargin = dp(4)
    }
    private fun sub(t: String) = label(t, 13, MUTE, false).also {
        (it.layoutParams as? LinearLayout.LayoutParams)?.bottomMargin = dp(14)
    }
    private fun section(t: String) = label(t, 13, RED, true).also {
        (it.layoutParams as? LinearLayout.LayoutParams)?.apply { topMargin = dp(16); bottomMargin = dp(8) }
    }
    private fun label(t: String, size: Int, col: Int, bold: Boolean) = TextView(this).apply {
        text = t; textSize = size.toFloat(); setTextColor(col)
        if (bold) setTypeface(typeface, android.graphics.Typeface.BOLD)
        layoutParams = LinearLayout.LayoutParams(-1, -2).also { it.bottomMargin = dp(4) }
    }
    private fun card() = LinearLayout(this).apply {
        orientation = LinearLayout.VERTICAL
        setPadding(dp(14), dp(12), dp(14), dp(12))
        background = GradientDrawable().apply { setColor(PANEL); cornerRadius = dp(12).toFloat() }
    }
    private fun btn(t: String, primary: Boolean = true, click: () -> Unit) = TextView(this).apply {
        text = t; textSize = 14f; gravity = Gravity.CENTER; setTextColor(Color.WHITE)
        setPadding(dp(14), dp(13), dp(14), dp(13))
        background = GradientDrawable().apply {
            setColor(if (primary) RED else PANEL2); cornerRadius = dp(10).toFloat()
        }
        setOnClickListener { click() }
        layoutParams = LinearLayout.LayoutParams(-1, -2).also { it.bottomMargin = dp(8) }
    }
    private fun gap(b: Int) = LinearLayout.LayoutParams(-1, -2).also { it.bottomMargin = dp(b) }
    private fun dp(v: Int) = (v * resources.displayMetrics.density).toInt()
    private fun toast(t: String) = Toast.makeText(this, t, Toast.LENGTH_SHORT).show()

    companion object {
        val BG = 0xFF0A0A0F.toInt()
        val PANEL = 0xFF16161F.toInt()
        val PANEL2 = 0xFF2A2A35.toInt()
        val RED = 0xFFFF1744.toInt()
        val GREEN = 0xFF00E676.toInt()
        val CYAN = 0xFF00E5FF.toInt()
        val MUTE = 0xFF888899.toInt()
        val TEXT = 0xFFE0E0E8.toInt()
    }
}

__EOF__

mkdir -p "app/src/main/java/com/elaina/optimasi"
cat > "app/src/main/java/com/elaina/optimasi/ShizukuHelper.kt" <<'__EOF__'
package com.elaina.optimasi

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import rikka.shizuku.Shizuku
import java.io.BufferedReader
import java.io.InputStreamReader

object ShizukuHelper {
    fun available(): Boolean = try { Shizuku.pingBinder() } catch (_: Exception) { false }
    fun granted(): Boolean = try {
        Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED
    } catch (_: Exception) { false }

    fun request(cb: (Boolean) -> Unit) {
        try {
            if (Shizuku.isPreV11()) { cb(false); return }
            val listener = object : Shizuku.OnRequestPermissionResultListener {
                override fun onRequestPermissionResult(requestCode: Int, grantResult: Int) {
                    Shizuku.removeRequestPermissionResultListener(this)
                    cb(grantResult == PackageManager.PERMISSION_GRANTED)
                }
            }
            Shizuku.addRequestPermissionResultListener(listener)
            Shizuku.requestPermission(1001)
        } catch (_: Exception) { cb(false) }
    }

    fun shell(cmd: String): String {
        if (!available() || !granted()) return "ERR"
        return try {
            val p = Shizuku.newProcess(arrayOf("sh", "-c", cmd), null, null)
            val out = BufferedReader(InputStreamReader(p.inputStream)).readText()
            val err = BufferedReader(InputStreamReader(p.errorStream)).readText()
            p.waitFor()
            val r = out.trim().ifBlank { err.trim() }
            r.ifBlank { "OK" }
        } catch (e: Exception) { "ERR:${e.message}" }
    }

    fun tap(x: Int, y: Int) = !shell("input tap $x $y").startsWith("ERR")

    fun cleanRamHard(ctx: Context): Int {
        if (!available() || !granted()) return -1
        var n = 0
        val self = ctx.packageName
        val keep = setOf(
            self, "moe.shizuku.privileged.api", "com.android.systemui",
            "com.android.launcher3", "com.google.android.apps.nexuslauncher",
            "com.miui.home", "com.oppo.launcher", "com.vivo.launcher",
            "com.sec.android.app.launcher", "com.huawei.android.launcher"
        )
        try {
            val pm = ctx.packageManager
            for (ai in pm.getInstalledApplications(0)) {
                val p = ai.packageName
                if (p in keep) continue
                if (p.startsWith("android.") || p.startsWith("com.android.")) continue
                if ((ai.flags and ApplicationInfo.FLAG_SYSTEM) != 0) continue
                if (!shell("am force-stop $p").startsWith("ERR")) n++
            }
            shell("am kill-all")
        } catch (_: Exception) { }
        return n
    }

    /** Super smooth graphics / UI */
    fun graphicsUltraSmooth(on: Boolean) {
        val anim = if (on) "0" else "1"
        shell("settings put global window_animation_scale $anim")
        shell("settings put global transition_animation_scale $anim")
        shell("settings put global animator_duration_scale $anim")
        if (on) {
            // force GPU-ish / reduce jank (best-effort, differs per OEM)
            shell("setprop debug.hwui.renderer skiagl")
            shell("setprop debug.sf.disable_backpressure 1")
            shell("settings put global force_gpu_rendering 1")
            shell("settings put system pointer_speed 7")
            // try peak refresh (may no-op)
            shell("settings put system peak_refresh_rate 120")
            shell("settings put system min_refresh_rate 60")
            shell("cmd power set-mode 0")
            shell("settings put global low_power 0")
        } else {
            shell("settings put global force_gpu_rendering 0")
            shell("settings put system pointer_speed 0")
            shell("settings put system peak_refresh_rate 60")
            shell("settings put system min_refresh_rate 0")
        }
    }

    /**
     * Cool mode: less heat by killing background + lighter system load.
     * Cannot actively cool hardware; reduces heat generation.
     */
    fun coolMode(on: Boolean) {
        if (on) {
            shell("settings put global low_power 1")
            shell("settings put global window_animation_scale 0")
            shell("settings put global transition_animation_scale 0")
            shell("settings put global animator_duration_scale 0")
            shell("am kill-all")
            // best-effort thermal / limit
            shell("cmd thermalservice override-status 0")
            shell("settings put global forced_app_standby_enabled 1")
        } else {
            shell("settings put global low_power 0")
            shell("settings put global window_animation_scale 1")
            shell("settings put global transition_animation_scale 1")
            shell("settings put global animator_duration_scale 1")
            shell("cmd thermalservice reset")
        }
    }

    fun maxSmooth(on: Boolean) = graphicsUltraSmooth(on)

    fun animFast(on: Boolean) {
        val v = if (on) "0.5" else "1"
        shell("settings put global window_animation_scale $v")
        shell("settings put global transition_animation_scale $v")
        shell("settings put global animator_duration_scale $v")
    }

    fun status(): String = when {
        !available() -> "Shizuku OFF"
        !granted() -> "Shizuku ON • izin belum"
        else -> "Shizuku SIAP"
    }
}

__EOF__

mkdir -p "app/src/main/java/com/elaina/optimasi"
cat > "app/src/main/java/com/elaina/optimasi/TapService.kt" <<'__EOF__'
package com.elaina.optimasi

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.view.Gravity
import android.view.MotionEvent
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.TextView
import java.util.concurrent.atomic.AtomicBoolean

class TapService : Service() {
    private var wm: WindowManager? = null
    private var view: FrameLayout? = null
    private var label: TextView? = null
    private val h = Handler(Looper.getMainLooper())
    private val on = AtomicBoolean(false)
    private var cps = 12
    private var px = 0
    private var py = 0
    private var wake: PowerManager.WakeLock? = null

    override fun onBind(i: Intent?): IBinder? = null

    override fun onStartCommand(i: Intent?, f: Int, id: Int): Int {
        cps = (i?.getIntExtra("cps", 12) ?: 12).coerceIn(5, 30)
        startFg()
        if (view == null) showBtn()
        // keep CPU awake while service runs (helps stability in games)
        try {
            val pm = getSystemService(POWER_SERVICE) as PowerManager
            if (wake == null) {
                wake = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "elaina:tap")
                wake?.acquire(60 * 60 * 1000L)
            }
        } catch (_: Exception) { }
        return START_STICKY
    }

    private fun startFg() {
        val ch = "elaina_tap"
        if (Build.VERSION.SDK_INT >= 26) {
            val nm = getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(
                NotificationChannel(ch, "ELAINA Turbo", NotificationManager.IMPORTANCE_LOW)
            )
        }
        val pi = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val n = if (Build.VERSION.SDK_INT >= 26) {
            Notification.Builder(this, ch)
        } else {
            @Suppress("DEPRECATION") Notification.Builder(this)
        }
            .setContentTitle("ELAINA Turbo aktif")
            .setContentText("Tombol TAP berjalan — jangan di-swipe tutup")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentIntent(pi)
            .setOngoing(true)
            .build()
        startForeground(1001, n)
    }

    private fun showBtn() {
        wm = getSystemService(WINDOW_SERVICE) as WindowManager
        val fl = FrameLayout(this)
        val tv = TextView(this).apply {
            text = "TAP"
            setTextColor(Color.WHITE)
            textSize = 13f
            gravity = Gravity.CENTER
            setPadding(28, 28, 28, 28)
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(0xE0FF1744.toInt())
            }
        }
        label = tv
        fl.addView(tv, FrameLayout.LayoutParams(150, 150, Gravity.CENTER))
        val lp = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = 60; y = 400
            if (Build.VERSION.SDK_INT >= 28) layoutInDisplayCutoutMode =
                WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
        var lx = 0f; var ly = 0f; var moved = false
        fl.setOnTouchListener { v, e ->
            when (e.action) {
                MotionEvent.ACTION_DOWN -> { lx = e.rawX; ly = e.rawY; moved = false; true }
                MotionEvent.ACTION_MOVE -> {
                    val dx = (e.rawX - lx).toInt(); val dy = (e.rawY - ly).toInt()
                    if (kotlin.math.abs(dx) > 5 || kotlin.math.abs(dy) > 5) moved = true
                    lp.x += dx; lp.y += dy; lx = e.rawX; ly = e.rawY
                    try { wm?.updateViewLayout(v, lp) } catch (_: Exception) {}
                    true
                }
                MotionEvent.ACTION_UP -> { if (!moved) toggle(); true }
                else -> false
            }
        }
        view = fl
        try { wm?.addView(fl, lp) } catch (_: Exception) { stopSelf() }
    }

    private fun toggle() {
        if (on.get()) stopTap() else startTap()
    }

    private fun startTap() {
        if (!ShizukuHelper.available() || !ShizukuHelper.granted()) {
            label?.text = "NO SZ"; return
        }
        on.set(true)
        label?.text = "ON"
        label?.background = GradientDrawable().apply {
            shape = GradientDrawable.OVAL; setColor(0xE000E676.toInt())
        }
        val delay = (1000L / cps).coerceAtLeast(33L)
        val loop = object : Runnable {
            override fun run() {
                if (!on.get()) return
                view?.let {
                    val loc = IntArray(2)
                    it.getLocationOnScreen(loc)
                    px = loc[0] + it.width / 2
                    py = loc[1] + it.height / 2 - 12
                }
                ShizukuHelper.tap(px, py)
                h.postDelayed(this, delay)
            }
        }
        h.post(loop)
    }

    private fun stopTap() {
        on.set(false)
        label?.text = "TAP"
        label?.background = GradientDrawable().apply {
            shape = GradientDrawable.OVAL; setColor(0xE0FF1744.toInt())
        }
    }

    override fun onDestroy() {
        on.set(false)
        try { wake?.release() } catch (_: Exception) {}
        wake = null
        view?.let { try { wm?.removeView(it) } catch (_: Exception) {} }
        view = null
        super.onDestroy()
    }
}

__EOF__

mkdir -p "app/src/main/res/drawable"
cat > "app/src/main/res/drawable/ic_launcher.xml" <<'__EOF__'
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp" android:height="108dp"
    android:viewportWidth="108" android:viewportHeight="108">
    <path android:fillColor="#0A0A0F" android:pathData="M0,0h108v108h-108z"/>
    <path android:fillColor="#FF1744" android:pathData="M54,14c-22,0 -40,18 -40,40s18,40 40,40 40,-18 40,-40 -18,-40 -40,-40z"/>
    <path android:fillColor="#FFFFFF"
        android:pathData="M54,32c-8,0 -14,6 -14,14 0,6 4,11 10,13v4h8v-4c6,-2 10,-7 10,-13 0,-8 -6,-14 -14,-14z"/>
    <path android:fillColor="#FF8A80"
        android:pathData="M38,72c0,-6 7,-10 16,-10s16,4 16,10v4H38v-4z"/>
    <path android:fillColor="#FFFFFF" android:pathData="M50,52h8v18h-8z"/>
    <path android:fillColor="#FFFFFF" android:pathData="M45,57h18v3h-18z"/>
</vector>

__EOF__

mkdir -p "app/src/main/res/values"
cat > "app/src/main/res/values/strings.xml" <<'__EOF__'
<resources>
    <string name="app_name">ELAINA Optimasi</string>
</resources>

__EOF__

cat > "build.gradle.kts" <<'__EOF__'
plugins {
    id("com.android.application") version "8.2.2" apply false
    id("org.jetbrains.kotlin.android") version "1.9.22" apply false
}

__EOF__

cat > "gradle.properties" <<'__EOF__'
org.gradle.jvmargs=-Xmx2048m -Dfile.encoding=UTF-8
android.useAndroidX=true
android.nonTransitiveRClass=true

__EOF__

cat > "settings.gradle.kts" <<'__EOF__'
pluginManagement {
    repositories { google(); mavenCentral(); gradlePluginPortal() }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories { google(); mavenCentral() }
}
rootProject.name = "ElainaOptimasi"
include(":app")

__EOF__

echo "[ELAINA] done"