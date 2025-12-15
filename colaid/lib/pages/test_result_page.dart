import 'package:flutter/material.dart';
import '../services/user_service.dart';
import 'camera_page.dart';
import 'results_history_page.dart';

class TestResultPage extends StatefulWidget {
  final List<Map<String, dynamic>> plates;
  final Map<int, String> userAnswers;
  final String detectedType;
  final bool isHistorical;

  const TestResultPage({
    super.key,
    required this.plates,
    required this.userAnswers,
    required this.detectedType,
    this.isHistorical = false,
  });

  @override
  State<TestResultPage> createState() => _TestResultPageState();
}

class _TestResultPageState extends State<TestResultPage> {
  int _incorrectCount = 0;

  @override
  void initState() {
    super.initState();
    _incorrectCount = _calculateIncorrect();
    if (!widget.isHistorical) {
      _saveResult();
    }
  }

  int _calculateIncorrect() {
    int count = 0;
    for (int i = 0; i < widget.plates.length; i++) {
      String correct = widget.plates[i]['answer'];
      String user = widget.userAnswers[i] ?? "";

      if (user.trim() != correct.trim()) {
        count++;
      }
    }
    return count;
  }

  Future<void> _saveResult() async {
    try {
      print("Saving test result: ${widget.plates.length} plates");
      await UserService().saveTestResult(
        widget.detectedType,
        _incorrectCount,
        widget.plates,
        widget.userAnswers,
      );
    } catch (e, stack) {
      print("Error saving test result: $e");
      print(stack);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Build table rows dynamically
    List<DataRow> tableRows = [];

    for (int i = 0; i < widget.plates.length; i++) {
      String correct = widget.plates[i]['answer'];
      String user = widget.userAnswers[i] ?? "";

      bool isWrong = correct.trim() != user.trim();

      tableRows.add(
        DataRow(
          cells: [
            DataCell(Text("Plate ${i + 1}")),
            DataCell(Text(correct)),
            DataCell(Text(user.isEmpty ? "No Answer" : user)),
            DataCell(
              Text(
                isWrong ? "❌ Wrong" : "✔️ Correct",
                style: TextStyle(
                  color: isWrong ? Colors.red : Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Test Results"),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (_) => const ResultsHistoryPage())
              );
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Detected Type
            const Text(
              "Detected Vision Type:",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              widget.detectedType,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.blue,
              ),
            ),

            const SizedBox(height: 22),

            // Table Title
            const Text(
              "Plate-by-Plate Summary:",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            // Results Table Horizontal Scroll
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                border: TableBorder.all(width: 1, color: Colors.grey),
                columns: const [
                  DataColumn(label: Text("Plate")),
                  DataColumn(label: Text("Correct")),
                  DataColumn(label: Text("Your Answer")),
                  DataColumn(label: Text("Status")),
                ],
                rows: tableRows,
              ),
            ),

            const SizedBox(height: 25),

            // Incorrect Count
            Text(
              "Total Incorrect Answers: $_incorrectCount",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _incorrectCount == 0 ? Colors.green : Colors.red,
              ),
            ),

            const SizedBox(height: 35),

            // Buttons Row
            Column(
              children: [
                if (!widget.isHistorical) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/camera');
                      },
                      child: const Text("Proceed to Camera Page", style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                         Navigator.push(
                          context, 
                          MaterialPageRoute(builder: (_) => const ResultsHistoryPage())
                        );
                      },
                      child: const Text("View Test History"),
                    ),
                  ),
                ] else ...[
                   SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Back to History"),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
