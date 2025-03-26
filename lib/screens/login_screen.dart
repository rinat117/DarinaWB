import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'pickup_selection_screen.dart';
import 'dashboard_screen.dart'; // Экран клиента
import 'employee_dashboard_screen.dart'; // Экран сотрудника

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _verificationId;
  bool _isCodeSent = false;
  bool _isEmailLogin = false;

  Future<void> _signInWithPhoneNumber() async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: _phoneController.text,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _auth.signInWithCredential(credential);
          _navigateBasedOnRole();
        },
        verificationFailed: (FirebaseAuthException e) {
          print("Verification failed: ${e.message}");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Ошибка: ${e.message}")),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _isCodeSent = true;
          });
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      print("Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Ошибка: $e")),
      );
    }
  }

  Future<void> _verifyCode() async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _codeController.text,
      );
      await _auth.signInWithCredential(credential);
      _navigateBasedOnRole();
    } catch (e) {
      print("Error verifying code: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Ошибка верификации: $e")),
      );
    }
  }

  Future<void> _signInWithEmail() async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      _navigateBasedOnRole();
    } catch (e) {
      print("Error signing in with email: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Ошибка входа: $e")),
      );
    }
  }

  Future<void> _navigateBasedOnRole() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final databaseReference = FirebaseDatabase.instance.ref();
    String? role;
    String? pickupPointId;

    // Проверяем, вошёл ли пользователь через email
    if (user.email != null) {
      // Заменяем недопустимые символы в email для использования в качестве ключа
      final emailKey = user.email!.replaceAll('@', '_').replaceAll('.', '_');
      final employeeSnapshot =
          await databaseReference.child('users/employees/$emailKey').get();
      if (employeeSnapshot.exists) {
        final employeeData = employeeSnapshot.value as Map<dynamic, dynamic>;
        role = employeeData['role'] as String?;
        pickupPointId = employeeData['pickup_point_id'] as String?;
      }
    } else {
      // Вошёл через номер телефона
      final phoneNumber = user.phoneNumber?.replaceAll('+', '') ?? '';
      final customerSnapshot =
          await databaseReference.child('users/customers/$phoneNumber').get();
      if (customerSnapshot.exists) {
        final customerData = customerSnapshot.value as Map<dynamic, dynamic>;
        role = customerData['role'] as String?;
      }
    }

    if (role == 'customer') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const PickupSelectionScreen()),
      );
    } else if (role == 'employee' && pickupPointId != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => EmployeeDashboardScreen(
            pickupPointId:
                pickupPointId!, // Добавляем !, так как уверены, что pickupPointId не null
            user: user,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Роль пользователя не определена")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Вход'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text('Вход по номеру'),
                  selected: !_isEmailLogin,
                  onSelected: (selected) {
                    setState(() {
                      _isEmailLogin = !selected;
                    });
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Вход по email'),
                  selected: _isEmailLogin,
                  onSelected: (selected) {
                    setState(() {
                      _isEmailLogin = selected;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isEmailLogin) ...[
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Пароль',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _signInWithEmail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                ),
                child: const Text('Войти'),
              ),
            ] else ...[
              if (!_isCodeSent) ...[
                TextField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Номер телефона (+7...)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _signInWithPhoneNumber,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                  ),
                  child: const Text('Отправить код'),
                ),
              ] else ...[
                TextField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    labelText: 'Код из SMS',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _verifyCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                  ),
                  child: const Text('Подтвердить'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
