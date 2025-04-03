import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stattrak/Sign-upPage.dart';
import 'package:provider/provider.dart';
import 'providers/SupabaseProvider.dart';
import 'package:stattrak/DashboardPage.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logging in...')),
      );

      try {
        final supabaseProvider =
        Provider.of<SupabaseProvider>(context, listen: false);
        final user = await supabaseProvider.signInUser(
          email: _emailController.text,
          password: _passwordController.text,
        );

        if (user == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Login failed. Check credentials or confirm email.')),
          );
          return;
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => DashboardPage()),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final isLargeScreen = screenWidth > 800;

          return Stack(
            children: [
              // Background Image from Assets
              Positioned.fill(
                child: Image.asset(
                  'icons/landingpage.jpg', // Load image from assets
                  fit: BoxFit.cover,
                ),
              ),
              Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                      child: isLargeScreen
                          ? _buildLargeScreenContent(context)
                          : _buildSmallScreenContent(context),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }


  Widget _buildLargeScreenContent(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The form container will be on the left side of the screen
        Expanded(
          flex: 1, // This will ensure the form container takes 1/3 of the screen width
          child: Padding(
            padding: const EdgeInsets.only(left: 40, top: 100),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _buildForm(context),
            ),
          ),
        ),
        // The text content will be placed on the right side
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.only(right: 40, left: 20, top: 160),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'A WEB-BASED INFORMATION FOR CYCLISTS\nTHAT IT’S EASY AND FREE',
                style: TextStyle(
                  fontFamily: 'RubikMonoOne',
                  fontSize: 34,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSmallScreenContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Text(
            'A WEB-BASED INFORMATION FOR CYCLISTS\nTHAT IT’S EASY AND FREE',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'RubikMonoOne',
              fontSize: 24,
              color: Colors.black,
            ),
          ),
        ),
        _buildForm(context),
      ],
    );
  }

  Widget _buildForm(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 350),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white, // White background for the container
          borderRadius: BorderRadius.circular(12), // Rounded corners
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 5,
            ),
          ], // Optional shadow for the container
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTextField(
                controller: _emailController,
                label: 'Email',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _passwordController,
                label: 'Password',
                obscureText: true,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                  onPressed: _handleLogin,
                  child: const Text(
                    'Log In',
                    style: TextStyle(
                      fontFamily: 'RubikMonoOne',
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // "Or" text and Sign Up button below the login button
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'or',
                    style: TextStyle(
                      fontFamily: 'RubikMonoOne',
                      fontSize: 14,
                      color: Colors.black,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SignUpPage()),
                      );
                    },
                    child: const Text(
                      'Sign Up',
                      style: TextStyle(
                        fontFamily: 'RubikMonoOne',
                        fontSize: 14,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Clickable Terms and Conditions
              GestureDetector(
                onTap: () {
                  // Navigate to Terms and Conditions or show a dialog
                  // For now, just print the action
                  print("Terms and Conditions clicked");
                },
                child: Text(
                  'By signing up for Stattrak, you agree to the Terms of Service.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'RubikMonoOne',
                    fontSize: 12,
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText && _obscurePassword,
      keyboardType: keyboardType,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your $label';
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          fontFamily: 'RubikMonoOne',
          fontSize: 14,
          color: Colors.black,
        ),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: Colors.lightBlueAccent, width: 1),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: Colors.lightBlueAccent),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: Colors.lightBlueAccent, width: 2),
        ),
        suffixIcon: label == 'Password'
            ? IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: Colors.black,
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        )
            : null,
      ),
      style: const TextStyle(
        fontFamily: 'RubikMonoOne',
        fontSize: 14,
        color: Colors.black,
      ),
    );
  }
}
