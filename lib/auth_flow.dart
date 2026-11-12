import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'app_theme.dart';

class FirebaseSetupScreen extends StatelessWidget {
  const FirebaseSetupScreen({required this.details, super.key});

  final String details;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.cloud_off, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Firebase is not configured',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                const Text(
                  'From the app folder, run `flutterfire configure` and select '
                  'your Firebase project and Android/iOS platforms. Then enable '
                  'Email/Password, Google, and Phone under Firebase '
                  'Authentication sign-in providers.',
                ),
                const SizedBox(height: 12),
                SelectableText(details),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({required this.signedInChild, super.key});

  final Widget signedInChild;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return FirebaseSetupScreen(details: snapshot.error.toString());
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data == null ? const LoginScreen() : signedInChild;
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static Future<void>? _googleSignInInitialization;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _smsCodeController = TextEditingController();

  bool _isCreatingAccount = false;
  bool _isLoading = false;
  bool _usePhone = false;
  String? _errorMessage;
  String? _verificationId;
  int? _resendingToken;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _smsCodeController.dispose();
    super.dispose();
  }

  String _messageFor(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'invalid-credential':
        return 'The email or password is incorrect.';
      case 'wrong-password':
        return 'The email or password is incorrect.';
      case 'email-already-in-use':
        return 'An account already exists for this email.';
      case 'weak-password':
        return 'Choose a stronger password (at least 6 characters).';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled in Firebase Authentication.';
      case 'too-many-requests':
        return 'Too many attempts. Wait a little and try again.';
      case 'invalid-phone-number':
        return 'Enter a valid phone number with its country code.';
      case 'invalid-verification-code':
        return 'That SMS code is incorrect. Check it and try again.';
      default:
        return error.message ?? 'Authentication failed (${error.code}).';
    }
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() {
      _errorMessage = message;
      _isLoading = false;
    });
  }

  Future<void> _submitEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final auth = FirebaseAuth.instance;
      if (_isCreatingAccount) {
        await auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        await auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }
    } on FirebaseAuthException catch (error) {
      _setError(_messageFor(error));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _setError('Enter your email address first.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset email sent.')),
        );
      }
    } on FirebaseAuthException catch (error) {
      _setError(_messageFor(error));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _googleSignInInitialization ??= GoogleSignIn.instance.initialize();
      await _googleSignInInitialization;

      final googleSignIn = GoogleSignIn.instance;
      if (!googleSignIn.supportsAuthenticate()) {
        _setError('Google sign-in is not available on this platform.');
        return;
      }

      final account = await googleSignIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        _setError(
          'Google did not return an ID token. Check the Firebase and Google '
          'OAuth configuration for this app.',
        );
        return;
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      await FirebaseAuth.instance.signInWithCredential(credential);
    } on FirebaseAuthException catch (error) {
      _setError(_messageFor(error));
    } on GoogleSignInException catch (error) {
      if (error.code != GoogleSignInExceptionCode.canceled) {
        _setError(error.description ?? 'Google sign-in failed.');
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendPhoneCode() async {
    final phoneNumber = _phoneController.text.trim();
    if (!phoneNumber.startsWith('+') || phoneNumber.length < 8) {
      _setError(
        'Enter your phone number in international format, e.g. +15551234567.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        forceResendingToken: _resendingToken,
        verificationCompleted: (credential) async {
          try {
            await FirebaseAuth.instance.signInWithCredential(credential);
          } on FirebaseAuthException catch (error) {
            _setError(_messageFor(error));
          }
        },
        verificationFailed: (error) {
          _setError(_messageFor(error));
        },
        codeSent: (verificationId, resendToken) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _resendingToken = resendToken;
            _isLoading = false;
          });
        },
        codeAutoRetrievalTimeout: (verificationId) {
          if (mounted) {
            setState(() => _verificationId = verificationId);
          }
        },
      );
    } on FirebaseAuthException catch (error) {
      _setError(_messageFor(error));
    }
  }

  Future<void> _verifyPhoneCode() async {
    final verificationId = _verificationId;
    if (verificationId == null) {
      _setError('Request an SMS code first.');
      return;
    }
    if (_smsCodeController.text.trim().isEmpty) {
      _setError('Enter the SMS verification code.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: _smsCodeController.text.trim(),
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
    } on FirebaseAuthException catch (error) {
      _setError(_messageFor(error));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = PennywisePalette.of(context);
    return Scaffold(
      backgroundColor: palette.canvas,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 330,
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: palette.gradient),
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned(top: -90, right: -40, child: _backgroundOrb(230)),
                  Positioned(top: 120, left: -95, child: _backgroundOrb(175)),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Icon(
                              Icons.account_balance_wallet_rounded,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 11),
                          const Text(
                            'Personal Expense Tracker',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      Text(
                        _usePhone
                            ? 'Your money,\nmade simple.'
                            : _isCreatingAccount
                            ? 'Start your\nmoney journey.'
                            : 'Welcome\nback.',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontSize: 34,
                              height: 1.05,
                            ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        'A calmer way to keep track of every little thing.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 27),
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                        decoration: BoxDecoration(
                          color: palette.surface,
                          borderRadius: BorderRadius.circular(27),
                          boxShadow: [
                            BoxShadow(
                              color: palette.text.withValues(alpha: 0.08),
                              blurRadius: 28,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                _usePhone
                                    ? 'Continue with phone'
                                    : _isCreatingAccount
                                    ? 'Create account'
                                    : 'Sign in to your account',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                _usePhone
                                    ? 'We’ll send you a one-time verification code.'
                                    : 'Your spending overview is just a sign-in away.',
                                style: TextStyle(
                                  color: palette.muted,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 20),
                              if (_usePhone)
                                ..._buildPhoneForm()
                              else
                                ..._buildEmailForm(),
                              if (_errorMessage != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.error
                                        .withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .error,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: _isLoading
                                    ? null
                                    : _signInWithGoogle,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: palette.text,
                                  minimumSize: const Size.fromHeight(52),
                                  side: BorderSide(color: palette.line),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                icon: Icon(Icons.g_mobiledata_rounded),
                                label: const Text('Continue with Google'),
                              ),
                              const SizedBox(height: 6),
                              TextButton(
                                onPressed: _isLoading
                                    ? null
                                    : () {
                                        setState(() {
                                          _usePhone = !_usePhone;
                                          _verificationId = null;
                                          _errorMessage = null;
                                        });
                                      },
                                child: Text(
                                  _usePhone
                                      ? 'Use email and password instead'
                                      : 'Sign in with phone instead',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Icon(
                            Icons.lock_rounded,
                            size: 14,
                            color: palette.muted,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Your information stays private and secure',
                            style: TextStyle(
                              color: palette.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _backgroundOrb(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.07),
      ),
    );
  }

  List<Widget> _buildEmailForm() {
    return [
      TextFormField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        decoration: const InputDecoration(
          labelText: 'Email',
          prefixIcon: Icon(Icons.mail_outline_rounded),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) return 'Enter your email.';
          if (!value.contains('@')) return 'Enter a valid email address.';
          return null;
        },
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _passwordController,
        obscureText: true,
        autofillHints: const [AutofillHints.password],
        decoration: const InputDecoration(
          labelText: 'Password',
          prefixIcon: Icon(Icons.lock_outline_rounded),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) return 'Enter your password.';
          if (_isCreatingAccount && value.length < 6) {
            return 'Use at least 6 characters.';
          }
          return null;
        },
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: _isLoading ? null : _sendPasswordReset,
          child: const Text('Forgot password?'),
        ),
      ),
      const SizedBox(height: 4),
      FilledButton(
        onPressed: _isLoading ? null : _submitEmail,
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(_isCreatingAccount ? 'Create account' : 'Sign in'),
      ),
      TextButton(
        onPressed: _isLoading
            ? null
            : () {
                setState(() {
                  _isCreatingAccount = !_isCreatingAccount;
                  _errorMessage = null;
                });
              },
        child: Text(
          _isCreatingAccount
              ? 'Already have an account? Sign in'
              : 'New here? Create an account',
        ),
      ),
    ];
  }

  List<Widget> _buildPhoneForm() {
    return [
      TextFormField(
        controller: _phoneController,
        keyboardType: TextInputType.phone,
        autofillHints: const [AutofillHints.telephoneNumber],
        decoration: const InputDecoration(
          labelText: 'Phone number',
          hintText: '+15551234567',
          prefixIcon: Icon(Icons.phone_iphone_rounded),
        ),
      ),
      if (_verificationId != null) ...[
        const SizedBox(height: 12),
        TextFormField(
          controller: _smsCodeController,
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
          decoration: const InputDecoration(
            labelText: 'SMS verification code',
            prefixIcon: Icon(Icons.password_rounded),
          ),
        ),
      ],
      const SizedBox(height: 16),
      FilledButton(
        onPressed: _isLoading
            ? null
            : _verificationId == null
            ? _sendPhoneCode
            : _verifyPhoneCode,
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(_verificationId == null ? 'Send SMS code' : 'Verify code'),
      ),
      if (_verificationId != null)
        TextButton(
          onPressed: _isLoading
              ? null
              : () {
                  _smsCodeController.clear();
                  _sendPhoneCode();
                },
          child: const Text('Resend SMS code'),
        ),
    ];
  }
}
