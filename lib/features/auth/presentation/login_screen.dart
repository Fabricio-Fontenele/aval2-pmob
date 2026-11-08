import 'package:flutter/material.dart';

import '../domain/auth_input_validator.dart';
import '../domain/auth_repository.dart';
import 'auth_form_notifier.dart';
import 'auth_session_notifier.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.repository,
    required this.sessionNotifier,
    this.onAuthenticated,
    this.onNavigateToRegister,
  });

  static const Key emailFieldKey = ValueKey<String>('login_email_field');
  static const Key passwordFieldKey = ValueKey<String>('login_password_field');
  static const Key submitButtonKey = ValueKey<String>('login_submit_button');
  static const Key retryButtonKey = ValueKey<String>('login_retry_button');
  static const Key createAccountButtonKey = ValueKey<String>(
    'login_create_account_button',
  );

  final AuthRepository repository;
  final AuthSessionNotifier sessionNotifier;
  final VoidCallback? onAuthenticated;
  final VoidCallback? onNavigateToRegister;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  late final AuthFormNotifier _formNotifier;

  @override
  void initState() {
    super.initState();
    _formNotifier = AuthFormNotifier(
      repository: widget.repository,
      sessionNotifier: widget.sessionNotifier,
    );
  }

  @override
  void dispose() {
    _formNotifier.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_formNotifier.isSubmitting) {
      return;
    }

    final isFormValid = _formKey.currentState?.validate() ?? false;
    if (!isFormValid) {
      return;
    }

    final authenticated = await _formNotifier.submitLogin(
      email: _emailController.text,
      password: _passwordController.text,
    );

    if (!mounted || !authenticated) {
      return;
    }

    widget.onAuthenticated?.call();
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop(true);
    }
  }

  Future<void> _handleNavigateToRegister() async {
    if (_formNotifier.isSubmitting) {
      return;
    }

    if (widget.onNavigateToRegister != null) {
      widget.onNavigateToRegister!();
      return;
    }

    final registered = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => RegisterScreen(
          repository: widget.repository,
          sessionNotifier: widget.sessionNotifier,
        ),
      ),
    );

    if (!mounted || registered != true) {
      return;
    }

    widget.onAuthenticated?.call();
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Entrar')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      key: LoginScreen.emailFieldKey,
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'E-mail',
                        hintText: 'exemplo@uespi.edu.br',
                        border: OutlineInputBorder(),
                      ),
                      validator: AuthInputValidator.validateEmail,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: LoginScreen.passwordFieldKey,
                      controller: _passwordController,
                      obscureText: true,
                      enableSuggestions: false,
                      autocorrect: false,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _handleSubmit(),
                      decoration: const InputDecoration(
                        labelText: 'Senha',
                        border: OutlineInputBorder(),
                      ),
                      validator: AuthInputValidator.validateLoginPassword,
                    ),
                    const SizedBox(height: 24),
                    ListenableBuilder(
                      listenable: _formNotifier,
                      builder: (context, _) {
                        return _LoginActionsSection(
                          isSubmitting: _formNotifier.isSubmitting,
                          errorMessage: _formNotifier.hasError
                              ? _formNotifier.errorMessage
                              : null,
                          fieldErrors: _formNotifier.hasError
                              ? _formNotifier.fieldErrors
                              : const {},
                          onSubmit: _handleSubmit,
                          onNavigateToRegister: _handleNavigateToRegister,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginActionsSection extends StatelessWidget {
  const _LoginActionsSection({
    required this.isSubmitting,
    required this.errorMessage,
    required this.fieldErrors,
    required this.onSubmit,
    required this.onNavigateToRegister,
  });

  final bool isSubmitting;
  final String? errorMessage;
  final Map<String, String> fieldErrors;
  final VoidCallback onSubmit;
  final VoidCallback onNavigateToRegister;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (errorMessage != null) ...[
          Card(
            color: colorScheme.errorContainer,
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          errorMessage!,
                          style: TextStyle(color: colorScheme.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                  for (final detail in fieldErrors.values) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 32),
                      child: Text(
                        detail,
                        style: TextStyle(color: colorScheme.onErrorContainer),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      key: LoginScreen.retryButtonKey,
                      onPressed: isSubmitting ? null : onSubmit,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar novamente'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        FilledButton.icon(
          key: LoginScreen.submitButtonKey,
          onPressed: isSubmitting ? null : onSubmit,
          icon: isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.login),
          label: Text(isSubmitting ? 'Entrando...' : 'Entrar'),
        ),
        const SizedBox(height: 12),
        TextButton(
          key: LoginScreen.createAccountButtonKey,
          onPressed: isSubmitting ? null : onNavigateToRegister,
          child: const Text('Criar uma conta'),
        ),
      ],
    );
  }
}
