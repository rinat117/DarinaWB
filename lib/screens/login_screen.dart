import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:email_validator/email_validator.dart';
import 'pickup_selection_screen.dart';
import 'employee_home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _smsCodeController = TextEditingController();
  bool _isCustomer = false;
  bool _isCodeSent = false;
  String? _verificationId;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _smsCodeController.dispose();
    super.dispose();
  }

  Future<void> _sendCodeToPhoneNumber() async {
    String phoneNumber = _phoneController.text.trim();
    if (!phoneNumber.startsWith('+')) {
      phoneNumber = '+7$phoneNumber';
    }

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await FirebaseAuth.instance.signInWithCredential(credential);
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => const PickupSelectionScreen()),
            );
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() {
            _errorMessage = 'Ошибка отправки кода: ${e.message}';
          });
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _isCodeSent = true;
            _verificationId = verificationId;
            _errorMessage = null;
          });
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка: $e';
      });
    }
  }

  Future<void> _verifyCode(String smsCode) async {
    if (_verificationId == null) {
      setState(() {
        _errorMessage = 'Идентификатор верификации отсутствует';
      });
      return;
    }

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      print(
          "User logged in: ${FirebaseAuth.instance.currentUser?.phoneNumber}");
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => const PickupSelectionScreen()),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка верификации кода: $e';
      });
    }
  }

  Future<void> _loginAsEmployee() async {
    if (_formKey.currentState!.validate()) {
      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const EmployeeHomeScreen()),
          );
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'Ошибка входа: $e';
        });
      }
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
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              SwitchListTile(
                title: Text(
                    _isCustomer ? 'Вход для клиента' : 'Вход для сотрудника'),
                value: _isCustomer,
                onChanged: (value) {
                  setState(() {
                    _isCustomer = value;
                    _errorMessage = null;
                    _isCodeSent = false;
                    _emailController.clear();
                    _passwordController.clear();
                    _phoneController.clear();
                    _smsCodeController.clear();
                  });
                },
              ),
              if (!_isCustomer) ...[
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Введите email';
                    }
                    if (!EmailValidator.validate(value)) {
                      return 'Введите корректный email';
                    }
                    if (!value.endsWith('@wbpvz.com')) {
                      return 'Email должен быть на домене @wbpvz.com';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Пароль'),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Введите пароль';
                    }
                    if (value.length < 6) {
                      return 'Пароль должен содержать минимум 6 символов';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loginAsEmployee,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                  ),
                  child: const Text('Войти как сотрудник'),
                ),
              ] else ...[
                if (!_isCodeSent) ...[
                  TextFormField(
                    controller: _phoneController,
                    decoration:
                        const InputDecoration(labelText: 'Номер телефона'),
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Введите номер телефона';
                      }
                      if (!RegExp(r'^\d{10}$').hasMatch(value)) {
                        return 'Введите корректный номер телефона (10 цифр)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        _sendCodeToPhoneNumber();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                    ),
                    child: const Text('Отправить код'),
                  ),
                ] else ...[
                  TextFormField(
                    controller: _smsCodeController,
                    decoration: const InputDecoration(labelText: 'Код из SMS'),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Введите код из SMS';
                      }
                      if (value.length != 6) {
                        return 'Код должен содержать 6 цифр';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        _verifyCode(_smsCodeController.text.trim());
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                    ),
                    child: const Text('Подтвердить код'),
                  ),
                ],
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
