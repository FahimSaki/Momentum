package com.example.momentum

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val action = intent.getStringExtra("widget_action") ?: return
        val taskId = intent.getStringExtra("task_id")

        when (action) {
            "add_task"      -> { /* navigate to task creation */ }
            "select_team"   -> { /* navigate to team selector */ }
            "complete_task" -> { /* complete the task with taskId */ }
            "open_task"     -> { /* open the task detail for taskId */ }
        }
    }
}
