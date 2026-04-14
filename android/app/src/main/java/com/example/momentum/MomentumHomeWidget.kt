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

class MomentumHomeWidget : AppWidgetProvider() {

    companion object {
        private const val TAG = "MomentumHomeWidget"

        // Broadcast actions — must match what's in AndroidManifest intent-filters
        const val ACTION_REFRESH       = "com.example.momentum.WIDGET_REFRESH"
        const val ACTION_TASK_TAPPED   = "com.example.momentum.WIDGET_TASK_TAPPED"
        const val ACTION_TASK_COMPLETE = "com.example.momentum.WIDGET_TASK_COMPLETE"

        // Intent extras
        const val EXTRA_TASK_ID    = "task_id"
        const val EXTRA_TASK_INDEX = "task_index"
        const val EXTRA_WIDGET_ACTION = "widget_action"

        // ── PendingIntent flag helper ────────────────────────────────────────
        private val updateFlag get() = PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag
        private val mutableFlag get() = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0
        private val immutableFlag get() =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0

        // ── Public entry point called from anywhere in the app ───────────────
        fun triggerUpdate(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, MomentumHomeWidget::class.java)
            val ids = manager.getAppWidgetIds(component)
            if (ids.isNotEmpty()) {
                for (id in ids) {
                    try {
                        updateAppWidget(context, manager, id)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error updating widget $id", e)
                    }
                }
            }
        }

        // ── Core widget update ───────────────────────────────────────────────
        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val views = RemoteViews(context.packageName, R.layout.momentum_home_widget)

            val prefs = readPrefs(context)
            val rawTasks = prefs.second
            val teamName = prefs.third

            // ── Header: team name ────────────────────────────────────────────
            views.setTextViewText(R.id.widget_team_name, "$teamName ▾")

            // ── Header click intents ─────────────────────────────────────────

            // Refresh — broadcast to this provider
            val refreshIntent = Intent(context, MomentumHomeWidget::class.java).apply {
                action = ACTION_REFRESH
            }
            views.setOnClickPendingIntent(
                R.id.widget_refresh,
                PendingIntent.getBroadcast(context, 10, refreshIntent, updateFlag)
            )

            // Add task — opens app with extra so Flutter knows to open create dialog
            views.setOnClickPendingIntent(
                R.id.widget_add,
                buildLaunchIntent(context, requestCode = 11, widgetAction = "add_task")
            )

            // Team name — opens app with extra so Flutter knows to open team selector
            views.setOnClickPendingIntent(
                R.id.widget_team_name,
                buildLaunchIntent(context, requestCode = 12, widgetAction = "select_team")
            )

            // Settings — just opens app
            views.setOnClickPendingIntent(
                R.id.widget_settings,
                buildLaunchIntent(context, requestCode = 13, widgetAction = null)
            )

            // ── Task list ────────────────────────────────────────────────────
            var taskCount = 0
            if (rawTasks.isNotBlank()) {
                try {
                    taskCount = JSONArray(rawTasks).length()
                } catch (e: Exception) {
                    Log.w(TAG, "Could not parse tasks JSON: ${e.message}")
                }
            }

            if (taskCount == 0) {
                views.setViewVisibility(R.id.widget_task_list, View.GONE)
                views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.widget_task_list, View.VISIBLE)
                views.setViewVisibility(R.id.widget_empty, View.GONE)

                // Bind RemoteViewsService to the ListView
                // The URI must be unique per appWidgetId so Android doesn't reuse
                // the wrong factory for different widget instances.
                val serviceIntent = Intent(context, MomentumWidgetService::class.java).apply {
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                    data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
                }
                views.setRemoteAdapter(R.id.widget_task_list, serviceIntent)

