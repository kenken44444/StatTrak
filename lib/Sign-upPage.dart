import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stattrak/login_page.dart';
import 'package:stattrak/map_page.dart';
import 'providers/SupabaseProvider.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({Key? key}) : super(key: key);

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
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
        name: _nameController.text,
        phone: _phoneController.text, // <-- Pass phone
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
        MaterialPageRoute(builder: (context) => MapPage()),
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
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/icons/signup.jpg', fit: BoxFit.cover),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final isLargeScreen = constraints.maxWidth > 800;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(context, isLargeScreen),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: isLargeScreen
                          ? _buildLargeScreenContent(context)
                          : _buildSmallScreenContent(context),
                    ),
                  ),
                  _buildFooterText(),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isLargeScreen) {
    return Container(
      color: Colors.blue.withOpacity(0.6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'STATTRAK',
            style: TextStyle(
              fontFamily: 'RubikMonoOne',
              fontSize: isLargeScreen ? 48 : 32,
              color: Colors.blue,
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            },
            child: const Text(
              'Log In',
              style: TextStyle(fontFamily: 'DMMono', color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLargeScreenContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(right: 40),
              child: Text(
                'A WEB-BASED INFORMATION FOR CYCLISTS THAT’S EASY AND FREE',
                style: TextStyle(
                  fontFamily: 'RubikMonoOne',
                  fontSize: 34,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          Expanded(flex: 1, child: _buildForm(context)),
        ],
      ),
    );
  }

  Widget _buildSmallScreenContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Text(
            'A WEB-BASED INFORMATION FOR CYCLISTS THAT’S EASY AND FREE',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'RubikMonoOne',
              fontSize: 24,
              color: Colors.white,
            ),
          ),
          _buildForm(context),
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTextField(controller: _nameController, label: 'Name'),
            _buildTextField(controller: _emailController, label: 'Email', keyboardType: TextInputType.emailAddress),
            _buildTextField(controller: _phoneController, label: 'Phone Number', keyboardType: TextInputType.phone),
            _buildTextField(controller: _passwordController, label: 'Password', obscureText: true),
            _buildTextField(controller: _confirmPasswordController, label: 'Confirm Password', obscureText: true),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _handleSignUp,
              child: const Text('Sign Up', style: TextStyle(fontSize: 20)),
            ),
          ],
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter your $label';
          }
          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildFooterText() {
    return Center(
      child: RichText(
        textAlign: TextAlign.center,
        text: const TextSpan(
          style: TextStyle(fontFamily: 'Dangrek', fontSize: 14, color: Colors.black, height: 2.3),
          children: [
            TextSpan(text: 'By signing up for Stattrak, you agree to the '),
            TextSpan(
              text: 'Terms of Service',
              style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
            ),
            TextSpan(text: '. View our '),
            TextSpan(
              text: 'Privacy Policy',
              style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
            ),
            TextSpan(text: '.'),
          ],
        ),
      ),
    );
  }
}
