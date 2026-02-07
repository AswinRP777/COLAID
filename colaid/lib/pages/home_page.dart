import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/theme_provider.dart';
import 'results_history_page.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/user_service.dart';
import '../services/bluetooth_service.dart';
import 'package:location/location.dart' as loc;
import 'eyewear_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  bool _hasCheckedConnection = false;

  final List<Map<String, String>> _cards = [
    {
      'title': 'Ishihara Test',
      'subtitle': 'Check your color vision using standard plates',
    },
    {'title': 'Test Results', 'subtitle': 'View your previous assessments'},
    {'title': 'Real-Time Camera', 'subtitle': 'Real Time Camera Flip'},
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  void _onSignOutPressed() {
    Navigator.pushReplacementNamed(context, '/');
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      await UserService().setProfilePic(pickedFile.path);
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _showFullScreenImage(String imagePath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4,
              child: Image.file(File(imagePath)),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showEditProfileDialog() async {
    final TextEditingController nameController = TextEditingController(
      text: UserService().userName ?? "",
    );

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Edit Profile"),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: "Full Name",
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                final newName = nameController.text.trim();
                if (newName.isNotEmpty) {
                  await UserService().setUserData(
                    email: UserService().userEmail ?? "",
                    name: newName,
                  );
                  if (mounted) {
                    setState(() {});
                  }
                }
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasCheckedConnection) {
        _checkAndPromptEyewear();
        _hasCheckedConnection = true;
      }
    });
  }

  Future<void> _checkAndPromptEyewear() async {
    // Check if already connected
    if (ColaidBluetoothService().connectedDevice != null) return;

    // Show Premium Dialog
   if (!mounted) return;

final isDark = Theme.of(context).brightness == Brightness.dark;

showDialog(
  context: context,
  barrierDismissible: true,
  builder: (ctx) => AlertDialog(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    ),
    backgroundColor: isDark
        ? const Color(0xFF020617)
        : Colors.white,
    title: Row(
      children: [
        Icon(
          Icons.visibility,
          color: isDark
              ? Colors.white
              : Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 10),
        Text(
          "Connect Eyewear",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ],
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "Experience the full potential of Colaid. Connect your smart eyewear for real-time color correction and assistance.",
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.grey.shade300 : Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Icon(Icons.bluetooth, size: 20, color: Colors.grey),
            const SizedBox(width: 8),
            const Text("Bluetooth", style: TextStyle(color: Colors.grey)),
            const SizedBox(width: 16),
            const Icon(Icons.location_on, size: 20, color: Colors.grey),
            const SizedBox(width: 8),
            const Text("Location", style: TextStyle(color: Colors.grey)),
          ],
        ),
      ],
    ),
    actions: [
      // Later button
      TextButton(
        onPressed: () => Navigator.pop(ctx),
        child: Text(
          "Later",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
          ),
        ),
      ),

      // Connect Now button (LOGIN THEME)
      FilledButton.icon(
        onPressed: () {
          Navigator.pop(ctx);
          _handleConnectEyewear();
        },
        icon: Icon(
          Icons.link,
          color: isDark ? Colors.black : Colors.white,
        ),
        label: Text(
          "Connect Now",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.black : Colors.white,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor:
              isDark ? Colors.white : const Color(0xFF1E293B),
          foregroundColor:
              isDark ? Colors.black : Colors.white,
        ),
      ),
    ],
  ),
);
  }

  Future<void> _handleConnectEyewear() async {
    // 1. Turn on Bluetooth if off (Android only)
    if (Platform.isAndroid) {
      if (await FlutterBluePlus.adapterState.first ==
          BluetoothAdapterState.off) {
        try {
          await FlutterBluePlus.turnOn();
        } catch (e) {
          debugPrint("Could not turn on Bluetooth: $e");
        }
      }

      // Slight delay to ensure Bluetooth dialog/animation clears (if any)
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // 2. Check & Request Location Permission & Service
    //    We need permission 'WhenInUse' or 'Always' before we can request the service to be enabled.
    var locStatus = await Permission.location.status;
    if (!locStatus.isGranted) {
      locStatus = await Permission.location.request();
    }

    if (locStatus.isGranted) {
      // Permission granted, now check if GPS is actually on
      final location = loc.Location();
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          debugPrint("User denied enabling location service.");
          // We could return here, OR we could navigate anyway and let the scan fail/prompt again.
          // But strict compliance usually means we return.
          // However, user complained "it is not go to the connect eyewear page".
          // So let's navigate anyway to avoid getting stuck?
          // Actually, if service is disabled, scanning won't work.
          // Let's TRY to navigate so they verify status on the next page.
        }
      }
    } else {
      debugPrint("Location permission denied.");
      // If permission is denied, we can't scan.
      // But maybe navigate anyway to let them see the "Scan" button which might re-trigger?
    }

    // 3. Navigate
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const EyewearPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final userProfilePic = UserService().profilePicPath;

    Widget bodyForIndex() {
      switch (_selectedIndex) {
        case 0:
          return _buildDashboard(cs);
        case 1:
          return _buildIshiharaShortcut();
        case 2:
          return _buildProfile();
        default:
          return _buildDashboard(cs);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vision Test Home'),
  backgroundColor: Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF020617)
      : Colors.white,
  foregroundColor: Theme.of(context).brightness == Brightness.dark
      ? Colors.white
      : const Color(0xFF1E293B),
  elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Notifications',
            icon: Badge(
              label: Text('${UserService().getUnreadBadgeCount()}'),
              isLabelVisible: UserService().getUnreadBadgeCount() > 0,
              child: const Icon(Icons.notifications_none),
            ),
            onPressed: () {
              UserService().markNotificationsAsRead();
              setState(() {});

              showDialog(
                context: context,
                builder: (context) {
                  return StatefulBuilder(
                    builder: (context, setStateDialog) {
                      final notifications = UserService().getAllNotifications();
                      return AlertDialog(
                        title: const Text("Notifications"),
                        content: SizedBox(
                          width: double.maxFinite,
                          child: notifications.isEmpty
                              ? const Text("No notifications yet.")
                              : ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: notifications.length,
                                  itemBuilder: (context, index) {
                                    final n = notifications[index];
                                    return Dismissible(
                                      key: Key(
                                        "${n.timestamp.millisecondsSinceEpoch}_$index",
                                      ),
                                      background: Container(
                                        color: Colors.red,
                                        alignment: Alignment.centerRight,
                                        padding: const EdgeInsets.only(
                                          right: 20,
                                        ),
                                        child: const Icon(
                                          Icons.delete,
                                          color: Colors.white,
                                        ),
                                      ),
                                      direction: DismissDirection.endToStart,
                                      onDismissed: (direction) {
                                        UserService().removeNotification(index);
                                        setStateDialog(() {});
                                        setState(() {});
                                      },
                                      child: ListTile(
                                        leading: const Icon(Icons.info_outline),
                                        title: Text(n.message),
                                        subtitle: Text(
                                          n.timestamp
                                              .toLocal()
                                              .toString()
                                              .split('.')[0],
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("Close"),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: _onSignOutPressed,
          ),
        ],
      ),

      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
  colors: [
    Color(0xFF0F172A),
    Color(0xFF020617),
  ],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
),

                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 32,
                        backgroundColor: Colors.white,
                        backgroundImage: userProfilePic != null
                            ? FileImage(File(userProfilePic))
                            : null,
                        child: userProfilePic == null
                            ? const Icon(
                                Icons.person,
                                size: 40,
                                color: Colors.grey,
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      UserService().userName ?? 'Vision Test User',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      UserService().userEmail ?? 'user@example.com',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.visibility,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "CVD: ${themeProvider.cvdType.name.toUpperCase()}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              ListTile(
                leading: const Icon(Icons.home),
                title: const Text('Home'),
                onTap: () {
                  Navigator.pop(context);
                  _onItemTapped(0);
                },
              ),
              ListTile(
                leading: const Icon(Icons.visibility),
                title: const Text('Ishihara Test'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/ishihara');
                },
              ),
              ListTile(
                leading: const Icon(Icons.assessment),
                title: const Text('Results'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ResultsHistoryPage(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera),
                title: const Text('Real time Flip'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/camera');
                },
              ),
              ListTile(
                leading: const Icon(Icons.map_outlined),
                title: const Text('Color Legend'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/legend');
                },
              ),

              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Settings'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/settings');
                },
              ),
            ],
          ),
        ),
      ),

      body: SafeArea(child: bodyForIndex()),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.visibility_outlined),
            label: 'Test',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),

      floatingActionButton: _selectedIndex == 1
    ? FloatingActionButton.extended(
        backgroundColor:
            Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : const Color(0xFF1E293B),
        foregroundColor:
            Theme.of(context).brightness == Brightness.dark
                ? Colors.black
                : Colors.white,
        onPressed: () => Navigator.pushNamed(context, '/ishihara'),
        icon: const Icon(Icons.color_lens),
        label: const Text("Start Test"),
      )
    : null,

    );
  }

  // ---------------- Dashboard ----------------
  Widget _buildDashboard(ColorScheme cs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome ',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "Check your color vision with ease.",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),

          // ----- Feature Cards -----
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _cards.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 1,
              mainAxisExtent: 92,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemBuilder: (context, index) {
              final c = _cards[index];
              final icons = [Icons.visibility, Icons.assessment, Icons.camera];

              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFF020617)
    : Colors.white,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
  backgroundColor: Theme.of(context).brightness == Brightness.dark
      ? Colors.white.withOpacity(0.08)
      : cs.primary.withOpacity(0.12),
  child: Icon(
    icons[index],
    color: Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : const Color(0xFF1E293B),
  ),
),

                  title: Text(c['title'] ?? ''),
                  subtitle: Text(c['subtitle'] ?? ''),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    if (index == 0) {
                      Navigator.pushNamed(context, '/ishihara');
                    } else if (index == 1) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ResultsHistoryPage(),
                        ),
                      );
                    } else if (index == 2) {
                      Navigator.pushNamed(context, '/camera');
                    }
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 20),

          // ---- Get Started Button ----
          SizedBox(
            width: double.infinity,
            child: FilledButton(
  onPressed: () => Navigator.pushNamed(context, '/ishihara'),
  style: FilledButton.styleFrom(
    backgroundColor:
        Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : const Color(0xFF1E293B),
    foregroundColor:
        Theme.of(context).brightness == Brightness.dark
            ? Colors.black
            : Colors.white,
  ),
  child: const Padding(
    padding: EdgeInsets.symmetric(vertical: 14),
    child: Text("Get Started"),
  ),
),

          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildIshiharaShortcut() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.visibility, size: 90),
          SizedBox(height: 12),
          Text(
            "Start the Ishihara Color Blindness Test",
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProfile() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final cvdType = themeProvider.cvdType.name.toUpperCase();
    final userProfilePic = UserService().profilePicPath;
    

   final isDark = Theme.of(context).brightness == Brightness.dark;
final cs = Theme.of(context).colorScheme;

return Center(
  child: SingleChildScrollView(
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ================= PROFILE IMAGE =================
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? Colors.white : cs.primary,
                  width: 2,
                ),
              ),
              child: GestureDetector(
                onTap: () {
                  if (userProfilePic != null) {
                    _showFullScreenImage(userProfilePic);
                  }
                },
                child: CircleAvatar(
                  radius: 52,
                  backgroundColor:
                      isDark ? const Color(0xFF020617) : Colors.grey.shade200,
                  backgroundImage: userProfilePic != null
                      ? FileImage(File(userProfilePic))
                      : null,
                  child: userProfilePic == null
                      ? Icon(
                          Icons.person,
                          size: 56,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey,
                        )
                      : null,
                ),
              ),
            ),

            // Camera button
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white : cs.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.camera_alt,
                    size: 16,
                    color: isDark ? Colors.black : Colors.white,
                  ),
                ),
              ),
            ),

            // Delete button
            if (userProfilePic != null)
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () async {
                    await UserService().removeProfilePic();
                    if (mounted) setState(() {});
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.delete,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 16),

        // ================= USER INFO =================
        Text(
          UserService().userName ?? "Vision Test User",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),

        const SizedBox(height: 4),

        Text(
          UserService().userEmail ?? "user@example.com",
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
          ),
        ),

        const SizedBox(height: 12),

        // ================= CVD CHIP =================
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: cs.tertiaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            "CVD Type: $cvdType",
            style: TextStyle(
              color: cs.onTertiaryContainer,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),

        const SizedBox(height: 28),

        // ================= QUICK ACTIONS =================
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _ProfileQuickAction(
              icon: Icons.assessment,
              label: "Results",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ResultsHistoryPage(),
                  ),
                );
              },
            ),
            _ProfileQuickAction(
              icon: Icons.settings,
              label: "Settings",
              onTap: () {
                Navigator.pushNamed(context, '/settings');
              },
            ),
          ],
        ),

        const SizedBox(height: 28),

        // ================= EDIT PROFILE =================
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _showEditProfileDialog,
            icon: Icon(
              Icons.edit,
              color: isDark ? Colors.black : Colors.white,
            ),
            label: Text(
              "Edit Profile",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.black : Colors.white,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor:
                  isDark ? Colors.white : const Color(0xFF1E293B),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),

        const SizedBox(height: 24),
      ],
    ),
  ),
);

  }
  
}
class _ProfileQuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ProfileQuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? const Color(0xFF020617)
                  : Theme.of(context).colorScheme.primary.withOpacity(0.1),
            ),
            child: Icon(
              icon,
              size: 22,
              color: isDark
                  ? Colors.white
                  : Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

