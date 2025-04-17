import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'pickup_selection_screen.dart';
import 'employee_home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>(); // Добавляем ключ для формы
  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  String? _verificationId;
  bool _isLoading = false;
  bool _isCodeSent = false;
  bool _isEmailMode = false;
  bool _obscurePassword = true; // <<<--- Состояние для видимости пароля
  String? _inputErrorText; // <<<--- Текст ошибки для поля ввода
  String? _passwordErrorText; // <<<--- Текст ошибки для поля пароля
  String? _codeErrorText; // <<<--- Текст ошибки для поля кода

  // Определяем цвета из твоей палитры
  final Color colorDarkPurple = const Color(0xFF481173);
  final Color colorMidPurple = const Color(0xFF990099);
  final Color colorMagenta1 = const Color(0xFFCB11AB);
  final Color colorMagenta2 = const Color(0xFFB42371);
  final Color colorError = Colors.redAccent[100]!; // Цвет для текста ошибок

  @override
  void dispose() {
    _inputController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  // --- Функция для очистки ошибок ---
  void _clearErrors() {
    setState(() {
      _inputErrorText = null;
      _passwordErrorText = null;
      _codeErrorText = null;
    });
  }

  void _determineInputType(String input) {
    _clearErrors(); // Очищаем ошибки при изменении ввода
    final isEmail = input.contains('@') && input.endsWith('wbpvz.com');
    if (_isEmailMode != isEmail) {
      setState(() {
        _isEmailMode = isEmail;
        _isCodeSent = false;
        _verificationId = null;
        // Очищаем контроллеры и ошибки при смене режима
        if (_isEmailMode) {
          _codeController.clear();
        } else {
          _passwordController.clear();
        }
      });
    }
  }

  // --- Обновленные функции входа с обработкой ошибок ---
  Future<void> _signInWithEmail() async {
    _clearErrors(); // Очищаем предыдущие ошибки
    if (_inputController.text.isEmpty) {
      setState(() => _inputErrorText = 'Введите email сотрудника');
      return;
    }
    if (_passwordController.text.isEmpty) {
      setState(() => _passwordErrorText = 'Введите пароль');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _auth.signInWithEmailAndPassword(
        email: _inputController.text.trim(),
        password: _passwordController.text.trim(),
      );
      await _navigateBasedOnRole();
    } on FirebaseAuthException catch (e) {
      print("Error signing in with email: ${e.code} - ${e.message}");
      String errorMessage = "Неизвестная ошибка входа.";
      if (e.code == 'user-not-found' ||
          e.code == 'invalid-email' ||
          e.code == 'invalid-credential') {
        errorMessage = 'Неверный email или пароль.';
        setState(() {
          // Показываем ошибку под обоими полями
          _inputErrorText = ' '; // Пустая строка, чтобы поле подсветилось
          _passwordErrorText = errorMessage;
        });
      } else if (e.code == 'wrong-password') {
        errorMessage = 'Неверный пароль.';
        setState(() => _passwordErrorText = errorMessage);
      } else if (e.code == 'too-many-requests') {
        errorMessage = 'Слишком много попыток. Попробуйте позже.';
        setState(() => _inputErrorText = errorMessage); // Показываем под email
      } else {
        setState(
            () => _inputErrorText = errorMessage); // Общая ошибка под email
      }
      // Убираем SnackBar, т.к. ошибка под полем
      // if (mounted) { ScaffoldMessenger.of(context).showSnackBar(...); }
    } catch (e) {
      print("Generic Error signing in with email: $e");
      setState(() => _inputErrorText = "Произошла ошибка входа.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendSmsCode() async {
    _clearErrors();
    final String phoneNumber = _inputController.text.trim();
    if (phoneNumber.isEmpty) {
      setState(() => _inputErrorText = 'Введите номер телефона');
      return;
    }
    // Простая валидация формата (можно улучшить)
    if (!phoneNumber.startsWith('+') || phoneNumber.length < 10) {
      setState(() => _inputErrorText = 'Неверный формат (+7...)');
      return;
    }

    setState(() => _isLoading = true); // Показываем загрузку ДО проверки в БД
    // Проверка на существование клиента в БД
    final dbRef = FirebaseDatabase.instance.ref();
    final phoneKey = phoneNumber.substring(1); // Убираем '+'
    try {
      final customerSnapshot =
          await dbRef.child('users/customers/$phoneKey').get();

      if (!customerSnapshot.exists && mounted) {
        setState(() {
          _inputErrorText = 'Клиент с номером $phoneNumber не найден.';
          _isLoading = false; // Убираем загрузку
        });
        return; // Прерываем выполнение
      }

      // Если клиент найден, продолжаем отправку кода
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          print("Phone verification completed automatically.");
          _clearErrors();
          await _auth.signInWithCredential(credential);
          await _navigateBasedOnRole();
        },
        verificationFailed: (FirebaseAuthException e) {
          print("Phone verification failed: ${e.code} - ${e.message}");
          String errorMessage = "Ошибка верификации.";
          if (e.code == 'invalid-phone-number') {
            errorMessage = 'Неверный формат номера телефона.';
          } else if (e.code == 'too-many-requests') {
            errorMessage = 'Слишком много попыток. Попробуйте позже.';
          } else if (e.code == 'network-request-failed') {
            errorMessage = 'Ошибка сети. Проверьте подключение.';
          }
          // Добавить другие коды ошибок по мере необходимости
          if (mounted) {
            setState(() => _inputErrorText = errorMessage);
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          print("SMS code sent, verificationId: $verificationId");
          _clearErrors(); // Очищаем ошибки при успешной отправке
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              _isCodeSent = true;
            });
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          print("SMS code auto retrieval timeout.");
          if (mounted && !_isCodeSent) {
            _verificationId = verificationId;
          }
        },
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      print("Error during customer check or sending SMS: $e");
      if (mounted) {
        setState(() => _inputErrorText = "Ошибка отправки SMS.");
      }
    } finally {
      // isLoading убирается либо здесь, либо при ошибке проверки клиента
      if (mounted && _isLoading) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifySmsCode() async {
    _clearErrors();
    if (_codeController.text.isEmpty) {
      setState(() => _codeErrorText = 'Введите код из SMS');
      return;
    }
    if (_verificationId == null) {
      setState(() => _codeErrorText = 'Ошибка сессии. Отправьте код еще раз.');
      _isCodeSent = false; // Сброс для повторной отправки
      return;
    }
    setState(() => _isLoading = true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _codeController.text.trim(),
      );
      await _auth.signInWithCredential(credential);
      _clearErrors(); // Очищаем ошибки перед навигацией
      await _navigateBasedOnRole();
    } on FirebaseAuthException catch (e) {
      print("Error verifying code: ${e.message}");
      String errorMessage = "Неизвестная ошибка кода.";
      if (e.code == 'invalid-verification-code') {
        errorMessage = 'Неверный код из SMS.';
      } else if (e.code == 'session-expired') {
        errorMessage = 'Время сессии истекло. Отправьте код еще раз.';
        setState(() {
          _isCodeSent = false; // Сброс для повторной отправки
          _verificationId = null;
          _codeController.clear();
        });
      }
      if (mounted) {
        setState(() => _codeErrorText = errorMessage);
      }
    } catch (e) {
      print("Generic Error verifying code: $e");
      if (mounted) {
        setState(() => _codeErrorText = "Произошла ошибка верификации.");
      }
    } finally {
      // isLoading сбрасывается здесь только если не было session-expired
      if (mounted && _isCodeSent) setState(() => _isLoading = false);
    }
  }

  // --- (Функция _navigateBasedOnRole остается БЕЗ ИЗМЕНЕНИЙ) ---
  Future<void> _navigateBasedOnRole() async {
    final user = _auth.currentUser;
    if (user == null) {
      print("Navigation Error: User is null after login attempt.");
      return;
    }

    final databaseReference = FirebaseDatabase.instance.ref();
    String? role;
    String? pickupPointId; // ID ПВЗ нужен для EmployeeHomeScreen

    if (user.email != null && user.email!.endsWith('@wbpvz.com')) {
      // Логика для сотрудника
      final emailKey = user.email!.replaceAll('.', '_').replaceAll('@', '_');
      print("Checking employee role for key: $emailKey");
      final employeeSnapshot =
          await databaseReference.child('users/employees/$emailKey').get();
      if (employeeSnapshot.exists && employeeSnapshot.value != null) {
        final employeeData = employeeSnapshot.value as Map<dynamic, dynamic>;
        role = employeeData['role'] as String?;
        pickupPointId =
            employeeData['pickup_point_id'] as String?; // Получаем ID ПВЗ
        print(
            "Role identified as employee: $role, Pickup Point ID: $pickupPointId");
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
      // Проверяем, есть ли pickupPointId
      if (pickupPointId != null && pickupPointId.isNotEmpty) {
        print("Navigating to EmployeeHomeScreen...");
        // Передаем ID ПВЗ в EmployeeHomeScreen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                const EmployeeHomeScreen(), // EmployeeHomeScreen теперь сам загружает ID
          ),
        );
      } else {
        print(
            "Navigation Error: Employee role identified, but pickupPointId is missing. Signing out.");
        // Показываем ошибку пользователю
        _showErrorDialog("Ошибка данных сотрудника",
            "Не удалось определить пункт выдачи. Обратитесь к администратору.");
        await _auth.signOut(); // Выход, если у сотрудника нет ПВЗ
      }
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
      _showErrorDialog("Ошибка входа",
          "Не удалось определить роль пользователя. Попробуйте войти снова.");
      await _auth.signOut(); // Выход, если роль не ясна
    }
  }
  // --- Конец неизмененной функции навигации ---

  // --- Виджет для отображения ошибки под полем ---
  Widget _buildErrorWidget(String? errorText) {
    if (errorText == null || errorText.isEmpty) {
      return const SizedBox.shrink(); // Не показывать ничего, если ошибки нет
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6.0, left: 16.0, right: 16.0),
      child: Text(
        errorText,
        style: TextStyle(color: colorError, fontSize: 13),
        textAlign: TextAlign.start,
      ),
    );
  }

  // --- НОВЫЙ Метод для показа диалога с ошибкой (для критических ошибок) ---
  void _showErrorDialog(String title, String content) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            // Смягченный градиент
            colors: [
              colorDarkPurple.withOpacity(0.95), // Темнее наверху
              colorMidPurple.withOpacity(0.85), // Средний в центре
              colorMidPurple.withOpacity(0.75) // Светлее внизу
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Form(
              // Оборачиваем в Form
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.15),
                    ),
                    child: Icon(
                      Icons.storefront_outlined, // Иконка ПВЗ
                      size: 70,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 24),
                  Text(
                    'Добро пожаловать!',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Вход в пункт выдачи заказов',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                  SizedBox(height: 40),

                  // --- Поле ввода Email или Телефона ---
                  TextFormField(
                    // Используем TextFormField для валидации формой
                    controller: _inputController,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(color: Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'Email сотрудника или Телефон клиента (+7...)',
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16.0),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.95),
                      prefixIcon: Icon(
                        _isEmailMode
                            ? Icons.email_outlined
                            : Icons.phone_outlined,
                        color: colorMidPurple,
                      ),
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      errorText: _inputErrorText, // <<<--- Отображение ошибки
                      errorStyle: TextStyle(
                          height: 0,
                          fontSize: 0), // Скрываем стандартный errorText
                    ),
                    onChanged: _determineInputType,
                    // validator: (value) { ... } // Можно добавить формальную валидацию
                  ),
                  _buildErrorWidget(
                      _inputErrorText), // <<<--- Наш виджет ошибки

                  SizedBox(height: 16),

                  // --- Поле Пароля (только для Email) ---
                  if (_isEmailMode)
                    Column(
                      // Оборачиваем в Column для виджета ошибки
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _passwordController,
                          style: TextStyle(color: Colors.black87),
                          decoration: InputDecoration(
                            hintText: 'Пароль',
                            hintStyle: TextStyle(color: Colors.grey[600]),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16.0),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.95),
                            prefixIcon:
                                Icon(Icons.lock_outline, color: colorMidPurple),
                            suffixIcon: IconButton(
                              // <<<--- Глазок
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: colorMidPurple.withOpacity(0.7),
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            contentPadding: EdgeInsets.symmetric(
                                vertical: 16, horizontal: 16),
                            errorText: _passwordErrorText,
                            errorStyle: TextStyle(height: 0, fontSize: 0),
                          ),
                          obscureText:
                              _obscurePassword, // <<<--- Используем состояние
                          onChanged: (_) =>
                              _clearErrors(), // Очищаем ошибки при вводе
                        ),
                        _buildErrorWidget(
                            _passwordErrorText), // <<<--- Наш виджет ошибки
                      ],
                    ),

                  // --- Поле Кода из SMS (только для Телефона после отправки) ---
                  if (!_isEmailMode && _isCodeSent)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _codeController,
                          style: TextStyle(color: Colors.black87),
                          decoration: InputDecoration(
                            hintText: 'Код из SMS',
                            hintStyle: TextStyle(color: Colors.grey[600]),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16.0),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.95),
                            prefixIcon:
                                Icon(Icons.sms_outlined, color: colorMidPurple),
                            contentPadding: EdgeInsets.symmetric(
                                vertical: 16, horizontal: 16),
                            errorText: _codeErrorText,
                            errorStyle: TextStyle(height: 0, fontSize: 0),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => _clearErrors(),
                        ),
                        _buildErrorWidget(
                            _codeErrorText), // <<<--- Наш виджет ошибки
                      ],
                    ),
                  SizedBox(height: 32),

                  // --- Основная кнопка (Вход / Отправить код / Подтвердить код) ---
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _isLoading
                              ? [Colors.grey.shade500, Colors.grey.shade400]
                              : [colorMagenta2, colorMagenta1],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(16.0),
                        boxShadow: _isLoading
                            ? []
                            : [
                                BoxShadow(
                                  color: colorMagenta1.withOpacity(0.4),
                                  blurRadius: 12,
                                  offset: Offset(0, 5),
                                )
                              ]),
                    child: ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              FocusScope.of(context).unfocus();
                              if (_isEmailMode) {
                                _signInWithEmail();
                              } else if (_isCodeSent) {
                                _verifySmsCode();
                              } else {
                                _sendSmsCode();
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.0)),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white)))
                          : Text(
                              _isEmailMode
                                  ? 'Войти'
                                  : (_isCodeSent
                                      ? 'Подтвердить код'
                                      : 'Отправить код'),
                              style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                    ),
                  ),
                  SizedBox(height: 24), // Добавим отступ снизу
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
