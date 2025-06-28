import 'package:flutter/material.dart';
import 'package:habit_tracker/services/api/task_service.dart';
import 'package:habit_tracker/models/task.dart';

class TaskDatabase extends ChangeNotifier {
  final TaskService _taskService = TaskService();
  final List<Task> currentTasks = [];
  String? _token;

  void setToken(String token) {
    _token = token;
  }

  Future<void> fetchTasks() async {
    if (_token == null) return;
    final tasks = await _taskService.getTasks(_token!);
    currentTasks.clear();
    currentTasks.addAll(tasks.map((t) => Task.fromJson(t)));
    notifyListeners();
  }

  Future<void> addTask(Task task) async {
    if (_token == null) return;
    await _taskService.createTask(_token!, task.toJson());
    await fetchTasks();
  }

  Future<void> updateTask(String id, Map<String, dynamic> updates) async {
    if (_token == null) return;
    await _taskService.updateTask(_token!, id, updates);
    await fetchTasks();
  }

  Future<void> deleteTask(String id) async {
    if (_token == null) return;
    await _taskService.deleteTask(_token!, id);
    await fetchTasks();
  }

  Future<void> assignTask(String id, String assignedTo) async {
    if (_token == null) return;
    await _taskService.assignTask(_token!, id, assignedTo);
    await fetchTasks();
  }
}
