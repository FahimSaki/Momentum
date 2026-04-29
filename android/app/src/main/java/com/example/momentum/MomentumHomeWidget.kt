package com.example.momentum

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONException

class MomentumHomeWidget : AppWidgetProvider() {

    companion object {
        private const val TAG = "MomentumWidget"
        private const val MAX_ROWS = 5

        const val ACTION_REFRESH     = "com.example.momentum.WIDGET_REFRESH"
        const val ACTION_TASK_TAPPED = "com.example.momentum.WIDGET_TASK_TAPPED"
        const val EXTRA_TASK_ID      = "task_id"

        private val ROW_IDS   = intArrayOf(R.id.row0, R.id.row1, R.id.row2, R.id.row3, R.id.row4)
        private val CHECK_IDS = intArrayOf(R.id.check0, R.id.check1, R.id.check2, R.id.check3, R.id.check4)
        private val NAME_IDS  = intArrayOf(R.id.name0, R.id.name1, R.id.name2, R.id.name3, R.id.name4)

        private fun immutableFlag(): Int =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            else
                PendingIntent.FLAG_UPDATE_CURRENT

        fun triggerUpdate(context: Context) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(ComponentName(context, MomentumHomeWidget::class.java))
            Log.d(TAG, "triggerUpdate: ${ids.size} widget(s)")
            ids.forEach { id ->
                try { updateAppWidget(context, mgr, id) }
                catch (e: Exception) { Log.e(TAG, "triggerUpdate failed id=$id", e) }
            }
        }

        fun updateAppWidget(context: Context, mgr: AppWidgetManager, widgetId: Int) {
            Log.d(TAG, "updateAppWidget id=$widgetId")
            try {
                val views = RemoteViews(context.packageName, R.layout.momentum_home_widget)

                val (_, rawTasks, teamName) = readPrefs(context)
                val label = if (teamName.isBlank()) "Personal Tasks" else teamName
                views.setTextViewText(R.id.widget_team_name, label)

                // Header buttons
                views.setOnClickPendingIntent(R.id.widget_refresh,
                    makeRefreshIntent(context, widgetId))
                views.setOnClickPendingIntent(R.id.widget_add,
                    makeOpenAppIntent(context, widgetId * 10 + 2, "add_task"))
                views.setOnClickPendingIntent(R.id.widget_team_name,
                    makeOpenAppIntent(context, widgetId * 10 + 3, "select_team"))

                val tasks = parseTasks(rawTasks)
                Log.d(TAG, "Rendering ${tasks.size} tasks from rawTasks length=${rawTasks.length}")

                if (tasks.isEmpty()) {
                    views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
                    ROW_IDS.forEach { views.setViewVisibility(it, View.GONE) }
                    views.setOnClickPendingIntent(R.id.widget_empty,
                        makeOpenAppIntent(context, widgetId * 10 + 4, "add_task"))
                } else {
                    views.setViewVisibility(R.id.widget_empty, View.GONE)

                    for (i in 0 until MAX_ROWS) {
                        if (i < tasks.size) {
                            val task = tasks[i]
                            views.setViewVisibility(ROW_IDS[i], View.VISIBLE)

                            val checkText  = if (task.isCompleted) "✓" else "○"
                            val checkColor = if (task.isCompleted) 0xFF4CAF50.toInt() else 0xFF888888.toInt()
                            val nameColor  = if (task.isCompleted) 0x88FFFFFF.toInt() else 0xFFFFFFFF.toInt()

                            views.setTextViewText(CHECK_IDS[i], checkText)
                            views.setInt(CHECK_IDS[i], "setTextColor", checkColor)
                            views.setTextViewText(NAME_IDS[i], task.name)
                            views.setInt(NAME_IDS[i], "setTextColor", nameColor)

                            views.setOnClickPendingIntent(ROW_IDS[i],
                                makeOpenAppIntent(context, widgetId * 100 + i, "open_task"))
                        } else {
                            views.setViewVisibility(ROW_IDS[i], View.GONE)
                        }
                    }
                }

                mgr.updateAppWidget(widgetId, views)
                Log.d(TAG, "Widget $widgetId updated OK")

            } catch (e: Exception) {
                Log.e(TAG, "updateAppWidget crashed id=$widgetId", e)
                renderFallback(context, mgr, widgetId)
            }
        }

