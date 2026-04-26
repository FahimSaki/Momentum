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

        const val ACTION_REFRESH      = "com.example.momentum.WIDGET_REFRESH"
        const val ACTION_TASK_TAPPED  = "com.example.momentum.WIDGET_TASK_TAPPED"
        const val EXTRA_TASK_ID       = "task_id"
        const val EXTRA_WIDGET_ACTION = "widget_action"

        private fun immutableFlag() =
            PendingIntent.FLAG_UPDATE_CURRENT or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                    PendingIntent.FLAG_IMMUTABLE else 0

        private fun mutableFlag() =
            PendingIntent.FLAG_UPDATE_CURRENT or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
                    PendingIntent.FLAG_MUTABLE else 0

        /** Called from Flutter's WidgetService after data is written. */
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

                // Set up button click handlers — each wrapped individually so one
                // failure does not prevent the rest of the widget from rendering.
                try {
                    views.setOnClickPendingIntent(
                        R.id.widget_refresh,
                        makeRefreshIntent(context, widgetId)
                    )
                } catch (e: Exception) { Log.w(TAG, "refresh click: ${e.message}") }

                try {
                    views.setOnClickPendingIntent(
                        R.id.widget_add,
                        makeAppLaunchIntent(context, widgetId * 10 + 2, "add_task", null)
                    )
                } catch (e: Exception) { Log.w(TAG, "add click: ${e.message}") }

                try {
                    views.setOnClickPendingIntent(
                        R.id.widget_team_name,
                        makeAppLaunchIntent(context, widgetId * 10 + 3, "select_team", null)
                    )
                } catch (e: Exception) { Log.w(TAG, "team-name click: ${e.message}") }

                val count = parseTaskCount(rawTasks)

                if (count == 0) {
                    // ── Empty state ───────────────────────────────────────────
                    views.setViewVisibility(R.id.widget_task_list, View.GONE)
                    views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
                    try {
                        views.setOnClickPendingIntent(
                            R.id.widget_empty,
                            makeAppLaunchIntent(context, widgetId * 10 + 4, "add_task", null)
                        )
                    } catch (e: Exception) { Log.w(TAG, "empty click: ${e.message}") }
                } else {
                    // ── Task list ─────────────────────────────────────────────
                    // NOTE: Do NOT call setEmptyView() here — it conflicts with the
                    // manual visibility management above and is the primary cause of
                    // "an error occurred while loading widget" on many launchers.
                    views.setViewVisibility(R.id.widget_task_list, View.VISIBLE)
                    views.setViewVisibility(R.id.widget_empty, View.GONE)

                    try {
                        // Unique data URI per instance → separate RemoteViewsFactory.
                        val serviceIntent = Intent(context, MomentumWidgetService::class.java).apply {
                            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                            data = Uri.parse("content://momentum.tasks/$widgetId")
                        }
                        views.setRemoteAdapter(R.id.widget_task_list, serviceIntent)

                        // Template PendingIntent for row taps.
                        // fill-in intent from each row adds task_id + tap_action.
                        val tapTemplate = PendingIntent.getBroadcast(
                            context, widgetId * 10 + 5,
                            Intent(context, MomentumHomeWidget::class.java).also {
                                it.action = ACTION_TASK_TAPPED
                                it.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                            },
                            mutableFlag()  // MUST be mutable so fill-in extras work
                        )
                        views.setPendingIntentTemplate(R.id.widget_task_list, tapTemplate)
                    } catch (e: Exception) {
                        Log.w(TAG, "adapter setup failed, falling back to empty: ${e.message}")
                        views.setViewVisibility(R.id.widget_task_list, View.GONE)
                        views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
                    }
                }

                mgr.updateAppWidget(widgetId, views)

                if (count > 0) {
                    try {
                        mgr.notifyAppWidgetViewDataChanged(widgetId, R.id.widget_task_list)
                    } catch (e: Exception) { Log.w(TAG, "notifyDataChanged: ${e.message}") }
                }

            } catch (e: Exception) {
                Log.e(TAG, "Widget $widgetId update failed: ${e.message}", e)
                showSafeState(context, mgr, widgetId)
            }
        }

        // ── Private helpers ───────────────────────────────────────────────────

        /** Minimal safe render used as last-resort fallback. */
        private fun showSafeState(context: Context, mgr: AppWidgetManager, widgetId: Int) {
            runCatching {
                val v = RemoteViews(context.packageName, R.layout.momentum_home_widget)
                v.setTextViewText(R.id.widget_team_name, "Momentum")
                v.setViewVisibility(R.id.widget_task_list, View.GONE)
                v.setViewVisibility(R.id.widget_empty, View.VISIBLE)
                v.setTextViewText(R.id.widget_empty, "Open the app to sync tasks")
                try {
                    v.setOnClickPendingIntent(
                        R.id.widget_empty,
                        makeAppLaunchIntent(context, widgetId * 10 + 9, null, null)
                    )
                    v.setOnClickPendingIntent(
                        R.id.widget_team_name,
                        makeAppLaunchIntent(context, widgetId * 10 + 8, null, null)
                    )
                } catch (e: Exception) { Log.w(TAG, "safe-state clicks: ${e.message}") }
                mgr.updateAppWidget(widgetId, v)
            }.onFailure { Log.e(TAG, "Safe state also failed for $widgetId", it) }
        }

        private fun makeRefreshIntent(context: Context, widgetId: Int): PendingIntent =
            PendingIntent.getBroadcast(
                context, widgetId * 10 + 1,
                Intent(context, MomentumHomeWidget::class.java).also {
                    it.action = ACTION_REFRESH
                    it.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                },
                immutableFlag()
            )

        /**
         * Builds a PendingIntent that opens the app via the homeWidget:// URI scheme.
         * The home_widget Flutter plugin intercepts this URI and fires the
         * widgetClicked stream, so all widget actions are handled on the Flutter side.
         */
        private fun makeAppLaunchIntent(
            context: Context,
            requestCode: Int,
            action: String?,
            taskId: String?
        ): PendingIntent {
            val uriBuilder = Uri.Builder()
                .scheme("homeWidget")
                .authority("widget")
            action?.let { uriBuilder.appendQueryParameter("widget_action", it) }
            taskId?.let  { uriBuilder.appendQueryParameter("task_id", it) }

            val intent = Intent(Intent.ACTION_VIEW, uriBuilder.build()).apply {
                setPackage(context.packageName)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            return PendingIntent.getActivity(context, requestCode, intent, immutableFlag())
        }

        private fun parseTaskCount(raw: String): Int {
            if (raw.isBlank()) return 0
            return try { JSONArray(raw).length() } catch (_: JSONException) { 0 }
        }

        /** Tries all known SharedPreferences file names written by home_widget pkg. */
        fun readPrefs(context: Context): Triple<String, String, String> {
            val candidates = listOf(
                "${context.packageName}.home_widget",  // home_widget >= 0.4
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

                // Launch the app via homeWidget:// so the Flutter widgetClicked
                // stream fires with the correct parameters.
                val uri = Uri.Builder()
                    .scheme("homeWidget")
                    .authority("widget")
                    .appendQueryParameter("widget_action", tapAction)
                    .appendQueryParameter("task_id", taskId)
                    .build()

                val launchIntent = Intent(Intent.ACTION_VIEW, uri).apply {
                    setPackage(context.packageName)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                }
                try { context.startActivity(launchIntent) }
                catch (e: Exception) { Log.e(TAG, "Failed to launch from task tap: ${e.message}") }
            }
        }
    }
}