import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/auth_service.dart';
import '../utils/responsive_helper.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithEmailAndPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await _authService.signInWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text,
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

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      await _authService.signInWithGoogle();
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
    final logoHeight = ResponsiveHelper.getResponsiveHeight(120);
    final verticalSpacing = ResponsiveHelper.getResponsiveHeight(24);
    final largeVerticalSpacing = ResponsiveHelper.getResponsiveHeight(48);
    final horizontalPadding = ResponsiveHelper.getResponsiveWidth(24);
    final buttonHeight = ResponsiveHelper.getResponsiveHeight(56);
    final borderRadius = ResponsiveHelper.getResponsiveWidth(12);
    
    // Responsive font sizes
    final headingFontSize = ResponsiveHelper.getResponsiveFontSize(28);
    final subheadingFontSize = ResponsiveHelper.getResponsiveFontSize(16);
    final buttonFontSize = ResponsiveHelper.getResponsiveFontSize(16);
    
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(horizontalPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: largeVerticalSpacing),
              Image.asset(
                'assets/logo.jpg',
                height: logoHeight,
              ),
              SizedBox(height: largeVerticalSpacing),
              Text(
                'Welcome Back!',
                style: TextStyle(
                  fontSize: headingFontSize,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: ResponsiveHelper.getResponsiveHeight(8)),
              Text(
                'Sign in to continue connecting with professionals',
                style: TextStyle(
                  fontSize: subheadingFontSize,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: largeVerticalSpacing),
              Form(
                key: _formKey,
                child: Column(
                  children: [
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
                    SizedBox(height: ResponsiveHelper.getResponsiveHeight(16)),
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
                  ],
                ),
              ),
              SizedBox(height: verticalSpacing),
              SizedBox(
                height: buttonHeight,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _signInWithEmailAndPassword,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(borderRadius),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : Text(
                    'Sign In',
                    style: TextStyle(fontSize: buttonFontSize),
                  ),
                ),
              ),
              SizedBox(height: ResponsiveHelper.getResponsiveHeight(16)),
              SizedBox(
                height: buttonHeight,
                child: OutlinedButton(
                  onPressed: _isLoading ? null : _signInWithGoogle,
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(borderRadius),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.asset(
                        'assets/google_logo.svg',
                        height: ResponsiveHelper.getResponsiveHeight(24),
                      ),
                      SizedBox(width: ResponsiveHelper.getResponsiveWidth(8)),
                      Text(
                        'Sign in with Google',
                        style: TextStyle(fontSize: buttonFontSize),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: verticalSpacing),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Don't have an account?",
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getResponsiveFontSize(14),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pushNamed('/register');
                    },
                    child: Text(
                      'Sign Up',
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
