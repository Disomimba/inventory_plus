import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../logic/inventory_controller.dart';

class ProfileInfoPage extends StatefulWidget {
  final InventoryController controller;
  final String currentName;
  final String? currentEmail;
  final String userId;
  final String role;

  const ProfileInfoPage({
    super.key,
    required this.controller,
    required this.currentName,
    this.currentEmail,
    required this.userId,
    required this.role,
  });

  @override
  State<ProfileInfoPage> createState() => _ProfileInfoPageState();
}

class _ProfileInfoPageState extends State<ProfileInfoPage> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
late TextEditingController _locationController; 
  late TextEditingController _phoneController;
  bool _isLoading = false;
  bool _isFetching = true;

  // ADD STATE VARIABLE FOR EDIT MODE
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _emailController = TextEditingController(text: widget.currentEmail ?? "");
    _locationController = TextEditingController(); 
    _phoneController = TextEditingController();
    // Fetch latest data from database immediately on load
    _loadLatestDataFromDatabase();
  }

  Future<void> _loadLatestDataFromDatabase() async {
    try {
      // ADD 'location' and 'phone' to the select statement
      final data = await Supabase.instance.client
          .from('profiles')
          .select('email, name, address, phone')
          .eq('id', widget.userId)
          .maybeSingle();

      if (data != null && mounted) {
        setState(() {
  _emailController.text = data['email'] ?? "";
  _nameController.text = data['name'] ?? widget.currentName;
  _locationController.text = data['address'] ?? ""; // Use controller
  _phoneController.text = data['phone'] ?? "";       // Use controller
  _isFetching = false;
});
      } else if (mounted) {
        setState(() {
          _isFetching = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching latest profile data: $e");
      if (mounted) {
        setState(() {
          _isFetching = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _locationController.dispose(); // Dispose
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);

    try {
      final newName = _nameController.text.trim();
      final newEmail = _emailController.text.trim();
      
      // FIX: Use the controllers instead of the old variables
      final newAddress = _locationController.text.trim(); 
      final newPhone = _phoneController.text.trim();

      if (newName.isEmpty) {
        throw Exception("Name cannot be empty.");
      }

      await widget.controller.updateProfile(
        userId: widget.userId,
        name: newName,
        email: newEmail,
        location: newAddress, // Use new variable
        phone: newPhone,      // Use new variable
      );


      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Profile updated successfully!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, newName);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error updating profile: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showChangePasswordDialog(BuildContext context) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureText = true;
    bool isSaving = false;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (stateContext, setState) {
            return AlertDialog(
              title: const Text("Change Password"),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          errorMessage!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    TextField(
                      controller: currentPasswordController,
                      obscureText: obscureText,
                      decoration: const InputDecoration(
                        labelText: "Current Password",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: newPasswordController,
                      obscureText: obscureText,
                      decoration: const InputDecoration(
                        labelText: "New Password",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: obscureText,
                      decoration: InputDecoration(
                        labelText: "Confirm Password",
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureText ? LucideIcons.eye : LucideIcons.eyeOff,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setState(() {
                              obscureText = !obscureText;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (currentPasswordController.text.isEmpty ||
                              newPasswordController.text.isEmpty ||
                              confirmPasswordController.text.isEmpty) {
                            setState(
                              () => errorMessage = "Please fill in all fields.",
                            );
                            return;
                          }
                          if (newPasswordController.text.trim().length <= 6) {
                            setState(
                              () => errorMessage =
                                  "Password must be more than 6 characters.",
                            );
                            return;
                          }
                          if (newPasswordController.text !=
                              confirmPasswordController.text) {
                            setState(
                              () =>
                                  errorMessage = "New passwords do not match.",
                            );
                            return;
                          }

                          setState(() {
                            isSaving = true;
                            errorMessage = null;
                          });

                          final error = await widget.controller.changePassword(
                            currentPasswordController.text,
                            newPasswordController.text,
                          );

                          if (error != null) {
                            setState(() {
                              errorMessage = error;
                              isSaving = false;
                            });
                          } else {
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Password changed successfully!",
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ... inside _ProfileInfoPageState class ...

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Profile Info",
          style: TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (_isEditing) {
                _saveProfile();
              } else {
                setState(() => _isEditing = true);
              }
            },
            child: Text(
              _isEditing ? "Save" : "Edit",
              style: const TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: _isFetching
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.orange.withOpacity(0.1),
                      child: const Icon(
                        LucideIcons.user,
                        color: Colors.orange,
                        size: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  _buildField(
                    "Role",
                    widget.role.toUpperCase(),
                    null,
                    readOnly: true,
                  ),
                  _buildField(
                    "Full Name",
                    "",
                    _nameController,
                    icon: LucideIcons.user,
                  ),
                  _buildField(
                    "Email Address",
                    "",
                    _emailController,
                    icon: LucideIcons.mail,
                    type: TextInputType.emailAddress,
                  ),
                  _buildField(
                    "Location",
                    "",
                    null,
                    icon: LucideIcons.mapPin,
                  ),
                  _buildField(
                    "Phone Number",
                    "",
                    null,
                    icon: LucideIcons.phone,
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: () => _showChangePasswordDialog(context),
                      icon: const Icon(LucideIcons.lock, size: 18),
                      label: const Text("Change Password"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black87,
                        side: const BorderSide(color: Colors.black12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // Helper to build consistent fields
  Widget _buildField(
    String label,
    String? staticValue,
    TextEditingController? controller, {
    IconData? icon,
    bool readOnly = false,
    TextInputType type = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: readOnly || !_isEditing,
          keyboardType: type,
          decoration: InputDecoration(
            // SAFE NULL CHECK HERE
            hintText: (staticValue != null && staticValue.isNotEmpty)
                ? staticValue
                : "Enter $label",
            filled: true,
            fillColor: _isEditing && controller != null
                ? Colors.white
                : Colors.grey.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            prefixIcon: icon != null
                ? Icon(icon, size: 18, color: Colors.grey)
                : null,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