        private fun renderFallback(context: Context, mgr: AppWidgetManager, widgetId: Int) {
            try {
                val views = RemoteViews(context.packageName, R.layout.momentum_home_widget)
                views.setTextViewText(R.id.widget_team_name, "Momentum")
                views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
                views.setTextViewText(R.id.widget_empty, "Tap to open app")
                ROW_IDS.forEach { views.setViewVisibility(it, View.GONE) }
                val openIntent = makeOpenAppIntent(context, widgetId * 10 + 9, null)
                views.setOnClickPendingIntent(R.id.widget_empty, openIntent)
                views.setOnClickPendingIntent(R.id.widget_team_name, openIntent)
                mgr.updateAppWidget(widgetId, views)
            } catch (e: Exception) {
                Log.e(TAG, "Fallback also failed id=$widgetId", e)
            }
        }

        private fun makeRefreshIntent(context: Context, widgetId: Int): PendingIntent =
            PendingIntent.getBroadcast(
                context, widgetId * 10 + 1,
                Intent(context, MomentumHomeWidget::class.java).apply {
                    action = ACTION_REFRESH
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                },
                immutableFlag()
            )

        private fun makeOpenAppIntent(context: Context, requestCode: Int, action: String?): PendingIntent {
            val uri = Uri.Builder()
                .scheme("homeWidget")
                .authority("widget")
                .apply { action?.let { appendQueryParameter("widget_action", it) } }
                .build()
            val intent = Intent(Intent.ACTION_VIEW, uri).apply {
                setPackage(context.packageName)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            return PendingIntent.getActivity(context, requestCode, intent, immutableFlag())
        }

        data class WidgetTask(val id: String, val name: String, val isCompleted: Boolean)

        private fun parseTasks(raw: String): List<WidgetTask> {
            if (raw.isBlank()) return emptyList()
            return try {
                val arr = JSONArray(raw)
                (0 until arr.length()).mapNotNull { i ->
                    val obj = arr.optJSONObject(i) ?: return@mapNotNull null
                    WidgetTask(
                        id          = obj.optString("id", i.toString()),
                        name        = obj.optString("name", "Task"),
                        isCompleted = obj.optBoolean("completed", false)
                    )
                }.take(MAX_ROWS)
            } catch (e: JSONException) {
                Log.e(TAG, "JSON parse error for raw='${raw.take(100)}'", e)
                emptyList()
            }
        }

        /**
         * home_widget v0.9.x writes to "HomeWidgetPreferences" by default.
         * We try that first, then fall back to older naming conventions.
         */
        fun readPrefs(context: Context): Triple<String, String, String> {
            // home_widget v0.9 uses this file name
            val candidates = listOf(
                "HomeWidgetPreferences",
                "${context.packageName}.home_widget",
                context.packageName,
                "FlutterSharedPreferences",
            )

            for (name in candidates) {
                try {
                    val sp = context.getSharedPreferences(name, Context.MODE_PRIVATE)
                    val allKeys = sp.all.keys.toList()
                    Log.d(TAG, "Checking prefs '$name' — keys: $allKeys")

                    val tasks = sp.getString("widget_tasks", null)
                    val team  = sp.getString("widget_team_name", null)

                    if (!tasks.isNullOrBlank() || !team.isNullOrBlank()) {
                        Log.d(TAG, "Prefs found in '$name': tasks=${tasks?.take(50)}, team=$team")
                        return Triple(
                            sp.getString("heatmap_data", "") ?: "",
                            tasks ?: "",
                            team  ?: ""
                        )
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "Could not read prefs '$name'", e)
                }
            }

            Log.w(TAG, "No widget prefs found in any candidate file — showing empty state")
            return Triple("", "", "")
        }
    }

    override fun onUpdate(context: Context, mgr: AppWidgetManager, ids: IntArray) {
        Log.d(TAG, "onUpdate: ${ids.toList()}")
        ids.forEach { id ->
            try { updateAppWidget(context, mgr, id) }
            catch (e: Exception) { Log.e(TAG, "onUpdate failed id=$id", e) }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            ACTION_REFRESH -> {
                Log.d(TAG, "Refresh received")
                triggerUpdate(context)
            }
            ACTION_TASK_TAPPED -> {
                val taskId = intent.getStringExtra(EXTRA_TASK_ID) ?: return
                val uri = Uri.Builder()
                    .scheme("homeWidget").authority("widget")
                    .appendQueryParameter("widget_action", "open_task")
                    .appendQueryParameter("task_id", taskId)
                    .build()
                try {
                    context.startActivity(
                        Intent(Intent.ACTION_VIEW, uri).apply {
                            setPackage(context.packageName)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                        }
                    )
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to open app", e)
                }
            }
        }
    }
}