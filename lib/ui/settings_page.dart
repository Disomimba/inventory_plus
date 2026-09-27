import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../logic/inventory_controller.dart';
import 'profile_info_page.dart';

class SettingsPage extends StatefulWidget {
  final InventoryController controller;
  final String userName;
  final String userId;
  final String userRole;

  const SettingsPage({
    super.key,
    required this.controller,
    required this.userName,
    required this.userId,
    required this.userRole,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late String _currentUserName;

  @override
  void initState() {
    super.initState();
    _currentUserName = widget.userName;
  }

  Future<dynamic> _openResponsivePage(BuildContext context, Widget page) async {
    final isDesktop = MediaQuery.of(context).size.width >= 600;
    if (isDesktop) {
      return await showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(width: 800, height: 750, child: page),
        ),
      );
    } else {
      return await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => page),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: ListView(
        children: [

          
          if (widget.controller.isAdmin) ...[
            _buildSectionHeader("ORGANIZATION"),
            const SizedBox(height: 20),
          ],

          const SizedBox(height: 20),
          _buildSectionHeader("ACCOUNT"),
          _buildSettingTile(
            icon: LucideIcons.logOut,
            color: Colors.redAccent,
            title: "Logout",
            textColor: Colors.redAccent,
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Center(
              child: Text(
                "Version 1.0.4",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Color textColor = Colors.black87,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        subtitle: subtitle != null
            ? Text(subtitle, style: const TextStyle(fontSize: 12))
            : null,
        trailing: const Icon(
          LucideIcons.chevronRight,
          size: 16,
          color: Colors.grey,
        ),
      ),
    );
  }

  

  Widget _buildProfileHeader(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () async {
          final updatedName = await _openResponsivePage(
            context,
            ProfileInfoPage(
              controller: widget.controller,
              currentName: _currentUserName,
              currentEmail: widget.controller.loggedInUserEmail,
              userId: widget.userId,
              role: widget.userRole,
            ),
          );

          if (updatedName != null && updatedName is String && mounted) {
            setState(() {
              _currentUserName = updatedName;
            });
          }
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.orange.withOpacity(0.1),
                child: const Icon(
                  LucideIcons.user,
                  color: Colors.orange,
                  size: 30,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentUserName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      widget.userId,
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
