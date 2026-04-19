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

    private data class Task(
        val id:          String,
        val name:        String,
        val isCompleted: Boolean,
        val teamName:    String,
    )

    private val tasks = mutableListOf<Task>()

    override fun onCreate()         { loadTasks() }
    override fun onDataSetChanged() { loadTasks() }
    override fun onDestroy()        { tasks.clear() }

    override fun getCount()              = tasks.size
    override fun getViewTypeCount()      = 1
    override fun hasStableIds()          = true
    override fun getItemId(pos: Int)     = pos.toLong()
    override fun getLoadingView(): RemoteViews? = null

    private fun loadTasks() {
        tasks.clear()
        runCatching {
            val (_, raw, _) = MomentumHomeWidget.readPrefs(ctx)
            if (raw.isBlank()) return
            val arr = JSONArray(raw)
            for (i in 0 until arr.length()) {
                val obj = arr.optJSONObject(i) ?: continue
                tasks += Task(
                    id          = obj.optString("id", i.toString()),
                    name        = obj.optString("name", "Task"),
                    isCompleted = obj.optBoolean("completed", false),
                    teamName    = obj.optString("team", ""),
                )
            }
            Log.d(TAG, "Loaded ${tasks.size} tasks")
        }.onFailure { Log.e(TAG, "loadTasks failed", it) }
    }

    override fun getViewAt(position: Int): RemoteViews {
        // Always return a valid view — any exception here kills the whole widget
        val views = RemoteViews(ctx.packageName, R.layout.widget_task_row)
        val task  = tasks.getOrNull(position) ?: return views.also {
            it.setTextViewText(R.id.task_name, "")
        }

        runCatching {
            views.setTextViewText(R.id.task_name, task.name)

            if (task.isCompleted) {
                views.setTextViewText(R.id.task_check, "✓")
                views.setInt(R.id.task_check, "setTextColor",
                    Color.parseColor("#4CAF50"))
                views.setInt(R.id.task_name, "setTextColor",
                    Color.parseColor("#88FFFFFF"))
            } else {
                views.setTextViewText(R.id.task_check, "○")
                views.setInt(R.id.task_check, "setTextColor",
                    Color.parseColor("#888888"))
                views.setInt(R.id.task_name, "setTextColor",
                    Color.WHITE)
            }

            if (task.teamName.isNotBlank()) {
                views.setViewVisibility(R.id.task_team, View.VISIBLE)
                views.setTextViewText(R.id.task_team, task.teamName)
            } else {
                views.setViewVisibility(R.id.task_team, View.GONE)
            }

            // Checkbox tap → complete/uncomplete in app
            views.setOnClickFillInIntent(R.id.task_check, Intent().apply {
                putExtra(MomentumHomeWidget.EXTRA_TASK_ID, task.id)
                putExtra("tap_action", "complete_task")
            })

            // Task name tap → open task in app
            views.setOnClickFillInIntent(R.id.task_name, Intent().apply {
                putExtra(MomentumHomeWidget.EXTRA_TASK_ID, task.id)
                putExtra("tap_action", "open_task")
            })

            // ⋮ options tap → open task edit screen in app
            // Long-press is NOT supported by Android RemoteViews;
            // this button is the standard workaround for edit/delete.
            views.setOnClickFillInIntent(R.id.task_options, Intent().apply {
                putExtra(MomentumHomeWidget.EXTRA_TASK_ID, task.id)
                putExtra("tap_action", "edit_task")
            })

        }.onFailure { Log.e(TAG, "getViewAt($position) failed", it) }

        return views
    }
}