                // Template PendingIntent — each row fills in task_id and action
                // Must be FLAG_MUTABLE so the fill-in extras can be merged in
                val templateIntent = Intent(context, MomentumHomeWidget::class.java).apply {
                    action = ACTION_TASK_TAPPED
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                }
                val templatePending = PendingIntent.getBroadcast(
                    context, 20, templateIntent, mutableFlag
                )
                views.setPendingIntentTemplate(R.id.widget_task_list, templatePending)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)

            // Tell the RemoteViewsFactory to reload its data
            if (taskCount > 0) {
                appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_task_list)
            }

            Log.i(TAG, "Widget $appWidgetId updated — $taskCount tasks, team=$teamName")
        }

        // ── SharedPreferences reader — tries all known home_widget file names ─
        // Returns Triple(heatmapString, tasksJson, teamName)
        fun readPrefs(context: Context): Triple<String, String, String> {
            val candidates = listOf(
                "${context.packageName}.home_widget",   // home_widget >= 0.5.0
                "home_widget_preferences",
                context.packageName,
                "HomeWidgetPreferences",
            )
            for (name in candidates) {
                val sp = context.getSharedPreferences(name, Context.MODE_PRIVATE)
                val tasks = sp.getString("widget_tasks", null)
                val heatmap = sp.getString("heatmap_data", null)
                val team = sp.getString("widget_team_name", null)
                if (!tasks.isNullOrBlank() || !heatmap.isNullOrBlank()) {
                    Log.i(TAG, "Data found in prefs: $name | tasks=${tasks?.length} chars | team=$team")
                    return Triple(heatmap ?: "", tasks ?: "", team ?: "My Tasks")
                }
            }

            // Log all keys that exist to help diagnose the exact prefs file name
            for (name in candidates) {
                val sp = context.getSharedPreferences(name, Context.MODE_PRIVATE)
                val allKeys = sp.all.keys
                if (allKeys.isNotEmpty()) {
                    Log.d(TAG, "Prefs '$name' exists with keys: $allKeys (but not widget_tasks)")
                }
            }

            Log.w(TAG, "No widget data — open the app first so Flutter can write SharedPreferences")
            return Triple("", "", "My Tasks")
        }

        private fun buildLaunchIntent(
            context: Context,
            requestCode: Int,
            widgetAction: String?
        ): PendingIntent {
            val intent = context.packageManager
                .getLaunchIntentForPackage(context.packageName)
                ?.apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    widgetAction?.let { putExtra(EXTRA_WIDGET_ACTION, it) }
                }
                ?: Intent()
            return PendingIntent.getActivity(context, requestCode, intent, updateFlag)
        }
    }

    // ── AppWidgetProvider callbacks ──────────────────────────────────────────

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        Log.i(TAG, "onUpdate for ${appWidgetIds.size} widget(s)")
        for (id in appWidgetIds) {
            try {
                updateAppWidget(context, appWidgetManager, id)
            } catch (e: Exception) {
                Log.e(TAG, "onUpdate failed for id=$id", e)
                showSafeErrorState(context, appWidgetManager, id)
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)

        when (intent.action) {

            ACTION_REFRESH -> {
                Log.i(TAG, "Refresh broadcast received")
                triggerUpdate(context)
            }

            ACTION_TASK_TAPPED -> {
                val taskId = intent.getStringExtra(EXTRA_TASK_ID) ?: return
                val action = intent.getStringExtra("tap_action") ?: "open"
                Log.i(TAG, "Task tapped: id=$taskId action=$action")

                // Open the Flutter app and tell it what to do.
                // Flutter reads widget_action and task_id from the intent in MainActivity.
                val launchAction = when (action) {
                    "complete" -> "complete_task"
                    else -> "open_task"
                }
                val launch = context.packageManager
                    .getLaunchIntentForPackage(context.packageName)
                    ?.apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                        putExtra(EXTRA_WIDGET_ACTION, launchAction)
                        putExtra(EXTRA_TASK_ID, taskId)
                    }
                if (launch != null) context.startActivity(launch)
            }
        }
    }

    // Minimal RemoteViews that never fails — used when the main update throws
    private fun showSafeErrorState(
        context: Context,
        manager: AppWidgetManager,
        id: Int
    ) {
        try {
            val views = RemoteViews(context.packageName, R.layout.momentum_home_widget)
            views.setTextViewText(R.id.widget_team_name, "Momentum ▾")
            views.setViewVisibility(R.id.widget_task_list, View.GONE)
            views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
            views.setTextViewText(R.id.widget_empty, "Tap to open app")
            val launch = buildLaunchIntent(context, 99, null)
            views.setOnClickPendingIntent(R.id.widget_empty, launch)
            views.setOnClickPendingIntent(R.id.widget_team_name, launch)
            manager.updateAppWidget(id, views)
        } catch (e: Exception) {
            Log.e(TAG, "Even safe error state failed", e)
        }
    }
}