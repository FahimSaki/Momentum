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

        const val ACTION_REFRESH      = "com.example.momentum.WIDGET_REFRESH"
        const val ACTION_TASK_TAPPED  = "com.example.momentum.WIDGET_TASK_TAPPED"

        const val EXTRA_TASK_ID       = "task_id"
        const val EXTRA_WIDGET_ACTION = "widget_action"

        // ── PendingIntent flag helpers ───────────────────────────────────────

        /** For intents that must NOT be mutated (launch, refresh). */
        private fun immutableFlag() =
            PendingIntent.FLAG_UPDATE_CURRENT or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                    PendingIntent.FLAG_IMMUTABLE else 0

        /** For the list-template intent that Android fills in extras for each row. */
        private fun mutableFlag() =
            PendingIntent.FLAG_UPDATE_CURRENT or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
                    PendingIntent.FLAG_MUTABLE else 0

        // ── Public entry point ───────────────────────────────────────────────

        fun triggerUpdate(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids     = manager.getAppWidgetIds(
                ComponentName(context, MomentumHomeWidget::class.java)
            )
            ids.forEach { id ->
                try { updateAppWidget(context, manager, id) }
                catch (e: Exception) { Log.e(TAG, "triggerUpdate failed for $id", e) }
            }
        }

        // ── Core widget draw ─────────────────────────────────────────────────

        fun updateAppWidget(
            context:          Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId:      Int,
        ) {
            try {
                val views = RemoteViews(context.packageName, R.layout.momentum_home_widget)
                val (_, rawTasks, teamName) = readPrefs(context)

                // ── Header ───────────────────────────────────────────────────

                views.setTextViewText(R.id.widget_team_name, "$teamName  ▾")

                // Refresh broadcast
                val refreshIntent = Intent(context, MomentumHomeWidget::class.java).apply {
                    action = ACTION_REFRESH
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                }
                views.setOnClickPendingIntent(
                    R.id.widget_refresh,
                    PendingIntent.getBroadcast(
                        context,
                        appWidgetId * 100,          // unique request code per widget
                        refreshIntent,
                        immutableFlag(),
                    )
                )

                // Add-task button → opens app
                views.setOnClickPendingIntent(
                    R.id.widget_add,
                    buildLaunchPending(context, appWidgetId * 100 + 1, "add_task"),
                )

                // Team-name tap → open team selector in app
                views.setOnClickPendingIntent(
                    R.id.widget_team_name,
                    buildLaunchPending(context, appWidgetId * 100 + 2, "select_team"),
                )

                // ── Task list ────────────────────────────────────────────────

                var taskCount = 0
                if (rawTasks.isNotBlank()) {
                    runCatching { taskCount = JSONArray(rawTasks).length() }
                }

                if (taskCount == 0) {
                    views.setViewVisibility(R.id.widget_task_list, View.GONE)
                    views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
                    // Tapping empty state opens app to add a task
                    views.setOnClickPendingIntent(
                        R.id.widget_empty,
                        buildLaunchPending(context, appWidgetId * 100 + 3, "add_task"),
                    )
                } else {
                    views.setViewVisibility(R.id.widget_task_list, View.VISIBLE)
                    views.setViewVisibility(R.id.widget_empty, View.GONE)

                    // Bind RemoteViewsService to the ListView.
                    // The data URI must be unique per appWidgetId so Android uses a
                    // separate factory cache for each widget instance.
                    val serviceIntent = Intent(context, MomentumWidgetService::class.java)
                    serviceIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                    serviceIntent.data = Uri.parse("widget://$appWidgetId")

                    views.setRemoteAdapter(R.id.widget_task_list, serviceIntent)

                    // Template PendingIntent – each row fills in EXTRA_TASK_ID + tap_action.
                    // Must be FLAG_MUTABLE so Android can merge fill-in extras.
                    val templateIntent = Intent(context, MomentumHomeWidget::class.java).apply {
                        action = ACTION_TASK_TAPPED
                        putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                    }
                    views.setPendingIntentTemplate(
                        R.id.widget_task_list,
                        PendingIntent.getBroadcast(
                            context,
                            appWidgetId * 100 + 4,
                            templateIntent,
                            mutableFlag(),
                        )
                    )
                }

                appWidgetManager.updateAppWidget(appWidgetId, views)

                // Notify the factory to reload data for the list.
                if (taskCount > 0) {
                    appWidgetManager.notifyAppWidgetViewDataChanged(
                        appWidgetId, R.id.widget_task_list
                    )
                }

                Log.i(TAG, "Widget $appWidgetId updated — $taskCount tasks, team=$teamName")

            } catch (e: Exception) {
                Log.e(TAG, "updateAppWidget crashed for $appWidgetId", e)
                showSafeState(context, appWidgetManager, appWidgetId)
            }
        }

        // ── Minimal fallback when main update fails ──────────────────────────

        private fun showSafeState(context: Context, manager: AppWidgetManager, id: Int) {
            runCatching {
                val v = RemoteViews(context.packageName, R.layout.momentum_home_widget)
                v.setTextViewText(R.id.widget_team_name, "Momentum  ▾")
                v.setViewVisibility(R.id.widget_task_list, View.GONE)
                v.setViewVisibility(R.id.widget_empty, View.VISIBLE)
                v.setTextViewText(R.id.widget_empty, "Tap to open the app")
                v.setOnClickPendingIntent(
                    R.id.widget_empty,
                    buildLaunchPending(context, id * 100 + 99, null),
                )
                manager.updateAppWidget(id, v)
            }.onFailure { Log.e(TAG, "Even safe state failed", it) }
        }

        // ── SharedPreferences reader ─────────────────────────────────────────
        // Returns Triple(heatmapString, tasksJson, teamName).
        // Tries all known file names written by the home_widget Flutter package.

        fun readPrefs(context: Context): Triple<String, String, String> {
            val candidates = listOf(
                "${context.packageName}.home_widget",   // home_widget >= 0.5.0 (most common)
                "home_widget_preferences",
                context.packageName,
                "HomeWidgetPreferences",
            )
            for (name in candidates) {
                val sp    = context.getSharedPreferences(name, Context.MODE_PRIVATE)
                val tasks = sp.getString("widget_tasks", null)
                val heat  = sp.getString("heatmap_data", null)
                val team  = sp.getString("widget_team_name", null)
                if (!tasks.isNullOrBlank() || !heat.isNullOrBlank()) {
                    Log.i(TAG, "Prefs '$name' — tasks=${tasks?.length} team=$team")
                    return Triple(heat ?: "", tasks ?: "", team ?: "My Tasks")
                }
            }
            Log.w(TAG, "No widget data found — open the app first")
            return Triple("", "", "My Tasks")
        }

        // ── Helpers ──────────────────────────────────────────────────────────

        private fun buildLaunchPending(
            context:      Context,
            requestCode:  Int,
            widgetAction: String?,
        ): PendingIntent {
            val intent = context.packageManager
                .getLaunchIntentForPackage(context.packageName)
                ?.apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    widgetAction?.let { putExtra(EXTRA_WIDGET_ACTION, it) }
                } ?: Intent()
            return PendingIntent.getActivity(context, requestCode, intent, immutableFlag())
        }
    }

    // ── AppWidgetProvider overrides ──────────────────────────────────────────

    override fun onUpdate(
        context:          Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds:     IntArray,
    ) {
        Log.i(TAG, "onUpdate for ${appWidgetIds.size} widget(s)")
        appWidgetIds.forEach { id ->
            try { updateAppWidget(context, appWidgetManager, id) }
            catch (e: Exception) { Log.e(TAG, "onUpdate failed for $id", e) }
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
                val taskId    = intent.getStringExtra(EXTRA_TASK_ID) ?: return
                val tapAction = intent.getStringExtra("tap_action") ?: "open"
                Log.i(TAG, "Task tapped: id=$taskId action=$tapAction")

                val launchAction = when (tapAction) {
                    "complete" -> "complete_task"
                    "delete"   -> "delete_task"
                    else       -> "open_task"
                }

                context.packageManager
                    .getLaunchIntentForPackage(context.packageName)
                    ?.apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                        putExtra(EXTRA_WIDGET_ACTION, launchAction)
                        putExtra(EXTRA_TASK_ID, taskId)
                    }
                    ?.let { context.startActivity(it) }
            }
        }
    }
}