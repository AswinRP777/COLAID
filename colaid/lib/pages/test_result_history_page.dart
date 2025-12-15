// lib/pages/test_result_history_page.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class TestResultHistoryPage extends StatefulWidget {
  const TestResultHistoryPage({super.key});

  @override
  State<TestResultHistoryPage> createState() => _TestResultHistoryPageState();
}

class _TestResultHistoryPageState extends State<TestResultHistoryPage> {
  List<Map<String, dynamic>> history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();

    final List<String> savedList =
        prefs.getStringList("test_history") ?? [];

    List<Map<String, dynamic>> decoded = savedList
        .map((e) => jsonDecode(e) as Map<String, dynamic>)
        .toList();

    setState(() {
      history = decoded;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Previous Test Results")),

      body: history.isEmpty
          ? const Center(
              child: Text(
                "No previous results found",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: history.length,
              itemBuilder: (context, index) {
                final result = history[index];
                return Card(
                  elevation: 2,
                  child: ListTile(
                    title: Text(
                      "Result ${index + 1}: ${result["type"]}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      "Incorrect: ${result["incorrect"]}\nDate: ${result["date"]}",
                    ),
                  ),
                );
              },
            ),
    );
  }
}
