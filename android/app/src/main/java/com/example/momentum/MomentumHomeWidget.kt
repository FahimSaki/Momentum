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
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONException

class MomentumHomeWidget : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        val views = RemoteViews(context.packageName, R.layout.momentum_home_widget)

        // Open-app PendingIntent
        val launchIntent = context.packageManager
            .getLaunchIntentForPackage(context.packageName)
            ?.apply { flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP }

        val pendingLaunch = if (launchIntent != null) {
            PendingIntent.getActivity(
                context, 0, launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        } else null

        pendingLaunch?.let {
            views.setOnClickPendingIntent(R.id.widget_open_app, it)
            views.setOnClickPendingIntent(R.id.widget_title, it)
        }

        // Read saved data
        val widgetData = HomeWidgetPlugin.getData(context)
        val rawHeatmap = widgetData.getString("heatmap_data", "") ?: ""
        val rawTasks   = widgetData.getString("widget_tasks",  "") ?: ""

        // Parse heatmap
        val heatmapData: List<Int> = if (rawHeatmap.isBlank()) {
            List(35) { 0 }
        } else {
            rawHeatmap.split(",").mapNotNull { it.trim().toIntOrNull() }
                .takeIf { it.isNotEmpty() } ?: List(35) { 0 }
        }

        // Parse tasks
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
            } catch (_: JSONException) { }
        }

        val totalTasks   = taskNames.size
        val completedCnt = taskDone.count { it }

        // Summary
        val summaryText = when {
            totalTasks == 0            -> "No tasks — tap to add some"
            completedCnt == totalTasks -> "All $totalTasks done! 🎉"
            else                       -> "$completedCnt / $totalTasks completed"
        }
        views.setTextViewText(R.id.widget_task_summary, summaryText)

        // 3 task slots
        val rowIds   = intArrayOf(R.id.widget_task_row_1,   R.id.widget_task_row_2,   R.id.widget_task_row_3)
        val nameIds  = intArrayOf(R.id.widget_task_name_1,  R.id.widget_task_name_2,  R.id.widget_task_name_3)
        val checkIds = intArrayOf(R.id.widget_task_check_1, R.id.widget_task_check_2, R.id.widget_task_check_3)

        val sortedIdx = taskNames.indices.sortedBy { taskDone[it] }

        for (slot in 0..2) {
            if (slot < sortedIdx.size) {
                val idx  = sortedIdx[slot]
                val done = taskDone[idx]

                views.setViewVisibility(rowIds[slot], View.VISIBLE)
                views.setTextViewText(nameIds[slot],  taskNames[idx])
                views.setTextViewText(checkIds[slot], if (done) "✓" else "○")
                views.setTextColor(checkIds[slot],
                    if (done) Color.parseColor("#66FF99") else Color.parseColor("#888888"))
                views.setTextColor(nameIds[slot],
                    if (done) Color.parseColor("#80FFFFFF") else Color.parseColor("#FFFFFF"))

                pendingLaunch?.let { views.setOnClickPendingIntent(rowIds[slot], it) }
            } else {
                views.setViewVisibility(rowIds[slot], View.GONE)
            }
        }

        // Overflow
        val overflow = totalTasks - 3
        if (overflow > 0) {
            views.setViewVisibility(R.id.widget_more_tasks, View.VISIBLE)
            views.setTextViewText(R.id.widget_more_tasks, "+$overflow more — tap to open")
        } else {
            views.setViewVisibility(R.id.widget_more_tasks, View.GONE)
        }

        // Empty state
        views.setViewVisibility(R.id.widget_empty,
            if (totalTasks == 0) View.VISIBLE else View.GONE)

        // Heatmap strip
        views.setImageViewBitmap(R.id.widget_heatmap_image, drawHeatmapStrip(heatmapData))

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    private fun drawHeatmapStrip(data: List<Int>): Bitmap {
        val count  = minOf(data.size, 35)
        val cell   = 18
        val pad    = 3
        val bmp    = Bitmap.createBitmap(maxOf(count * (cell + pad), 1), maxOf(cell, 1), Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        canvas.drawColor(Color.TRANSPARENT)
        val paint  = Paint(Paint.ANTI_ALIAS_FLAG)
        for (i in 0 until count) {
            val l = (i * (cell + pad)).toFloat()
            paint.color = heatColor(data[i])
            canvas.drawRoundRect(l, 0f, l + cell, cell.toFloat(), 4f, 4f, paint)
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