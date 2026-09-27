import 'package:flutter/material.dart';
import 'dart:math';
import '../login/auth_service.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});
  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _authService = AuthService();
  int _step = 0; 
  String? _email;
  String? _generatedOtp; // ADDED THIS
  final _controller = TextEditingController();

  Future<void> _nextStep() async {
    try {
      if (_step == 0) { // Step 0: Request OTP
        final email = await _authService.getEmailFromUsername(_controller.text);
        if (email == null) throw "Username not found.";
        
        String otp = (100000 + Random().nextInt(900000)).toString();
        await _authService.sendEmailJsOtp(email, otp);
        
        setState(() { 
          _email = email; 
          _generatedOtp = otp; 
          _step = 1; 
          _controller.clear(); 
        });
      } 
      else if (_step == 1) { // Step 1: Verify OTP
        if (_controller.text == _generatedOtp) {
          setState(() { _step = 2; _controller.clear(); });
        } else {
          throw "Invalid OTP";
        }
      } 
      else if (_step == 2) { // Step 2: Reset Password
        await _authService.resetPasswordForUser(_email!, _controller.text);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password updated successfully!")));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final labels = ["Enter Username", "Enter 6-digit OTP", "Enter New Password"];
    return Scaffold(
      appBar: AppBar(title: const Text("Reset Password")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _controller, 
              decoration: InputDecoration(labelText: labels[_step]),
              keyboardType: _step == 1 ? TextInputType.number : TextInputType.text,
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _nextStep, child: const Text("Continue")),
          ],
        ),
      ),
    );
  }
}