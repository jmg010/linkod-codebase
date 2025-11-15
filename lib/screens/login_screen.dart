import 'package:flutter/material.dart';
import '../models/user_role.dart';
import '../ui_constants.dart';
import '../widgets/linkod_app_bar_title.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  UserRole _selectedRole = UserRole.resident;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    if (_formKey.currentState!.validate()) {
      // Save role in a simple variable
      final selectedRole = _selectedRole;

      // Navigate to HomeScreen and pass the role
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => HomeScreen(userRole: selectedRole),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const LinkodAppBarTitle()),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(kPaddingLarge * 1.5),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo or App Title
                Text(
                  'Welcome to LINKod',
                  textAlign: TextAlign.center,
                  style: kHeadlineMedium.copyWith(color: kFacebookBlue),
                ),
                const SizedBox(height: kPaddingLarge * 3),

                // Email Field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'Enter your email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: kPaddingLarge),

                // Password Field
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    hintText: 'Enter your password',
                    prefixIcon: Icon(Icons.lock_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: kPaddingLarge),

                // Role Dropdown
                DropdownButtonFormField<UserRole>(
                  value: _selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'User Role',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  items:
                      UserRole.values.map((UserRole role) {
                        return DropdownMenuItem<UserRole>(
                          value: role,
                          child: Text(role.displayName),
                        );
                      }).toList(),
                  onChanged: (UserRole? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedRole = newValue;
                      });
                    }
                  },
                ),
                const SizedBox(height: kPaddingLarge * 2),

                // Login Button
                ElevatedButton(
                  onPressed: _handleLogin,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: kPaddingLarge,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(kCardRadius),
                    ),
                  ),
                  child: const Text(
                    'Login',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
