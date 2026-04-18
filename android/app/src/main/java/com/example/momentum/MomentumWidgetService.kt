package com.example.momentum

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

// ── Service ────────────────────────────────────────────────────────────────

class MomentumWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        MomentumWidgetFactory(applicationContext, intent)
}

// ── Factory ────────────────────────────────────────────────────────────────

class MomentumWidgetFactory(
    private val context: Context,
    private val intent: Intent
) : RemoteViewsService.RemoteViewsFactory {

    private val TAG = "MomentumWidgetFactory"
    private val tasks = mutableListOf<JSONObject>()

    override fun onCreate() {
        Log.d(TAG, "Factory onCreate")
        loadTasks()
    }

    override fun onDataSetChanged() {
        Log.d(TAG, "onDataSetChanged — reloading tasks")
        loadTasks()
    }

    override fun onDestroy() {
        tasks.clear()
    }

    override fun getCount(): Int = tasks.size

    override fun getViewTypeCount(): Int = 1

    override fun hasStableIds(): Boolean = true

    override fun getItemId(position: Int): Long = position.toLong()

    override fun getLoadingView(): RemoteViews? = null

    // ── Load task data from SharedPreferences ──────────────────────────────

    private fun loadTasks() {
        tasks.clear()
        val (_, rawTasks, _) = MomentumHomeWidget.readPrefs(context)

        if (rawTasks.isBlank()) {
            Log.d(TAG, "No task data in SharedPreferences")
            return
        }

        try {
            val arr = JSONArray(rawTasks)
            for (i in 0 until arr.length()) {
                val obj = arr.optJSONObject(i) ?: continue
                tasks.add(obj)
            }
            Log.d(TAG, "Loaded ${tasks.size} tasks")
        } catch (e: Exception) {
            Log.w(TAG, "Failed to parse task JSON: ${e.message}")
        }
    }

    // ── Build view for each task row ───────────────────────────────────────

    override fun getViewAt(position: Int): RemoteViews {
        val fallback = RemoteViews(context.packageName, R.layout.widget_task_row)

        val task = tasks.getOrNull(position) ?: run {
            Log.w(TAG, "No task at position $position")
            return fallback
        }

        val views = RemoteViews(context.packageName, R.layout.widget_task_row)

        val taskId   = task.optString("id", position.toString())
        val taskName = task.optString("name", "").trim().ifEmpty { "Task" }
        val isDone   = task.optBoolean("completed", false)
        val teamName = task.optString("team", "")

        // ── Task name ──────────────────────────────────────────────────────
        views.setTextViewText(R.id.task_name, taskName)

        if (isDone) {
            // Strikethrough is not supported in RemoteViews, so we dim the text
            views.setTextColor(R.id.task_name, Color.parseColor("#66FFFFFF"))
        } else {
            views.setTextColor(R.id.task_name, Color.WHITE)
        }

        // ── Checkbox circle ────────────────────────────────────────────────
        if (isDone) {
            views.setTextViewText(R.id.task_check, "✓")
            views.setTextColor(R.id.task_check, Color.parseColor("#4CAF50"))
        } else {
            views.setTextViewText(R.id.task_check, "○")
            views.setTextColor(R.id.task_check, Color.parseColor("#888888"))
        }

        // ── Team label (shown only for team tasks) ─────────────────────────
        if (teamName.isNotBlank()) {
            views.setViewVisibility(R.id.task_team, View.VISIBLE)
            views.setTextViewText(R.id.task_team, teamName)
        } else {
            views.setViewVisibility(R.id.task_team, View.GONE)
        }

        // ── Click intents ──────────────────────────────────────────────────
        // These fill into the setPendingIntentTemplate set on the ListView.
        // Tapping the checkbox sends action="complete", tapping the name sends action="open".
        // Both open the app — the Flutter side reads widget_action and task_id from the intent.

        val checkFillIn = Intent().apply {
            putExtra(MomentumHomeWidget.EXTRA_TASK_ID, taskId)
            putExtra("tap_action", "complete_task")
        }
        views.setOnClickFillInIntent(R.id.task_check, checkFillIn)

        val nameFillIn = Intent().apply {
            putExtra(MomentumHomeWidget.EXTRA_TASK_ID, taskId)
            putExtra("tap_action", "open_task")
        }
        views.setOnClickFillInIntent(R.id.task_name, nameFillIn)

        return views
    }
}