import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'home_screen.dart';
import 'student_test_screen.dart';
import 'teacher_test_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool isLogin = true;
  bool isTeacherMode = true;
  bool isScanning = false;

  void toggleFormType() {
    setState(() {
      isLogin = !isLogin;
    });
  }

  void toggleMode() {
    setState(() {
      isTeacherMode = !isTeacherMode;
      isScanning = false;
    });
  }

  void startScanning() {
    setState(() {
      isScanning = true;
    });
  }

  Future<void> _submit() async {
    try {
      if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email ve şifre alanları boş bırakılamaz'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (isLogin) {
        await _auth.signInWithEmailAndPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );
      } else {
        await _auth.createUserWithEmailAndPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // login_screen.dart içindeki _buildQRScanner() fonksiyonunu güncelleyelim:

  Widget _buildQRScanner() {
    return Stack(
      children: [
        MobileScanner(
          controller: MobileScannerController(),
          onDetect: (capture) {
            final List<Barcode> barcodes = capture.barcodes;
            if (barcodes.isNotEmpty && barcodes[0].rawValue != null) {
              final String qrData = barcodes[0].rawValue!;
              final List<String> parts = qrData.split(':');
              if (parts.length == 3) {
                // QR kod geçerliyse sadece öğrenci test ekranına yönlendir
                // Öğretmen test ekranına yönlendirme yapma
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StudentTestScreen(
                      classId: parts[0],
                      studentId: parts[1],
                      testId: parts[2],
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Geçersiz QR kod'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            color: Colors.black54,
            padding: const EdgeInsets.all(16),
            child: const Text(
              'QR kodu kamera görüş alanına getirin',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        Positioned(
          bottom: 16,
          left: 16,
          child: FloatingActionButton(
            onPressed: () {
              setState(() {
                isScanning = false;
              });
            },
            child: const Icon(Icons.arrow_back),
          ),
        ),
      ],
    );
  }

  Widget _buildTeacherForm() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            decoration: const InputDecoration(
              labelText: 'Şifre',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lock),
            ),
            obscureText: true,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _submit,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
            child: Text(isLogin ? 'Giriş Yap' : 'Kayıt Ol'),
          ),
          TextButton(
            onPressed: toggleFormType,
            child: Text(
              isLogin
                  ? 'Hesabın yok mu? Kayıt ol'
                  : 'Hesabın var mı? Giriş yap',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentView() {
    if (isScanning) {
      return _buildQRScanner();
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.qr_code_scanner,
              size: 100,
              color: Colors.grey,
            ),
            const SizedBox(height: 24),
            const Text(
              'Sınava başlamak için QR kodu okutun',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: startScanning,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('QR Kod Okut'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(200, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isTeacherMode ? 'Öğretmen Girişi' : 'Öğrenci Girişi'),
        actions: [
          TextButton.icon(
            onPressed: toggleMode,
            icon: Icon(
              isTeacherMode ? Icons.school : Icons.person,
              color: Colors.red,
            ),
            label: Text(
              isTeacherMode ? 'Öğrenci' : 'Öğretmen',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
      body: isTeacherMode ? _buildTeacherForm() : _buildStudentView(),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
