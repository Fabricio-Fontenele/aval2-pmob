import 'package:flutter/material.dart';

import '../domain/auth_input_validator.dart';
import '../domain/auth_repository.dart';
import 'auth_form_notifier.dart';
import 'auth_session_notifier.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    super.key,
    required this.repository,
    required this.sessionNotifier,
    this.onRegistered,
    this.onNavigateToLogin,
  });

  static const Key emailFieldKey = ValueKey<String>('register_email_field');
  static const Key passwordFieldKey = ValueKey<String>(
    'register_password_field',
  );
  static const Key passwordConfirmationFieldKey = ValueKey<String>(
    'register_password_confirmation_field',
  );
  static const Key submitButtonKey = ValueKey<String>('register_submit_button');
  static const Key retryButtonKey = ValueKey<String>('register_retry_button');
  static const Key alreadyHaveAccountButtonKey = ValueKey<String>(
    'register_already_have_account_button',
  );

  final AuthRepository repository;
  final AuthSessionNotifier sessionNotifier;
  final VoidCallback? onRegistered;
  final VoidCallback? onNavigateToLogin;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordConfirmationController =
      TextEditingController();

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
    _passwordConfirmationController.dispose();
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

    final registered = await _formNotifier.submitRegistration(
      email: _emailController.text,
      password: _passwordController.text,
      passwordConfirmation: _passwordConfirmationController.text,
    );

    if (!mounted || !registered) {
      return;
    }

    widget.onRegistered?.call();
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop(true);
    }
  }

  void _handleNavigateToLogin() {
    if (_formNotifier.isSubmitting) {
      return;
    }

    if (widget.onNavigateToLogin != null) {
      widget.onNavigateToLogin!();
      return;
    }

    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Criar conta')),
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
                      key: RegisterScreen.emailFieldKey,
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
                      key: RegisterScreen.passwordFieldKey,
                      controller: _passwordController,
                      obscureText: true,
                      enableSuggestions: false,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Senha',
                        helperText: 'Mínimo de 8 caracteres',
                        border: OutlineInputBorder(),
                      ),
                      validator:
                          AuthInputValidator.validateRegistrationPassword,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: RegisterScreen.passwordConfirmationFieldKey,
                      controller: _passwordConfirmationController,
                      obscureText: true,
                      enableSuggestions: false,
                      autocorrect: false,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _handleSubmit(),
                      decoration: const InputDecoration(
                        labelText: 'Confirmar senha',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          AuthInputValidator.validatePasswordConfirmation(
                            password: _passwordController.text,
                            confirmation: value,
                          ),
                    ),
                    const SizedBox(height: 24),
                    ListenableBuilder(
                      listenable: _formNotifier,
                      builder: (context, _) {
                        return _RegisterActionsSection(
                          isSubmitting: _formNotifier.isSubmitting,
                          errorMessage: _formNotifier.hasError
                              ? _formNotifier.errorMessage
                              : null,
                          fieldErrors: _formNotifier.hasError
                              ? _formNotifier.fieldErrors
                              : const {},
                          onSubmit: _handleSubmit,
                          onNavigateToLogin: _handleNavigateToLogin,
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

class _RegisterActionsSection extends StatelessWidget {
  const _RegisterActionsSection({
    required this.isSubmitting,
    required this.errorMessage,
    required this.fieldErrors,
    required this.onSubmit,
    required this.onNavigateToLogin,
  });

  final bool isSubmitting;
  final String? errorMessage;
  final Map<String, String> fieldErrors;
  final VoidCallback onSubmit;
  final VoidCallback onNavigateToLogin;

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
                      key: RegisterScreen.retryButtonKey,
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
          key: RegisterScreen.submitButtonKey,
          onPressed: isSubmitting ? null : onSubmit,
          icon: isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.person_add),
          label: Text(isSubmitting ? 'Criando conta...' : 'Criar conta'),
        ),
        const SizedBox(height: 12),
        TextButton(
          key: RegisterScreen.alreadyHaveAccountButtonKey,
          onPressed: isSubmitting ? null : onNavigateToLogin,
          child: const Text('Já tenho uma conta'),
        ),
      ],
    );
  }
}
