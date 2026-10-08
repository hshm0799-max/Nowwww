import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController(text: '+91');
  final _otpController = TextEditingController();
  final _nameController = TextEditingController();
  final _areaController = TextEditingController();
  final _workController = TextEditingController();

  String _verificationId = '';
  bool _isOtpSent = false;
  bool _loading = false;

  void _msg(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _sendOTP() async {
    if (_nameController.text.trim().isEmpty ||
        _areaController.text.trim().isEmpty ||
        _workController.text.trim().isEmpty) {
      _msg('Name, Area aur Work bharna zaroori hai');
      return;
    }
    setState(() => _loading = true);
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: _phoneController.text.trim(),
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Auto-verification (Android)
        await _signIn(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() => _loading = false);
        _msg('Verification failed: ${e.message}');
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _verificationId = verificationId;
          _isOtpSent = true;
          _loading = false;
        });
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  Future<void> _verifyOTP() async {
    setState(() => _loading = true);
    final credential = PhoneAuthProvider.credential(
      verificationId: _verificationId,
      smsCode: _otpController.text.trim(),
    );
    await _signIn(credential);
  }

  Future<void> _signIn(PhoneAuthCredential credential) async {
    try {
      final cred = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = cred.user;
      if (user == null) return;

      final ref = FirebaseFirestore.instance.collection('staff').doc(user.uid);
      final doc = await ref.get();
      if (!doc.exists) {
        await ref.set({
          'uid': user.uid,
          'phoneNumber': _phoneController.text.trim(),
          'name': _nameController.text.trim(),
          'area': _areaController.text.trim(),
          'work': _workController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen(uid: user.uid)),
      );
    } on FirebaseAuthException catch (e) {
      _msg('Login failed: ${e.message}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _nameController.dispose();
    _areaController.dispose();
    _workController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HR Digital - Login')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (!_isOtpSent) ...[
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Mobile Number (+91...)'),
              ),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Staff Full Name'),
              ),
              TextField(
                controller: _areaController,
                decoration: const InputDecoration(labelText: 'Area / Location'),
              ),
              TextField(
                controller: _workController,
                decoration: const InputDecoration(labelText: 'Work / Role'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _sendOTP,
                child: Text(_loading ? 'Please wait...' : 'Send OTP'),
              ),
            ] else ...[
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(labelText: 'Enter 6-Digit OTP'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _verifyOTP,
                child: Text(_loading ? 'Please wait...' : 'Verify & Login'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
