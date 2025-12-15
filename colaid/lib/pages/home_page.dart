import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/theme_provider.dart';
import 'results_history_page.dart';
import '../services/user_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

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
      setState(() {});
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
                  setState(() {});
                }
                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
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
                                          "${n.timestamp.toLocal().toString().split('.')[0]}",
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
                  gradient: LinearGradient(
                    colors: [cs.primary, cs.tertiary],
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
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.4),
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
              onPressed: () => Navigator.pushNamed(context, '/ishihara'),
              label: const Text("Start Test"),
              icon: const Icon(Icons.color_lens),
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
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: cs.primary.withOpacity(0.12),
                    child: Icon(icons[index], color: cs.primary),
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

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              // 1. Profile Picture - Tap to View
              GestureDetector(
                onTap: () {
                  if (userProfilePic != null) {
                    _showFullScreenImage(userProfilePic);
                  }
                },
                child: CircleAvatar(
                  radius: 46,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: userProfilePic != null
                      ? FileImage(File(userProfilePic))
                      : null,
                  child: userProfilePic == null
                      ? const Icon(Icons.person, size: 50, color: Colors.grey)
                      : null,
                ),
              ),

              // 2. Camera Icon - Tap to Pick
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),

              // 3. Trash Icon - Tap to Delete (Only if pic exists)
              if (userProfilePic != null)
                Positioned(
                  top: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () async {
                      await UserService().removeProfilePic();
                      setState(() {});
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.delete,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            UserService().userName ?? "Vision Test User",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(UserService().userEmail ?? "user@example.com"),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              "CVD Type: $cvdType",
              style: TextStyle(
                color: Theme.of(context).colorScheme.onTertiaryContainer,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showEditProfileDialog,
            icon: const Icon(Icons.edit),
            label: const Text("Edit Profile"),
          ),
        ],
      ),
    );
  }
}
