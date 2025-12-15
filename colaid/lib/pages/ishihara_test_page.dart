import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import 'test_result_page.dart';

class IshiharaTestPage extends StatefulWidget {
  const IshiharaTestPage({super.key});

  @override
  State<IshiharaTestPage> createState() => _IshiharaTestPageState();
}

class _IshiharaTestPageState extends State<IshiharaTestPage> {
  final List<Map<String, dynamic>> platesData = [
    {'image': 'assets/Ishihara_01.png', 'answer': '12'},
    {'image': 'assets/Ishihara_02.jpg', 'answer': '74'},
    {'image': 'assets/Ishihara_03.jpg', 'answer': '6'},
    {'image': 'assets/Ishihara_04.jpg', 'answer': '16'},
    {'image': 'assets/Ishihara_05.jpg', 'answer': '2'},
    {'image': 'assets/Ishihara_06.jpg', 'answer': '29'},
    {'image': 'assets/Ishihara_07.jpg', 'answer': '7'},
    {'image': 'assets/Ishihara_08.jpg', 'answer': '45'},
    {'image': 'assets/Ishihara_09.jpg', 'answer': '5'},
    {'image': 'assets/Ishihara_10.jpg', 'answer': '97'},
    {'image': 'assets/Ishihara_11.jpg', 'answer': '8'},
    {'image': 'assets/Ishihara_12.jpg', 'answer': '42'},
    {'image': 'assets/Ishihara_13.jpg', 'answer': '3'},
    {'image': 'assets/ishihara_14.png', 'answer': '35'},
    {'image': 'assets/ishihara_15.png', 'answer': '96'},
    {'image': 'assets/ishihara_16.png', 'answer': '16'},
    {'image': 'assets/ishihara_17.png', 'answer': '57'},
  ];

  late List<Map<String, dynamic>> _selectedPlates;
  int _currentIndex = 0;
  final Map<int, String> _userAnswers = {};
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    platesData.shuffle();
    _selectedPlates = platesData.sublist(0, 12);
  }

  void _saveAnswer() {
    final input = _controller.text.trim();
    if (input.isEmpty) return;

    _userAnswers[_currentIndex] = input;
    _controller.clear();

    if (_currentIndex < _selectedPlates.length - 1) {
      setState(() => _currentIndex++);
    } else {
      _showResults();
    }
  }

  void _showResults() {
    int protan = 0, deutan = 0, tritan = 0;
    List<int> incorrectList = [];

    for (int i = 0; i < _selectedPlates.length; i++) {
      String correct = _selectedPlates[i]['answer'];
      String user = _userAnswers[i] ?? '';

      if (user != correct) {
        incorrectList.add(i + 1);

        int num = int.parse(correct);
        if (num % 3 == 0) protan++;
        else if (num % 3 == 1) deutan++;
        else tritan++;
      }
    }

    String type = "Normal Vision";
    CvdType cvdType = CvdType.none;

    if (protan > deutan && protan > tritan) {
      type = "Protanopia";
      cvdType = CvdType.protanopia;
    } else if (deutan > protan && deutan > tritan) {
      type = "Deuteranopia";
      cvdType = CvdType.deuteranopia;
    } else if (tritan > protan && tritan > deutan) {
      type = "Tritanopia";
      cvdType = CvdType.tritanopia;
    }

    // Update Global Settings
    Provider.of<ThemeProvider>(context, listen: false).setCvdType(cvdType);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => TestResultPage(
          plates: _selectedPlates,
          userAnswers: _userAnswers,
          detectedType: type,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plate = _selectedPlates[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text("Ishihara Test (${_currentIndex + 1}/12)"),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Image.asset(plate['image'], height: 250),
              const SizedBox(height: 25),

              TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: "Enter number",
                ),
              ),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: _saveAnswer,
                child: const Text("Next"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
