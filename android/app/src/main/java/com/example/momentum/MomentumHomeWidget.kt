package com.example.momentum

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class MomentumHomeWidget : AppWidgetProvider() {
    override fun onUpdate(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            val widgetData = HomeWidgetPlugin.getData(context)
            val views = RemoteViews(context.packageName, R.layout.momentum_home_widget)

            // val heatmapData = widgetData.getString("heatmap_data", "")?.split(",") ?: listOf()

            val rawData = widgetData.getString("heatmap_data", "") ?: ""
            val heatmapData = if (rawData.isBlank()) listOf() else rawData.split(",")

            if (heatmapData.isEmpty()) {
                views.setTextViewText(R.id.widget_title, context.getString(R.string.empty_widget_text))
            } else {
                views.setTextViewText(R.id.widget_title, context.getString(R.string.widget_title))

                for (i in 0 until 35) {
                    val intensity = heatmapData.getOrNull(i)?.toIntOrNull() ?: 0
                    val colorRes =
                            when (intensity) {
                                0 -> R.color.heatmap_empty
                                1 -> R.color.heatmap_level1
                                2 -> R.color.heatmap_level2
                                3 -> R.color.heatmap_level3
                                4 -> R.color.heatmap_level4
                                else -> R.color.heatmap_level5
                            }
                            val cell = RemoteViews(context.packageName, R.layout.heatmap_cell)
                            cell.setInt(R.id.heatmap_cell_bg, "setBackgroundResource", colorRes)
                            views.addView(R.id.widget_grid, cell)
                }
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    override fun onEnabled(context: Context) {
        // Widget first created
    }

    override fun onDisabled(context: Context) {
        // Last widget instance removed
    }
}
