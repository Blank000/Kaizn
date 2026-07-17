package com.alokraj.habit_reward_tracker

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

/**
 * Renders today's timeline on the home screen.
 *
 * Data layout (written by `WidgetService` in Dart, read from
 * `HomeWidgetPlugin.getData(context)` which exposes the shared SharedPreferences):
 *   key: "timeline_today"
 *   value: JSON string:
 *     { "updatedAt": "...", "tasks": [ { id, name, startMin, duration, state, milestoneName, colorHex } ] }
 *
 * v1: static layout with up to 6 row slots. Excess tasks are summarised in the
 * footer ("+ N more"). Tap anywhere → opens the app.
 */
class TimelineWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val MAX_ROWS = 6
        private val ROW_IDS = intArrayOf(
            R.id.row_0, R.id.row_1, R.id.row_2,
            R.id.row_3, R.id.row_4, R.id.row_5
        )
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.timeline_widget)
            populate(context, views)

            val openIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java
            )
            views.setOnClickPendingIntent(R.id.widget_root, openIntent)

            appWidgetManager.updateAppWidget(id, views)
        }
    }

    private fun populate(context: Context, views: RemoteViews) {
        val prefs = HomeWidgetPlugin.getData(context)
        val payload = prefs.getString("timeline_today", null)

        // Header: "Today · Mon, May 14"
        val headerFmt = SimpleDateFormat("EEE, MMM d", Locale.getDefault())
        views.setTextViewText(
            R.id.header_text,
            "Today · " + headerFmt.format(Calendar.getInstance().time)
        )

        val tasks: JSONArray = try {
            if (payload != null) JSONObject(payload).getJSONArray("tasks")
            else JSONArray()
        } catch (e: Exception) {
            JSONArray()
        }

        if (tasks.length() == 0) {
            views.setViewVisibility(R.id.empty_state, View.VISIBLE)
            for (rowId in ROW_IDS) {
                views.setViewVisibility(rowId, View.GONE)
            }
            views.setViewVisibility(R.id.footer_text, View.GONE)
            return
        }

        views.setViewVisibility(R.id.empty_state, View.GONE)

        val total = tasks.length()
        val visible = minOf(total, MAX_ROWS)

        for (i in 0 until visible) {
            val rowId = ROW_IDS[i]
            val task = tasks.getJSONObject(i)
            views.setViewVisibility(rowId, View.VISIBLE)
            applyRow(views, rowId, task)
        }
        for (i in visible until MAX_ROWS) {
            views.setViewVisibility(ROW_IDS[i], View.GONE)
        }

        if (total > MAX_ROWS) {
            views.setViewVisibility(R.id.footer_text, View.VISIBLE)
            views.setTextViewText(
                R.id.footer_text,
                "+ ${total - MAX_ROWS} more"
            )
        } else {
            views.setViewVisibility(R.id.footer_text, View.GONE)
        }
    }

    private fun applyRow(views: RemoteViews, rowId: Int, task: JSONObject) {
        val name = task.optString("name", "")
        val state = task.optString("state", "unchecked")
        val startMin = if (task.isNull("startMin")) null else task.optInt("startMin")
        val colorHex = task.optString("colorHex", "#58CC02")

        // Find child IDs within the row. We use the same IDs in every row layout
        // (include layout reuses ids); RemoteViews resolves them per row via the
        // parent row id by setting nested updates.
        // Time label
        val timeText = if (startMin == null) "Anytime"
        else formatTime(startMin)

        // Build a sub-RemoteViews for the row by setting on the row ID directly.
        // RemoteViews supports setTextViewText with the *direct* child id within
        // the inflated widget tree, since each row uses unique top-level container
        // but shared sub-element ids would clash. We give each row a unique set
        // of child ids via `_N` suffixes in the layout XML.
        val suffix = ROW_IDS.indexOf(rowId)
        val accentId = context_id("accent_$suffix")
        val timeId = context_id("time_$suffix")
        val nameId = context_id("name_$suffix")
        val stateId = context_id("state_$suffix")

        if (accentId != 0) {
            views.setInt(accentId, "setBackgroundColor", safeParseColor(colorHex))
        }
        if (timeId != 0) views.setTextViewText(timeId, timeText)
        if (nameId != 0) views.setTextViewText(nameId, name)
        if (stateId != 0) {
            val stateText = when (state) {
                "checked" -> "✓"
                "missed" -> "✕"
                "skipped" -> "—"
                else -> "○"
            }
            views.setTextViewText(stateId, stateText)
        }
    }

    private fun context_id(name: String): Int {
        // Resolved via reflection so we can build child ids dynamically by index.
        // Layout uses ids like accent_0, time_0, name_0, state_0, ..., _5.
        return try {
            val clazz = R.id::class.java
            val field = clazz.getField(name)
            field.getInt(null)
        } catch (e: Exception) {
            0
        }
    }

    private fun safeParseColor(hex: String): Int {
        return try {
            Color.parseColor(hex)
        } catch (e: Exception) {
            Color.parseColor("#58CC02")
        }
    }

    private fun formatTime(min: Int): String {
        val h24 = (min / 60) % 24
        val m = min % 60
        val h12 = when {
            h24 == 0 -> 12
            h24 > 12 -> h24 - 12
            else -> h24
        }
        val ampm = if (h24 < 12) "AM" else "PM"
        return "%d:%02d %s".format(h12, m, ampm)
    }
}
