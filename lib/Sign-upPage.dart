import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stattrak/DashboardPage.dart';
import 'package:stattrak/login_page.dart';
import 'package:stattrak/providers/SupabaseProvider.dart';
import 'package:stattrak/utils/responsive_layout.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({Key? key}) : super(key: key);

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Signing up...')),
    );

    try {
      final supabaseProvider =
      Provider.of<SupabaseProvider>(context, listen: false);
      final user = await supabaseProvider.signUpUser(
        email: _emailController.text,
        password: _passwordController.text,
        name: _usernameController.text,
        phone: _phoneController.text,
      );

      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please check your email to confirm your account or try again.'),
          ),
        );
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => DashboardPage()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exception: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ResponsiveLayout(
        mobileLayout: _buildMobileLayout(),
        tabletLayout: _buildTabletLayout(),
        desktopLayout: _buildDesktopLayout(),
      ),
    );
  }

  // Mobile layout
  Widget _buildMobileLayout() {
    return Stack(
      children: [
        // Background image
        Positioned.fill(
          child: Image.asset(
            'assets/icons/signup.jpg',
            fit: BoxFit.cover,
          ),
        ),

        // Logo at top-right
        Positioned(
          top: 20,
          right: 20,
          child: Row(
            children: [
              Image.asset('assets/icons/Stattrak_Logo.png', height: 30),
              const SizedBox(width: 6),
              const Text(
                'Stattrak',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF67E8DA),
                ),
              ),
            ],
          ),
        ),

        // Caption bottom-right
        Positioned(
          bottom: 10,
          right: 10,
          child: Text(
            '*photo AI generated',
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withOpacity(0.7),
              fontStyle: FontStyle.italic,
            ),
          ),
        ),

        // Center form
        Center(
          child: SingleChildScrollView(
            child: _buildSignUpForm(context, true),
          ),
        ),
      ],
    );
  }

  // Tablet layout
  Widget _buildTabletLayout() {
    return Stack(
      children: [
        // Background image
        Positioned.fill(
          child: Image.asset(
            'assets/icons/signup.jpg',
            fit: BoxFit.cover,
          ),
        ),

        // Logo at top-right
        Positioned(
          top: 20,
          right: 30,
          child: Row(
            children: [
              Image.asset('assets/icons/Stattrak_Logo.png', height: 35),
              const SizedBox(width: 8),
              const Text(
                'Stattrak',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF67E8DA),
                ),
              ),
            ],
          ),
        ),

        // Caption bottom-right
        Positioned(
          bottom: 10,
          right: 10,
          child: Text(
            '*photo AI generated',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.7),
              fontStyle: FontStyle.italic,
            ),
          ),
        ),

        // Center form
        Center(
          child: SingleChildScrollView(
            child: _buildSignUpForm(context, false),
          ),
        ),
      ],
    );
  }

  // Desktop layout
  Widget _buildDesktopLayout() {
    return Stack(
      children: [
        // Background image
        Positioned.fill(
          child: Image.asset(
            'assets/icons/signup.jpg',
            fit: BoxFit.cover,
          ),
        ),

        // Logo at top-right
        Positioned(
          top: 20,
          right: 40,
          child: Row(
            children: [
              Image.asset('assets/icons/Stattrak_Logo.png', height: 40),
              const SizedBox(width: 8),
              const Text(
                'Stattrak',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF67E8DA),
                ),
              ),
            ],
          ),
        ),

        // Caption bottom-right
        Positioned(
          bottom: 10,
          right: 10,
          child: Text(
            '*photo AI generated',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.7),
              fontStyle: FontStyle.italic,
            ),
          ),
        ),

        // Center content with form on left and quote on right
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // Sign up form
              _buildSignUpForm(context, false),

              // Quote section
              _buildQuoteSection(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSignUpForm(BuildContext context, bool isMobile) {
    // Determine form width based on screen size
    double formWidth;
    if (isMobile) {
      formWidth = MediaQuery.of(context).size.width * 0.9;
    } else if (MediaQuery.of(context).size.width >= 900) {
      formWidth = 380; // Desktop width
    } else {
      formWidth = 450; // Tablet width
    }

    return Container(
      width: formWidth,
      margin: EdgeInsets.all(isMobile ? 16 : 24),
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Sign up your account',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Form(
            key: _formKey,
            child: Column(
              children: [
                _buildTextField(
                  controller: _emailController,
                  label: 'Email',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _usernameController,
                  label: 'Username',
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _phoneController,
                  label: 'Phone Number',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _passwordController,
                  label: 'Password',
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _confirmPasswordController,
                  label: 'Confirm Password',
                  obscureText: true,
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: _handleSignUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4299E1), // Lighter blue matching design
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Sign up',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Already have an account?',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 14,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                  );
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Log In',
                  style: TextStyle(
                    color: Color(0xFF2196F3),
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ],
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
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 15),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your $label';
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.never,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFF67E8DA), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildQuoteSection() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"From start to finish, we support your journey.\n'
                  'Routes, rides, and everything in between.\n'
                  'Transforming every ride into a goal-achieving experience,\n'
                  'All in one app"',
              style: const TextStyle(
                fontSize: 20,
                color: Colors.white,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}