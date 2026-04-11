package com.example.momentum

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONException

class MomentumHomeWidget : AppWidgetProvider() {

    companion object {
        private const val TAG = "MomentumHomeWidget"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            try {
                updateWidget(context, appWidgetManager, appWidgetId)
            } catch (e: Exception) {
                // Never let a crash here kill the widget — show a fallback view instead
                Log.e(TAG, "Widget update failed for id=$appWidgetId", e)
                showErrorState(context, appWidgetManager, appWidgetId)
            }
        }
    }

    // ── Fallback when something goes wrong ────────────────────────────────────

    private fun showErrorState(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        try {
            val views = RemoteViews(context.packageName, R.layout.momentum_home_widget)
            views.setTextViewText(R.id.widget_task_summary, "Tap to open Momentum")
            views.setViewVisibility(R.id.widget_task_row_1, View.GONE)
            views.setViewVisibility(R.id.widget_task_row_2, View.GONE)
            views.setViewVisibility(R.id.widget_task_row_3, View.GONE)
            views.setViewVisibility(R.id.widget_more_tasks, View.GONE)
            views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
            views.setTextViewText(R.id.widget_empty, "Open app to refresh")
            // Set a blank 1×1 heatmap so the ImageView never has a null src
            val blank = Bitmap.createBitmap(1, 1, Bitmap.Config.ARGB_8888)
            views.setImageViewBitmap(R.id.widget_heatmap_image, blank)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        } catch (e: Exception) {
            Log.e(TAG, "Even the fallback failed", e)
        }
    }

    // ── Main update ───────────────────────────────────────────────────────────

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        val views = RemoteViews(context.packageName, R.layout.momentum_home_widget)

        // ── Launch intent ─────────────────────────────────────────────────────
        val launchIntent = context.packageManager
            .getLaunchIntentForPackage(context.packageName)
            ?.apply { flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP }

        val pendingLaunch = launchIntent?.let {
            PendingIntent.getActivity(
                context, 0, it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }

        pendingLaunch?.let {
            views.setOnClickPendingIntent(R.id.widget_open_app, it)
            views.setOnClickPendingIntent(R.id.widget_title, it)
        }

        // ── Read saved data ───────────────────────────────────────────────────
        val widgetData  = HomeWidgetPlugin.getData(context)
        val rawHeatmap  = widgetData.getString("heatmap_data", "") ?: ""
        val rawTasks    = widgetData.getString("widget_tasks",  "") ?: ""

        // ── Parse heatmap ─────────────────────────────────────────────────────
        val heatmapData: List<Int> = rawHeatmap
            .takeIf { it.isNotBlank() }
            ?.split(",")
            ?.mapNotNull { it.trim().toIntOrNull() }
            ?.takeIf { it.isNotEmpty() }
            ?: List(35) { 0 }

        // ── Parse tasks ───────────────────────────────────────────────────────
        val taskNames = mutableListOf<String>()
        val taskDone  = mutableListOf<Boolean>()

        if (rawTasks.isNotBlank()) {
            try {
                val arr = JSONArray(rawTasks)
                for (i in 0 until arr.length()) {
                    val obj  = arr.optJSONObject(i) ?: continue
                    val name = obj.optString("name", "").trim()
                    val done = obj.optBoolean("completed", false)
                    if (name.isNotEmpty()) {
                        taskNames.add(name)
                        taskDone.add(done)
                    }
                }
            } catch (e: JSONException) {
                // Bad JSON from Flutter — just show an empty list
                Log.w(TAG, "Failed to parse task JSON: ${e.message}")
            }
        }

        val totalTasks   = taskNames.size
        val completedCnt = taskDone.count { it }

        // ── Summary line ──────────────────────────────────────────────────────
        val summaryText = when {
            totalTasks == 0            -> "No tasks — tap to add some"
            completedCnt == totalTasks -> "All $totalTasks done! 🎉"
            else                       -> "$completedCnt / $totalTasks completed"
        }
        views.setTextViewText(R.id.widget_task_summary, summaryText)

        // ── 3 task slots ──────────────────────────────────────────────────────
        val rowIds   = intArrayOf(R.id.widget_task_row_1,   R.id.widget_task_row_2,   R.id.widget_task_row_3)
        val nameIds  = intArrayOf(R.id.widget_task_name_1,  R.id.widget_task_name_2,  R.id.widget_task_name_3)
        val checkIds = intArrayOf(R.id.widget_task_check_1, R.id.widget_task_check_2, R.id.widget_task_check_3)

        // Show active tasks first, then completed
        val sortedIdx = taskNames.indices.sortedBy { taskDone[it] }

        for (slot in 0..2) {
            if (slot < sortedIdx.size) {
                val idx  = sortedIdx[slot]
                val done = taskDone[idx]

                views.setViewVisibility(rowIds[slot], View.VISIBLE)
                views.setTextViewText(nameIds[slot],  taskNames[idx])
                views.setTextViewText(checkIds[slot], if (done) "✓" else "○")
                views.setTextColor(
                    checkIds[slot],
                    if (done) Color.parseColor("#66FF99") else Color.parseColor("#888888")
                )
                views.setTextColor(
                    nameIds[slot],
                    if (done) Color.parseColor("#80FFFFFF") else Color.WHITE
                )

                pendingLaunch?.let { views.setOnClickPendingIntent(rowIds[slot], it) }
            } else {
                views.setViewVisibility(rowIds[slot], View.GONE)
            }
        }

        // ── Overflow label ────────────────────────────────────────────────────
        val overflow = totalTasks - 3
        if (overflow > 0) {
            views.setViewVisibility(R.id.widget_more_tasks, View.VISIBLE)
            views.setTextViewText(R.id.widget_more_tasks, "+$overflow more — tap to open")
        } else {
            views.setViewVisibility(R.id.widget_more_tasks, View.GONE)
        }

        // ── Empty state ───────────────────────────────────────────────────────
        views.setViewVisibility(
            R.id.widget_empty,
            if (totalTasks == 0) View.VISIBLE else View.GONE
        )

        // ── Heatmap ───────────────────────────────────────────────────────────
        // drawHeatmapStrip always returns a non-null bitmap, never throws
        views.setImageViewBitmap(R.id.widget_heatmap_image, drawHeatmapStrip(heatmapData))

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    // ── Heatmap rendering ─────────────────────────────────────────────────────

    private fun drawHeatmapStrip(data: List<Int>): Bitmap {
        val count = data.size.coerceAtMost(35).coerceAtLeast(1)
        val cell  = 18
        val gap   = 3
        val w     = count * (cell + gap) - gap   // no trailing gap
        val bmp   = Bitmap.createBitmap(w.coerceAtLeast(1), cell, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        canvas.drawColor(Color.TRANSPARENT)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)

        for (i in 0 until count) {
            val left = (i * (cell + gap)).toFloat()
            paint.color = heatColor(data[i])
            canvas.drawRoundRect(left, 0f, left + cell, cell.toFloat(), 4f, 4f, paint)
        }
        return bmp
    }

    private fun heatColor(v: Int): Int = when {
        v <= 0 -> Color.parseColor("#44FFFFFF")
        v == 1 -> Color.parseColor("#FF00897B")
        v == 2 -> Color.parseColor("#FF00796B")
        v == 3 -> Color.parseColor("#FF00695C")
        v == 4 -> Color.parseColor("#FF00574D")
        else   -> Color.parseColor("#FF004D40")
    }
}