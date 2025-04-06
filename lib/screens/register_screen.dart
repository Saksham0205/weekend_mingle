import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/responsive_helper.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _professionController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _professionController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await _authService.registerWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text,
        _nameController.text.trim(),
        _professionController.text.trim(),
      );
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Initialize responsive values
    ResponsiveHelper.init(context);
    
    // Calculate responsive values
    final horizontalPadding = ResponsiveHelper.getResponsiveWidth(24);
    final verticalSpacing = ResponsiveHelper.getResponsiveHeight(16);
    final largeVerticalSpacing = ResponsiveHelper.getResponsiveHeight(24);
    final extraLargeVerticalSpacing = ResponsiveHelper.getResponsiveHeight(32);
    final borderRadius = ResponsiveHelper.getResponsiveWidth(12);
    final buttonHeight = ResponsiveHelper.getResponsiveHeight(56);
    
    // Responsive font sizes
    final headingFontSize = ResponsiveHelper.getResponsiveFontSize(28);
    final subheadingFontSize = ResponsiveHelper.getResponsiveFontSize(16);
    final buttonFontSize = ResponsiveHelper.getResponsiveFontSize(16);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Create Account',
          style: TextStyle(
            fontSize: ResponsiveHelper.getResponsiveFontSize(20),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(horizontalPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Join Mingle',
                style: TextStyle(
                  fontSize: headingFontSize,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: ResponsiveHelper.getResponsiveHeight(8)),
              Text(
                'Connect with professionals and make meaningful connections',
                style: TextStyle(
                  fontSize: subheadingFontSize,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: extraLargeVerticalSpacing),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(borderRadius),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: verticalSpacing),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(borderRadius),
                        ),
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
                    SizedBox(height: verticalSpacing),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(borderRadius),
                        ),
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
                    SizedBox(height: verticalSpacing),
                    TextFormField(
                      controller: _professionController,
                      decoration: InputDecoration(
                        labelText: 'Profession',
                        prefixIcon: const Icon(Icons.work_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(borderRadius),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your profession';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(height: largeVerticalSpacing),
              SizedBox(
                height: buttonHeight,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(borderRadius),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : Text(
                    'Create Account',
                    style: TextStyle(fontSize: buttonFontSize),
                  ),
                ),
              ),
              SizedBox(height: largeVerticalSpacing),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account?',
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getResponsiveFontSize(14),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      'Sign In',
                      style: TextStyle(
                        fontSize: ResponsiveHelper.getResponsiveFontSize(14),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}