import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl_phone_field/intl_phone_field.dart'; // Для ввода телефона
import 'package:intl_phone_field/phone_number.dart'; // Для ввода телефона
import 'pickup_selection_screen.dart'; // Экран выбора ПВЗ для клиента
import 'employee_home_screen.dart'; // Главный экран сотрудника

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _inputController =
      TextEditingController(); // Общий контроллер для email/phone
  final TextEditingController _passwordController =
      TextEditingController(); // Контроллер для пароля
  final TextEditingController _codeController =
      TextEditingController(); // Контроллер для SMS кода

  String? _verificationId; // Хранение ID верификации для SMS
  bool _isLoading = false; // Состояние загрузки для кнопки
  bool _isCodeSent = false; // Показывает, был ли отправлен SMS код
  bool _isEmailMode =
      false; // Флаг для определения режима ввода (email или телефон)

  @override
  void dispose() {
    _inputController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  // --- Определение типа ввода (Email или Телефон) ---
  void _determineInputType(String input) {
    final isEmail = input.contains('@') && input.endsWith('wbpvz.com');
    if (_isEmailMode != isEmail) {
      // Обновляем только если тип изменился
      setState(() {
        _isEmailMode = isEmail;
        _isCodeSent = false; // Сбрасываем флаг SMS при смене типа
        _verificationId = null;
        // Очищаем ненужные контроллеры при смене режима
        if (_isEmailMode) {
          _codeController.clear();
        } else {
          _passwordController.clear();
        }
      });
    }
  }

  // --- Вход через Email и Пароль (для сотрудников) ---
  Future<void> _signInWithEmail() async {
    if (_inputController.text.isEmpty || _passwordController.text.isEmpty)
      return;
    setState(() => _isLoading = true);
    try {
      await _auth.signInWithEmailAndPassword(
        email: _inputController.text.trim(),
        password: _passwordController.text.trim(),
      );
      await _navigateBasedOnRole(); // Навигация после успешного входа
    } on FirebaseAuthException catch (e) {
      print("Error signing in with email: ${e.message}");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Ошибка входа: ${e.message ?? e.code}")),
        );
      }
    } catch (e) {
      print("Generic Error signing in with email: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Произошла ошибка входа.")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Отправка SMS кода (для клиентов) ---
  Future<void> _sendSmsCode() async {
    if (_inputController.text.isEmpty) return;
    final String phoneNumber = _inputController.text.trim();
    // Предварительная проверка на существование клиента в БД
    final dbRef = FirebaseDatabase.instance.ref();
    final phoneKey = phoneNumber.startsWith('+')
        ? phoneNumber.substring(1)
        : phoneNumber; // Убираем '+' если есть
    final customerSnapshot =
        await dbRef.child('users/customers/$phoneKey').get();

    if (!customerSnapshot.exists) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Клиент с номером $phoneNumber не найден.')),
        );
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber, // Передаем номер как есть (с +)
        verificationCompleted: (PhoneAuthCredential credential) async {
          print("Phone verification completed automatically.");
          // Автоматический вход (редко срабатывает на iOS)
          await _auth.signInWithCredential(credential);
          await _navigateBasedOnRole();
        },
        verificationFailed: (FirebaseAuthException e) {
          print("Phone verification failed: ${e.message}");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text("Ошибка верификации: ${e.message ?? e.code}")),
            );
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          print("SMS code sent, verificationId: $verificationId");
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              _isCodeSent = true; // Показываем поле для ввода кода
            });
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          print("SMS code auto retrieval timeout.");
          _verificationId = verificationId; // Сохраняем на случай ручного ввода
        },
        timeout: const Duration(seconds: 60), // Таймаут ожидания SMS
      );
    } catch (e) {
      print("Error sending SMS code: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Ошибка отправки SMS: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Проверка SMS кода и вход (для клиентов) ---
  Future<void> _verifySmsCode() async {
    if (_codeController.text.isEmpty || _verificationId == null) return;
    setState(() => _isLoading = true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _codeController.text.trim(),
      );
      await _auth.signInWithCredential(credential);
      await _navigateBasedOnRole(); // Навигация после успешной верификации
    } on FirebaseAuthException catch (e) {
      print("Error verifying code: ${e.message}");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Ошибка кода: ${e.message ?? e.code}")),
        );
      }
    } catch (e) {
      print("Generic Error verifying code: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Произошла ошибка верификации.")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Навигация после успешного входа ---
  Future<void> _navigateBasedOnRole() async {
    final user = _auth.currentUser;
    if (user == null) {
      print("Navigation Error: User is null after login attempt.");
      return;
    }

    final databaseReference = FirebaseDatabase.instance.ref();
    String? role;
    // String? pickupPointId; // ID ПВЗ больше не нужен для EmployeeHomeScreen

    if (user.email != null && user.email!.endsWith('@wbpvz.com')) {
      // Логика для сотрудника
      final emailKey = user.email!.replaceAll('.', '_').replaceAll('@', '_');
      print("Checking employee role for key: $emailKey");
      final employeeSnapshot =
          await databaseReference.child('users/employees/$emailKey').get();
      if (employeeSnapshot.exists && employeeSnapshot.value != null) {
        final employeeData = employeeSnapshot.value as Map<dynamic, dynamic>;
        role = employeeData['role'] as String?;
        // pickupPointId = employeeData['pickup_point_id'] as String?; // Можно получить, если нужен в другом месте
        print("Role identified as employee: $role");
      } else {
        print(
            "Employee data not found in DB for key: $emailKey. Check DB structure/key.");
      }
    } else if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
      // Логика для клиента
      final phoneNumber = user.phoneNumber!.replaceAll('+', '');
      print("Checking customer role for phone: $phoneNumber");
      final customerSnapshot =
          await databaseReference.child('users/customers/$phoneNumber').get();
      if (customerSnapshot.exists && customerSnapshot.value != null) {
        final customerData = customerSnapshot.value as Map<dynamic, dynamic>;
        role = customerData['role']
            as String?; // Убедись, что у клиентов есть role: "customer"
        print("Role identified as customer: $role");
      } else {
        print(
            "Customer data not found in DB for phone: $phoneNumber. Check DB structure/key.");
      }
    }

    // --- Непосредственно навигация ---
    if (!mounted) return; // Проверка перед навигацией

    if (role == 'employee') {
      print("Navigating to EmployeeHomeScreen...");
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              const EmployeeHomeScreen(), // <<<--- ПРАВИЛЬНЫЙ ЭКРАН
        ),
      );
    } else if (role == 'customer') {
      print("Navigating to PickupSelectionScreen...");
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) =>
                const PickupSelectionScreen()), // Клиент идет на выбор ПВЗ
      );
    } else {
      print(
          "Navigation Error: Role is undefined or invalid ('$role'). Signing out.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                "Не удалось определить роль пользователя. Попробуйте снова.")),
      );
      await _auth.signOut(); // Выход, если роль не ясна
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Вход в WB Пункт'),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
      ),
      backgroundColor: Colors.grey[100],
      body: Center(
        child: SingleChildScrollView(
          // Для предотвращения переполнения на маленьких экранах
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // Логотип или иконка (опционально)
              Icon(Icons.local_shipping, size: 60, color: Colors.deepPurple),
              SizedBox(height: 20),
              Text(
                'Добро пожаловать!',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple),
              ),
              SizedBox(height: 32),

              // --- Поле ввода Email или Телефона ---
              TextField(
                controller: _inputController,
                keyboardType:
                    TextInputType.emailAddress, // Позволяет вводить @ и .
                decoration: InputDecoration(
                  hintText:
                      'Email сотрудника (@wbpvz.com) или Телефон клиента (+7...)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: Icon(
                      _isEmailMode
                          ? Icons.email_outlined
                          : Icons.phone_outlined,
                      color: Colors.deepPurple),
                ),
                onChanged: _determineInputType, // Определяем тип при вводе
              ),
              SizedBox(height: 16),

              // --- Поле Пароля (только для Email) ---
              if (_isEmailMode)
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    hintText: 'Пароль',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon:
                        Icon(Icons.lock_outline, color: Colors.deepPurple),
                  ),
                  obscureText: true,
                ),

              // --- Поле Кода из SMS (только для Телефона после отправки) ---
              if (!_isEmailMode && _isCodeSent)
                TextField(
                  controller: _codeController,
                  decoration: InputDecoration(
                    hintText: 'Код из SMS',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon:
                        Icon(Icons.sms_outlined, color: Colors.deepPurple),
                  ),
                  keyboardType: TextInputType.number,
                ),
              SizedBox(height: 32),

              // --- Основная кнопка (Вход / Отправить код / Подтвердить код) ---
              ElevatedButton(
                onPressed: _isLoading
                    ? null // Блокируем кнопку во время загрузки
                    : () {
                        if (_isEmailMode) {
                          _signInWithEmail();
                        } else if (_isCodeSent) {
                          _verifySmsCode();
                        } else {
                          _sendSmsCode();
                        }
                      },
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    padding: EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                    textStyle: TextStyle(fontSize: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    minimumSize:
                        Size(double.infinity, 50) // Кнопка на всю ширину
                    ),
                child: _isLoading
                    ? SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white)))
                    : Text(
                        _isEmailMode
                            ? 'Войти'
                            : (_isCodeSent
                                ? 'Подтвердить код'
                                : 'Отправить код'),
                        style: TextStyle(color: Colors.white)),
              ),
              SizedBox(height: 16),

              // --- Кнопка "Забыли пароль?" (только для Email) ---
              if (_isEmailMode)
                TextButton(
                  onPressed: () {
                    // TODO: Implement forgot password logic for email
                    if (_inputController.text.isEmpty ||
                        !_inputController.text.contains('@')) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Введите email сотрудника')));
                      return;
                    }
                    FirebaseAuth.instance
                        .sendPasswordResetEmail(
                            email: _inputController.text.trim())
                        .then((_) => ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(
                                    'Письмо для сброса пароля отправлено на ${_inputController.text.trim()}'))))
                        .catchError((e) => ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(
                                content: Text('Ошибка сброса пароля: $e'))));
                  },
                  child: Text('Забыли пароль?',
                      style: TextStyle(color: Colors.grey)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
