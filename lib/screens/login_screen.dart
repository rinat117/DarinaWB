import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'employee_home_screen.dart';
import 'pickup_selection_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _inputController = TextEditingController();
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();
  String? _verificationId; // Для хранения ID верификации телефона
  bool _isLoading = false;
  bool _showPasswordField = false; // Показывать поле пароля для сотрудников
  bool _showCodeField = false; // Показывать поле кода для клиентов
  String _inputType = ''; // 'email' или 'phone'

  @override
  void dispose() {
    _inputController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  // Проверка ввода: email или телефон
  void _checkInput(String value) {
    setState(() {
      _showPasswordField = false;
      _showCodeField = false;
      _inputType = '';

      if (value.endsWith('@wbpvz.com')) {
        _inputType = 'email';
        _showPasswordField = true;
      } else if (RegExp(r'^\+?\d{10,15}$').hasMatch(value) ||
          RegExp(r'^\d{10,15}$').hasMatch(value)) {
        _inputType = 'phone';
        _showCodeField =
            true; // Сначала покажем поле для кода, но отправим SMS позже
      }
    });
  }

  // Вход сотрудников через email и пароль
  Future<void> _loginWithEmail(BuildContext context) async {
    setState(() => _isLoading = true);
    try {
      final email = _inputController.text.trim();
      final password = _passwordController.text.trim();
      final userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const EmployeeHomeScreen()),
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: ${e.message}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Отправка SMS для входа по телефону
  Future<void> _sendSMS(BuildContext context) async {
    setState(() => _isLoading = true);
    try {
      String phoneNumber = _inputController.text.trim();
      // Если пользователь ввёл номер без +, добавляем его
      if (!phoneNumber.startsWith('+')) {
        phoneNumber =
            '+7$phoneNumber'; // Предполагаем, что это российский номер
      }
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          final userCredential =
              await FirebaseAuth.instance.signInWithCredential(credential);
          _navigateToPickupSelection(context, userCredential);
        },
        verificationFailed: (FirebaseAuthException e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка верификации: ${e.message}')),
          );
          setState(() => _isLoading = false);
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _isLoading = false;
            _showCodeField = true; // Показываем поле для кода
          });
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Неизвестная ошибка: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  // Вход по коду из SMS
  Future<void> _loginWithPhoneCode(BuildContext context) async {
    setState(() => _isLoading = true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _codeController.text.trim(),
      );
      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      _navigateToPickupSelection(context, userCredential);
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка кода: ${e.message}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Переход на экран выбора пункта выдачи после входа клиента
  void _navigateToPickupSelection(
      BuildContext context, UserCredential userCredential) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => PickupSelectionScreen(
          user: userCredential.user!, // Передаем User
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Вход в WB Пункт',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 40),
              // Поле ввода Email/Phone (без кода страны)
              TextField(
                controller: _inputController,
                decoration: InputDecoration(
                  labelText: 'Email или телефон',
                  hintText: 'например, test@wbpvz.com или 79991234567',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: Icon(Icons.person, color: Colors.deepPurple),
                ),
                keyboardType: TextInputType.phone, // Клавиатура для чисел
                onChanged: _checkInput,
              ),
              const SizedBox(height: 20),
              // Поле пароля для сотрудников
              if (_showPasswordField)
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Пароль',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: Icon(Icons.lock, color: Colors.deepPurple),
                  ),
                  obscureText: true,
                ),
              // Поле кода для клиентов
              if (_showCodeField)
                TextField(
                  controller: _codeController,
                  decoration: InputDecoration(
                    labelText: 'Код из SMS',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: Icon(Icons.sms, color: Colors.deepPurple),
                  ),
                  keyboardType: TextInputType.number,
                ),
              const SizedBox(height: 20),
              // Кнопка действия
              ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        if (_inputType == 'email' && _showPasswordField) {
                          _loginWithEmail(context);
                        } else if (_inputType == 'phone') {
                          if (_verificationId == null) {
                            _sendSMS(context);
                          } else if (_showCodeField) {
                            _loginWithPhoneCode(context);
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        _inputType == 'email'
                            ? 'Войти'
                            : (_verificationId == null
                                ? 'Отправить код'
                                : 'Подтвердить'),
                        style:
                            const TextStyle(fontSize: 18, color: Colors.white),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
