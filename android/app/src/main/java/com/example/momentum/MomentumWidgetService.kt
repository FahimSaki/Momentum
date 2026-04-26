package com.example.momentum

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import android.util.Log
import org.json.JSONArray

class MomentumWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        MomentumWidgetFactory(applicationContext, intent)
}

class MomentumWidgetFactory(
    private val ctx: Context,
    private val intent: Intent,
) : RemoteViewsService.RemoteViewsFactory {

    private val TAG = "MomentumWidgetFactory"

    // Named WidgetTask to avoid any potential clash with generated model classes.
    private data class WidgetTask(
        val id:          String,
        val name:        String,
        val isCompleted: Boolean,
        val teamName:    String,
    )

    private val tasks = mutableListOf<WidgetTask>()

    override fun onCreate()         { loadTasks() }
    override fun onDataSetChanged() { loadTasks() }
    override fun onDestroy()        { tasks.clear() }

    override fun getCount()          = tasks.size
    override fun getViewTypeCount()  = 1
    override fun hasStableIds()      = true
    override fun getItemId(pos: Int) = pos.toLong()
    override fun getLoadingView(): RemoteViews? = null

    private fun loadTasks() {
        tasks.clear()
        try {
            val (_, raw, _) = MomentumHomeWidget.readPrefs(ctx)
            if (raw.isBlank()) return
            val arr = JSONArray(raw)
            for (i in 0 until arr.length()) {
                val obj = arr.optJSONObject(i) ?: continue
                tasks += WidgetTask(
                    id          = obj.optString("id", i.toString()),
                    name        = obj.optString("name", "Task"),
                    isCompleted = obj.optBoolean("completed", false),
                    teamName    = obj.optString("team", ""),
                )
            }
            Log.d(TAG, "Loaded ${tasks.size} tasks")
        } catch (e: Exception) {
            Log.e(TAG, "loadTasks failed: ${e.message}", e)
        }
    }

    override fun getViewAt(position: Int): RemoteViews {
        // Always return a valid RemoteViews — any exception here kills the widget.
        val views = RemoteViews(ctx.packageName, R.layout.widget_task_row)

        try {
            val task = tasks.getOrNull(position) ?: run {
                views.setTextViewText(R.id.task_name, "")
                return views
            }

            views.setTextViewText(R.id.task_name, task.name)

            if (task.isCompleted) {
                views.setTextViewText(R.id.task_check, "✓")
                views.setInt(R.id.task_check, "setTextColor", Color.parseColor("#4CAF50"))
                views.setInt(R.id.task_name,  "setTextColor", Color.parseColor("#88FFFFFF"))
            } else {
                views.setTextViewText(R.id.task_check, "○")
                views.setInt(R.id.task_check, "setTextColor", Color.parseColor("#888888"))
                views.setInt(R.id.task_name,  "setTextColor", Color.WHITE)
            }

            if (task.teamName.isNotBlank()) {
                views.setViewVisibility(R.id.task_team, View.VISIBLE)
                views.setTextViewText(R.id.task_team, task.teamName)
            } else {
                views.setViewVisibility(R.id.task_team, View.GONE)
            }

            // Checkbox tap → complete / uncomplete task in Flutter
            views.setOnClickFillInIntent(R.id.task_check, Intent().apply {
                putExtra(MomentumHomeWidget.EXTRA_TASK_ID, task.id)
                putExtra("tap_action", "complete_task")
            })

            // Task name tap → open task detail in Flutter
            views.setOnClickFillInIntent(R.id.task_name, Intent().apply {
                putExtra(MomentumHomeWidget.EXTRA_TASK_ID, task.id)
                putExtra("tap_action", "open_task")
            })

            // ⋮ options tap → edit / delete in Flutter
            // (Long-press is not supported by RemoteViews; this button is the workaround.)
            views.setOnClickFillInIntent(R.id.task_options, Intent().apply {
                putExtra(MomentumHomeWidget.EXTRA_TASK_ID, task.id)
                putExtra("tap_action", "edit_task")
            })

        } catch (e: Exception) {
            Log.e(TAG, "getViewAt($position) failed: ${e.message}", e)
        }

        return views
    }
}