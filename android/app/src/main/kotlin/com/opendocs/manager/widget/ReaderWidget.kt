package com.opendocs.manager.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import com.opendocs.manager.MainActivity
import com.opendocs.manager.R

/**
 * 4-button quick-launch widget: Scan · QR · Recent · Files.
 * Each button opens the app and navigates to the matching screen via
 * the "widget_route" intent extra, which MainActivity forwards to Flutter.
 */
class ReaderWidget : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) {
            updateWidget(context, appWidgetManager, id)
        }
    }

    companion object {
        private const val ROUTE_SCAN   = "/ocr/camera"
        private const val ROUTE_QR     = "/tools/qr"
        private const val ROUTE_RECENT = "/"
        private const val ROUTE_FILES  = "/browser"

        fun updateWidget(
            context: Context,
            manager: AppWidgetManager,
            widgetId: Int,
        ) {
            val views = RemoteViews(context.packageName, R.layout.widget_reader)
            views.setOnClickPendingIntent(R.id.btn_scan,   pendingIntent(context, ROUTE_SCAN))
            views.setOnClickPendingIntent(R.id.btn_qr,     pendingIntent(context, ROUTE_QR))
            views.setOnClickPendingIntent(R.id.btn_recent, pendingIntent(context, ROUTE_RECENT))
            views.setOnClickPendingIntent(R.id.btn_files,  pendingIntent(context, ROUTE_FILES))
            manager.updateAppWidget(widgetId, views)
        }

        private fun pendingIntent(context: Context, route: String): PendingIntent {
            val intent = Intent(context, MainActivity::class.java).apply {
                action = "com.opendocs.WIDGET_NAV"
                putExtra("widget_route", route)
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            return PendingIntent.getActivity(
                context,
                route.hashCode(),
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, ReaderWidget::class.java)
            )
            for (id in ids) updateWidget(context, manager, id)
        }
    }
}
