import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class LegendPage extends StatefulWidget {
  const LegendPage({super.key});

  @override
  State<LegendPage> createState() => _LegendPageState();
}

class _LegendPageState extends State<LegendPage> {
  final List<Map<String, dynamic>> _colorAssets = const [
    {"name": "Red", "color": Colors.red},
    {"name": "Green", "color": Colors.green},
    {"name": "Orange", "color": Colors.orange},
    {"name": "Brown", "color": Colors.brown},
    {"name": "Pink", "color": Colors.pink},
    {"name": "Purple", "color": Colors.purple},
    {"name": "Blue", "color": Colors.blue},
    {"name": "Yellow", "color": Colors.yellow},
  ];



  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("Color Legend", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Color Transformation Map",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "See how colors are adjusted to improve your visual experience based on your setting: ${themeProvider.cvdType.name.toUpperCase()}",
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    
                    // Color List
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _colorAssets.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = _colorAssets[index];
                        final color = item['color'] as Color;
                        
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              // Color Name
                              SizedBox(
                                width: 60,
                                child: Text(
                                  item['name'],
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              
                              const Spacer(),
                              
                              // Original Color
                              _buildColorSwatch(color),
                              
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Icon(Icons.arrow_right_alt, color: Colors.grey),
                              ),
                              
                              // Corrected Color (Filtered)
                              ColorFiltered(
                                colorFilter: ColorFilter.matrix(themeProvider.currentCvdFilter),
                                child: _buildColorSwatch(color),
                              ),
                              
                              const Spacer(),
                              
                              // Description text
                               Text(
                                  "${item['name']} → ${_getTransformedColorName(item['name'], themeProvider.cvdType)}",
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Legend Footer
              Container(
                 padding: const EdgeInsets.all(16),
                 decoration: BoxDecoration(
                   border: Border.all(color: Colors.grey.withOpacity(0.3)),
                   borderRadius: BorderRadius.circular(12),
                 ),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     const Text("Legend", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                     const SizedBox(height: 16),
                     Row(
                       children: [
                         _buildColorSwatch(Colors.grey),
                         const SizedBox(width: 8),
                         const Text("Original Color"),
                         const SizedBox(width: 24),
                         Container(
                           width: 20, 
                           height: 20, 
                           decoration: BoxDecoration(
                             color: Colors.blue, 
                             borderRadius: BorderRadius.circular(4)
                           )
                         ),
                         const SizedBox(width: 8),
                         const Text("Corrected Color"),
                       ],
                     )
                   ],
                 ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  String _getTransformedColorName(String original, CvdType type) {
    if (type == CvdType.none) return original;

    final map = _cvdColorMaps[type];
    return map?[original] ?? "Changed";
  }

  static const Map<CvdType, Map<String, String>> _cvdColorMaps = {
    CvdType.protanopia: {
      "Red": "Dark Yellow",
      "Green": "Yellow",
      "Orange": "Yellow",
      "Brown": "Dark Green",
      "Pink": "Blue/Grey",
      "Purple": "Blue",
      "Blue": "Blue", // Similar
      "Yellow": "Yellow",
    },
    CvdType.deuteranopia: {
      "Red": "Dark Yellow",
      "Green": "Beige",
      "Orange": "Yellow",
      "Brown": "Dark Green",
      "Pink": "Grey/Blue",
      "Purple": "Blue",
      "Blue": "Blue",
      "Yellow": "Yellow",
    },
    CvdType.tritanopia: {
      "Red": "Red",
      "Green": "Cyan",
      "Orange": "Red",
      "Brown": "Magenta",
      "Pink": "Red",
      "Purple": "Dark Red",
      "Blue": "Cyan/Grey",
      "Yellow": "Pink",
    }
  };

  Widget _buildColorSwatch(Color color) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 2,
            offset: const Offset(0, 1),
          )
        ]
      ),
    );
  }
}
