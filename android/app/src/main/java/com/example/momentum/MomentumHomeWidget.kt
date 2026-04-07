package com.example.momentum

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.graphics.*
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

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
        val widgetData = HomeWidgetPlugin.getData(context)
        val views = RemoteViews(context.packageName, R.layout.momentum_home_widget)

        val rawData = widgetData.getString("heatmap_data", "") ?: ""
        val heatmapData: List<Int> = if (rawData.isBlank()) {
            List(35) { 0 }
        } else {
            rawData.split(",").map { it.trim().toIntOrNull() ?: 0 }
        }

        // Check if we have any data at all
        val hasData = heatmapData.any { it > 0 }

        if (!hasData) {
            views.setTextViewText(R.id.widget_title, "No tasks tracked yet")
        } else {
            views.setTextViewText(R.id.widget_title, "Momentum")
        }

        // Draw the heatmap as a bitmap - this is the reliable approach for widgets
        val bitmap = drawHeatmapBitmap(heatmapData)
        views.setImageViewBitmap(R.id.widget_heatmap_image, bitmap)

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    private fun drawHeatmapBitmap(data: List<Int>): Bitmap {
        val cols = 7
        val rows = 5
        val cellSize = 36
        val cellPadding = 4
        val totalWidth = cols * (cellSize + cellPadding) + cellPadding
        val totalHeight = rows * (cellSize + cellPadding) + cellPadding

        val bitmap = Bitmap.createBitmap(totalWidth, totalHeight, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.drawColor(Color.TRANSPARENT)

        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        val cornerRadius = 6f

        for (i in 0 until minOf(data.size, cols * rows)) {
            val col = i % cols
            val row = i / cols

            val left = (cellPadding + col * (cellSize + cellPadding)).toFloat()
            val top = (cellPadding + row * (cellSize + cellPadding)).toFloat()
            val right = left + cellSize
            val bottom = top + cellSize

            paint.color = getHeatmapColor(data[i])
            canvas.drawRoundRect(left, top, right, bottom, cornerRadius, cornerRadius, paint)
        }

        return bitmap
    }

    private fun getHeatmapColor(intensity: Int): Int {
        return when {
            intensity <= 0 -> Color.parseColor("#FF424242")  // Empty - dark grey
            intensity == 1 -> Color.parseColor("#FF00897B")  // Level 1 - light teal
            intensity == 2 -> Color.parseColor("#FF00796B")  // Level 2
            intensity == 3 -> Color.parseColor("#FF00695C")  // Level 3
            intensity == 4 -> Color.parseColor("#FF00574D")  // Level 4
            else           -> Color.parseColor("#FF004D40")  // Level 5 - dark teal
        }
    }
}