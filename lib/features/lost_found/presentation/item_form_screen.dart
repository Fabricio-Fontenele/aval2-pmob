import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/item_input_validator.dart';
import '../domain/item_repository.dart';
import '../domain/item_status.dart';
import 'item_form_notifier.dart';

class ItemFormScreen extends StatefulWidget {
  const ItemFormScreen({
    super.key,
    required this.repository,
    this.onUnauthorized,
    this.onItemSaved,
  });

  static const Key nameFieldKey = ValueKey<String>('item_form_name_field');
  static const Key descriptionFieldKey = ValueKey<String>(
    'item_form_description_field',
  );
  static const Key locationFieldKey = ValueKey<String>(
    'item_form_location_field',
  );
  static const Key statusFieldKey = ValueKey<String>('item_form_status_field');
  static const Key submitButtonKey = ValueKey<String>(
    'item_form_submit_button',
  );
  static const Key retryButtonKey = ValueKey<String>('item_form_retry_button');

  final ItemRepository repository;
  final VoidCallback? onUnauthorized;
  final VoidCallback? onItemSaved;

  @override
  State<ItemFormScreen> createState() => _ItemFormScreenState();
}

class _ItemFormScreenState extends State<ItemFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  late final ItemFormNotifier _notifier;
  ItemStatus? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _notifier = ItemFormNotifier(
      repository: widget.repository,
      onUnauthorized: widget.onUnauthorized,
    );
  }

  @override
  void dispose() {
    _notifier.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_notifier.isSubmitting) {
      return;
    }

    final isFormValid = _formKey.currentState?.validate() ?? false;
    if (!isFormValid) {
      return;
    }

    final saved = await _notifier.submit(
      name: _nameController.text,
      description: _descriptionController.text,
      location: _locationController.text,
      status: _selectedStatus,
    );

    if (!mounted || !saved) {
      return;
    }

    widget.onItemSaved?.call();
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cadastrar objeto')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      key: ItemFormScreen.nameFieldKey,
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      maxLength: ItemInputValidator.maxNameLength,
                      maxLengthEnforcement: MaxLengthEnforcement.none,
                      decoration: const InputDecoration(
                        labelText: 'Nome do objeto',
                        hintText: 'Ex.: Garrafa térmica azul',
                        border: OutlineInputBorder(),
                      ),
                      validator: ItemInputValidator.validateName,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: ItemFormScreen.descriptionFieldKey,
                      controller: _descriptionController,
                      minLines: 3,
                      maxLines: 5,
                      maxLength: ItemInputValidator.maxDescriptionLength,
                      maxLengthEnforcement: MaxLengthEnforcement.none,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        labelText: 'Descrição',
                        hintText: 'Informe características que ajudem a identificar o objeto',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                      validator: ItemInputValidator.validateDescription,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: ItemFormScreen.locationFieldKey,
                      controller: _locationController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Local',
                        hintText: 'Ex.: Biblioteca Central, Bloco B',
                        border: OutlineInputBorder(),
                      ),
                      validator: ItemInputValidator.validateLocation,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<ItemStatus>(
                      key: ItemFormScreen.statusFieldKey,
                      initialValue: _selectedStatus,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Situação',
                        border: OutlineInputBorder(),
                      ),
                      items: ItemStatus.values
                          .map(
                            (status) => DropdownMenuItem<ItemStatus>(
                              value: status,
                              child: Text(status.label),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        _selectedStatus = value;
                      },
                      validator: ItemInputValidator.validateStatus,
                    ),
                    const SizedBox(height: 24),
                    ListenableBuilder(
                      listenable: _notifier,
                      builder: (context, _) {
                        return _SubmissionActionsSection(
                          isSubmitting: _notifier.isSubmitting,
                          errorMessage: _notifier.hasError
                              ? _notifier.errorMessage
                              : null,
                          fieldErrors: _notifier.hasError
                              ? _notifier.fieldErrors
                              : const {},
                          onSubmit: _handleSubmit,
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

class _SubmissionActionsSection extends StatelessWidget {
  const _SubmissionActionsSection({
    required this.isSubmitting,
    required this.errorMessage,
    required this.fieldErrors,
    required this.onSubmit,
  });

  final bool isSubmitting;
  final String? errorMessage;
  final Map<String, String> fieldErrors;
  final VoidCallback onSubmit;

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
                      key: ItemFormScreen.retryButtonKey,
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
          key: ItemFormScreen.submitButtonKey,
          onPressed: isSubmitting ? null : onSubmit,
          icon: isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: Text(isSubmitting ? 'Salvando...' : 'Salvar objeto'),
        ),
      ],
    );
  }
}
