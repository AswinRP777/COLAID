import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/user_service.dart';
import 'test_result_page.dart';

class ResultsHistoryPage extends StatefulWidget {
  const ResultsHistoryPage({super.key});

  @override
  State<ResultsHistoryPage> createState() => _ResultsHistoryPageState();
}

class _ResultsHistoryPageState extends State<ResultsHistoryPage> {
  final Set<String> _selectedDates = {};
  bool _isSelectionMode = false;

  void _toggleSelection(String date) {
    setState(() {
      if (_selectedDates.contains(date)) {
        _selectedDates.remove(date);
        if (_selectedDates.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedDates.add(date);
      }
    });
  }

  Future<void> _deleteSelected() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Results"),
        content: Text(
          "Are you sure you want to delete ${_selectedDates.length} result(s)?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      await UserService().deleteTestResults(_selectedDates);
      setState(() {
        _selectedDates.clear();
        _isSelectionMode = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = UserService()
        .getTestResults(); // This might need setState to refresh if not reactive

    return Scaffold(
      appBar: AppBar(
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _isSelectionMode = false;
                  _selectedDates.clear();
                }),
              )
            : null,
        title: Text(
          _isSelectionMode
              ? "${_selectedDates.length} Selected"
              : "Test History",
        ),
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteSelected,
            ),
        ],
      ),
      body: results.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    "No test history found",
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: results.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final result = results[index];
                final date =
                    DateTime.tryParse(result['date']) ?? DateTime.now();
                final type = result['type'];
                final incorrect = result['incorrect'];

                // Retrieve detailed data if available
                List<Map<String, dynamic>>? plates;
                Map<int, String>? userAnswers;

                try {
                  if (result['plates'] != null) {
                    // Robust parsing: converting List<dynamic> to List<Map<String, dynamic>>
                    plates = (result['plates'] as List)
                        .map((e) => Map<String, dynamic>.from(e as Map))
                        .toList();
                  }

                  if (result['userAnswers'] != null) {
                    final Map<dynamic, dynamic> rawAnswers =
                        result['userAnswers'] as Map;
                    userAnswers = rawAnswers.map(
                      (k, v) => MapEntry(int.parse(k.toString()), v.toString()),
                    );
                  }
                } catch (e) {
                  debugPrint("Error parsing history item: $e");
                  // Keep them null if parsing fails
                }

                final dateStr = DateFormat.yMMMd().add_jm().format(date);
                final platesCount = plates?.length ?? 0;
                final dateKey = result['date'];
                final isSelected = _selectedDates.contains(dateKey);

                return Card(
                  elevation: 2,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: _isSelectionMode
                        ? Checkbox(
                            value: isSelected,
                            onChanged: (val) => _toggleSelection(dateKey),
                          )
                        : CircleAvatar(
                            backgroundColor: type == "Normal Vision"
                                ? Colors.green.shade100
                                : Colors.orange.shade100,
                            child: Icon(
                              type == "Normal Vision"
                                  ? Icons.check
                                  : Icons.warning_amber,
                              color: type == "Normal Vision"
                                  ? Colors.green
                                  : Colors.deepOrange,
                            ),
                          ),
                    title: Text(
                      type,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(dateStr),
                        const SizedBox(height: 4),
                        Text(
                          "Incorrect Answers: $incorrect",
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        if (platesCount > 0)
                          Text(
                            "Details available ($platesCount plates)",
                            style: const TextStyle(
                              color: Colors.blue,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    onLongPress: () {
                      setState(() {
                        _isSelectionMode = true;
                        _toggleSelection(dateKey);
                      });
                    },
                    onTap: _isSelectionMode
                        ? () => _toggleSelection(dateKey)
                        : (plates != null &&
                              userAnswers != null &&
                              plates.isNotEmpty)
                        ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TestResultPage(
                                  plates: plates!,
                                  userAnswers: userAnswers!,
                                  detectedType: type,
                                  isHistorical: true,
                                ),
                              ),
                            );
                          }
                        : (() {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Detailed results not available for this entry.",
                                ),
                              ),
                            );
                          }),
                  ),
                );
              },
            ),
    );
  }
}
