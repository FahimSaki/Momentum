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
        private const val TAG = "MomentumHomeWidget"

        const val ACTION_REFRESH     = "com.example.momentum.WIDGET_REFRESH"
        const val ACTION_TASK_TAPPED = "com.example.momentum.WIDGET_TASK_TAPPED"
        const val EXTRA_TASK_ID      = "task_id"
        const val EXTRA_WIDGET_ACTION = "widget_action"

        private fun immutableFlag() =
            PendingIntent.FLAG_UPDATE_CURRENT or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                    PendingIntent.FLAG_IMMUTABLE else 0

        private fun mutableFlag() =
            PendingIntent.FLAG_UPDATE_CURRENT or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
                    PendingIntent.FLAG_MUTABLE else 0

        // Called from Flutter's WidgetService after data is written
        fun triggerUpdate(context: Context) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(ComponentName(context, MomentumHomeWidget::class.java))
            ids.forEach { id ->
                try { updateAppWidget(context, mgr, id) }
                catch (e: Exception) { Log.e(TAG, "triggerUpdate failed for $id", e) }
            }
        }

        fun updateAppWidget(context: Context, mgr: AppWidgetManager, widgetId: Int) {
            try {
                val views = RemoteViews(context.packageName, R.layout.momentum_home_widget)
                val (_, rawTasks, teamName) = readPrefs(context)
                val label = if (teamName.isBlank()) "Personal Tasks  ▾" else "$teamName  ▾"

                views.setTextViewText(R.id.widget_team_name, label)

                // Refresh button
                views.setOnClickPendingIntent(R.id.widget_refresh,
                    PendingIntent.getBroadcast(
                        context, widgetId * 10 + 1,
                        Intent(context, MomentumHomeWidget::class.java).also {
                            it.action = ACTION_REFRESH
                            it.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                        },
                        immutableFlag()
                    ))

                // Add task button
                views.setOnClickPendingIntent(R.id.widget_add,
                    appLaunchPending(context, widgetId * 10 + 2, "add_task", null))

                // Team name tap → open team selector in app
                views.setOnClickPendingIntent(R.id.widget_team_name,
                    appLaunchPending(context, widgetId * 10 + 3, "select_team", null))

                val taskCount = taskCount(rawTasks)

                if (taskCount == 0) {
                    views.setViewVisibility(R.id.widget_task_list, View.GONE)
                    views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
                    views.setOnClickPendingIntent(R.id.widget_empty,
                        appLaunchPending(context, widgetId * 10 + 4, "add_task", null))
                } else {
                    views.setViewVisibility(R.id.widget_task_list, View.VISIBLE)
                    views.setViewVisibility(R.id.widget_empty, View.GONE)

                    // Each widget instance needs a unique data URI so Android
                    // creates a separate RemoteViewsFactory for it.
                    val serviceIntent = Intent(context, MomentumWidgetService::class.java).apply {
                        putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                        data = Uri.parse("content://momentum.tasks/$widgetId")
                    }
                    views.setRemoteAdapter(R.id.widget_task_list, serviceIntent)
                    views.setEmptyView(R.id.widget_task_list, R.id.widget_empty)

                    // All row clicks funnel through this template; each row
                    // fills in EXTRA_TASK_ID + "tap_action" via fillInIntent.
                    views.setPendingIntentTemplate(
                        R.id.widget_task_list,
                        PendingIntent.getBroadcast(
                            context, widgetId * 10 + 5,
                            Intent(context, MomentumHomeWidget::class.java).also {
                                it.action = ACTION_TASK_TAPPED
                                it.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                            },
                            mutableFlag()  // MUST be mutable for fill-in extras
                        )
                    )
                }

                mgr.updateAppWidget(widgetId, views)
                if (taskCount > 0)
                    mgr.notifyAppWidgetViewDataChanged(widgetId, R.id.widget_task_list)

            } catch (e: Exception) {
                Log.e(TAG, "Widget $widgetId update failed", e)
                showSafeState(context, mgr, widgetId)
            }
        }

        // Minimal safe render when anything goes wrong
        private fun showSafeState(context: Context, mgr: AppWidgetManager, widgetId: Int) {
            runCatching {
                val v = RemoteViews(context.packageName, R.layout.momentum_home_widget)
                v.setTextViewText(R.id.widget_team_name, "Momentum  ▾")
                v.setViewVisibility(R.id.widget_task_list, View.GONE)
                v.setViewVisibility(R.id.widget_empty, View.VISIBLE)
                v.setTextViewText(R.id.widget_empty, "Open the app to sync tasks")
                v.setOnClickPendingIntent(R.id.widget_empty,
                    appLaunchPending(context, widgetId * 10 + 9, null, null))
                v.setOnClickPendingIntent(R.id.widget_team_name,
                    appLaunchPending(context, widgetId * 10 + 8, null, null))
                mgr.updateAppWidget(widgetId, v)
            }.onFailure { Log.e(TAG, "Safe state also failed for $widgetId", it) }
        }

        private fun taskCount(raw: String): Int {
            if (raw.isBlank()) return 0
            return try { JSONArray(raw).length() } catch (_: JSONException) { 0 }
        }

        private fun appLaunchPending(
            context: Context, requestCode: Int, action: String?, taskId: String?
        ): PendingIntent {
            val intent = (context.packageManager.getLaunchIntentForPackage(context.packageName)
                ?: Intent(context, MainActivity::class.java)).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                action?.let { putExtra(EXTRA_WIDGET_ACTION, it) }
                taskId?.let { putExtra(EXTRA_TASK_ID, it) }
            }
            return PendingIntent.getActivity(context, requestCode, intent, immutableFlag())
        }

        // Tries all known SharedPreferences file names written by home_widget pkg
        fun readPrefs(context: Context): Triple<String, String, String> {
            val candidates = listOf(
                "${context.packageName}.home_widget",   // home_widget >= 0.4
                "HomeWidgetPreferences",
                context.packageName,
            )
            for (name in candidates) {
                runCatching {
                    val sp    = context.getSharedPreferences(name, Context.MODE_PRIVATE)
                    val tasks = sp.getString("widget_tasks", null)
                    val team  = sp.getString("widget_team_name", null)
                    if (!tasks.isNullOrBlank() || team != null) {
                        Log.d(TAG, "Prefs found in '$name'")
                        return Triple(
                            sp.getString("heatmap_data", "") ?: "",
                            tasks ?: "",
                            team  ?: ""
                        )
                    }
                }
            }
            return Triple("", "", "")
        }
    }

    override fun onUpdate(context: Context, mgr: AppWidgetManager, ids: IntArray) {
        ids.forEach { id ->
            try { updateAppWidget(context, mgr, id) }
            catch (e: Exception) { Log.e(TAG, "onUpdate failed for $id", e) }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            ACTION_REFRESH -> {
                Log.d(TAG, "Refresh broadcast received")
                triggerUpdate(context)
            }
            ACTION_TASK_TAPPED -> {
                val taskId    = intent.getStringExtra(EXTRA_TASK_ID) ?: return
                val tapAction = intent.getStringExtra("tap_action") ?: "open_task"
                Log.d(TAG, "Task tapped: id=$taskId action=$tapAction")
                context.packageManager
                    .getLaunchIntentForPackage(context.packageName)
                    ?.apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                        putExtra(EXTRA_WIDGET_ACTION, tapAction)
                        putExtra(EXTRA_TASK_ID, taskId)
                    }
                    ?.let { context.startActivity(it) }
            }
        }
    }
}