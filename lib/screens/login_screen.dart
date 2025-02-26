import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import 'home_screen.dart'; // Import HomeScreen (Customer)
import 'employee_home_screen.dart'; // Import EmployeeHomeScreen (Create this file)

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailPhoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false; // Track loading state

  @override
  void dispose() {
    _emailPhoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login(BuildContext context) async {
    setState(() {
      _isLoading = true; // Start loading
    });

    try {
      String emailPhone = _emailPhoneController.text.trim();
      String password = _passwordController.text.trim();

      if (emailPhone.endsWith('@wbpvz.com')) {
        // Employee Login (Email/Password)
        try {
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: emailPhone,
            password: password,
          );
          // Successful Employee Login
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const EmployeeHomeScreen()),
          );
        } on FirebaseAuthException catch (e) {
          // Handle Firebase Auth errors (e.g., invalid email, wrong password)
          print('Firebase Auth Error: ${e.code} - ${e.message}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка входа: ${e.message}')),
          );
        } catch (e) {
          // Handle other errors
          print('Login Error: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Неизвестная ошибка')),
          );
        }
      } else {
        // Customer Login (Phone/Password) - Not implemented yet
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Вход по номеру телефона пока не реализован')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false; // Stop loading
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Вход'),
        backgroundColor: Colors.deepPurple,
      ),
      backgroundColor: Colors.grey[100],
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                'Войдите в свой аккаунт',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple),
              ),
              SizedBox(height: 32),
              TextField(
                controller: _emailPhoneController,
                decoration: InputDecoration(
                  hintText: 'Email или номер телефона',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: Icon(Icons.person, color: Colors.deepPurple),
                ),
              ),
              SizedBox(height: 16),
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
                  prefixIcon: Icon(Icons.lock, color: Colors.deepPurple),
                ),
                obscureText: true,
              ),
              SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : () => _login(context), // Disable button while loading
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                  textStyle: TextStyle(fontSize: 18),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white)) // Show loading indicator
                    : Text('Войти', style: TextStyle(color: Colors.white)),
              ),
              SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  // TODO: Implement sign up logic
                },
                child: Text('Зарегистрироваться',
                    style: TextStyle(color: Colors.deepPurple)),
              ),
              TextButton(
                onPressed: () {
                  // TODO: Implement forgot password logic
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
