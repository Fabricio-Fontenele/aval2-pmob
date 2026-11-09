import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../auth/domain/auth_repository.dart';
import '../../auth/presentation/auth_session_notifier.dart';
import '../../auth/presentation/login_screen.dart';
import '../domain/item_repository.dart';
import '../domain/item_status.dart';
import '../domain/lost_found_item.dart';
import 'item_date_format.dart';
import 'item_form_screen.dart';
import 'item_list_notifier.dart';

class ItemListScreen extends StatefulWidget {
  const ItemListScreen({
    super.key,
    required this.itemRepository,
    required this.authRepository,
    required this.sessionNotifier,
  });

  static const Key refreshButtonKey = ValueKey<String>(
    'item_list_refresh_button',
  );
  static const Key retryButtonKey = ValueKey<String>('item_list_retry_button');
  static const Key publishButtonKey = ValueKey<String>(
    'item_list_publish_button',
  );
  static const Key signInButtonKey = ValueKey<String>(
    'item_list_sign_in_button',
  );
  static const Key signOutButtonKey = ValueKey<String>(
    'item_list_sign_out_button',
  );
  static const Key emptyStateKey = ValueKey<String>('item_list_empty_state');
  static const Key errorStateKey = ValueKey<String>('item_list_error_state');
  static const Key listViewKey = ValueKey<String>('item_list_view');

  static Key cardKey(String itemId) =>
      ValueKey<String>('item_list_card_$itemId');

  final ItemRepository itemRepository;
  final AuthRepository authRepository;
  final AuthSessionNotifier sessionNotifier;

  @override
  State<ItemListScreen> createState() => _ItemListScreenState();
}

class _ItemListScreenState extends State<ItemListScreen> {
  late final ItemListNotifier _notifier;
  bool _isNavigating = false;
  bool _isPromptingExpiredSession = false;

  @override
  void initState() {
    super.initState();
    _notifier = ItemListNotifier(repository: widget.itemRepository);
    _notifier.load();
  }

  @override
  void dispose() {
    _notifier.dispose();
    super.dispose();
  }

  Future<void> _handlePublish() async {
    if (_isNavigating) {
      return;
    }
    _isNavigating = true;
    try {
      if (!widget.sessionNotifier.isAuthenticated) {
        final authenticated = await _openLogin();
        if (!mounted || authenticated != true) {
          return;
        }
      }
      await _openItemForm();
    } finally {
      _isNavigating = false;
    }
  }

  Future<void> _handleSignIn() async {
    if (_isNavigating) {
      return;
    }
    _isNavigating = true;
    try {
      await _openLogin();
    } finally {
      _isNavigating = false;
    }
  }

  Future<bool?> _openLogin() {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => LoginScreen(
          repository: widget.authRepository,
          sessionNotifier: widget.sessionNotifier,
        ),
      ),
    );
  }

  Future<void> _openItemForm() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ItemFormScreen(
          repository: widget.itemRepository,
          onUnauthorized: _handleExpiredSession,
        ),
      ),
    );
    if (!mounted || saved != true) {
      return;
    }
    _showMessage('Objeto cadastrado com sucesso.');
    await _notifier.refreshAfterSave();
  }

  void _handleExpiredSession() {
    widget.sessionNotifier.handleSessionExpired();
    if (!mounted || _isPromptingExpiredSession) {
      return;
    }
    _isPromptingExpiredSession = true;
    _openLogin().whenComplete(() => _isPromptingExpiredSession = false);
  }

  Future<void> _handleSignOut() async {
    final signedOut = await widget.sessionNotifier.logout();
    if (!mounted) {
      return;
    }
    _showMessage(
      signedOut
          ? 'Sessão encerrada.'
          : widget.sessionNotifier.errorMessage ??
                'Não foi possível encerrar a sessão. Tente novamente.',
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Achados e Perdidos'),
        actions: [
          ListenableBuilder(
            listenable: _notifier,
            builder: (context, _) => IconButton(
              key: ItemListScreen.refreshButtonKey,
              tooltip: 'Atualizar lista',
              onPressed: _notifier.isLoading ? null : _notifier.refresh,
              icon: const Icon(Icons.refresh),
            ),
          ),
          ListenableBuilder(
            listenable: widget.sessionNotifier,
            builder: (context, _) => _SessionAction(
              sessionNotifier: widget.sessionNotifier,
              onSignIn: _handleSignIn,
              onSignOut: _handleSignOut,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: ItemListScreen.publishButtonKey,
        onPressed: _handlePublish,
        icon: const Icon(Icons.add),
        label: const Text('Cadastrar'),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _notifier,
          builder: (context, _) =>
              _ItemListBody(notifier: _notifier, onPublish: _handlePublish),
        ),
      ),
    );
  }
}

class _SessionAction extends StatelessWidget {
  const _SessionAction({
    required this.sessionNotifier,
    required this.onSignIn,
    required this.onSignOut,
  });

  final AuthSessionNotifier sessionNotifier;
  final VoidCallback onSignIn;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    if (sessionNotifier.isRestoring || sessionNotifier.isLoggingOut) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (sessionNotifier.isAuthenticated) {
      return IconButton(
        key: ItemListScreen.signOutButtonKey,
        tooltip: 'Sair',
        onPressed: onSignOut,
        icon: const Icon(Icons.logout),
      );
    }

    return IconButton(
      key: ItemListScreen.signInButtonKey,
      tooltip: 'Entrar',
      onPressed: onSignIn,
      icon: const Icon(Icons.login),
    );
  }
}

class _ItemListBody extends StatelessWidget {
  const _ItemListBody({required this.notifier, required this.onPublish});

  final ItemListNotifier notifier;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    final items = notifier.items;

    if (items.isEmpty) {
      if (notifier.status == ItemListStatus.initial || notifier.isLoading) {
        return const _LoadingState();
      }
      if (notifier.hasError) {
        return _CenteredScrollable(
          onRefresh: notifier.refresh,
          child: _ErrorState(
            message: notifier.errorMessage,
            savedItemAwaitingRefresh: notifier.savedItemAwaitingRefresh,
            onRetry: notifier.refresh,
          ),
        );
      }
      return _CenteredScrollable(
        onRefresh: notifier.refresh,
        child: _EmptyState(onPublish: onPublish),
      );
    }

    return Column(
      children: [
        if (notifier.isLoading) const LinearProgressIndicator(),
        if (notifier.hasError)
          _ErrorBanner(
            message: notifier.errorMessage,
            savedItemAwaitingRefresh: notifier.savedItemAwaitingRefresh,
            onRetry: notifier.refresh,
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: notifier.refresh,
            child: ListView.separated(
              key: ItemListScreen.listViewKey,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _ItemCard(item: items[index]),
            ),
          ),
        ),
      ],
    );
  }
}

class _CenteredScrollable extends StatelessWidget {
  const _CenteredScrollable({required this.onRefresh, required this.child});

  static const _verticalPadding = 120.0;

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final minHeight = constraints.hasBoundedHeight
              ? math.max(0.0, constraints.maxHeight - _verticalPadding)
              : 0.0;
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minHeight),
              child: Center(child: child),
            ),
          );
        },
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Carregando objetos...'),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onPublish});

  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      key: ItemListScreen.emptyStateKey,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.inbox_outlined, size: 48),
        const SizedBox(height: 16),
        Text(
          'Nenhum objeto cadastrado ainda.',
          style: textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Arraste para baixo ou use Atualizar lista para buscar novidades.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        FilledButton.tonalIcon(
          onPressed: onPublish,
          icon: const Icon(Icons.add),
          label: const Text('Cadastrar objeto'),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.savedItemAwaitingRefresh,
    required this.onRetry,
  });

  final String? message;
  final bool savedItemAwaitingRefresh;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      key: ItemListScreen.errorStateKey,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.cloud_off, size: 48, color: colorScheme.error),
        const SizedBox(height: 16),
        if (savedItemAwaitingRefresh) ...[
          const Text(_savedItemNotice, textAlign: TextAlign.center),
          const SizedBox(height: 8),
        ],
        Text(
          message ?? 'Não foi possível carregar a lista. Tente novamente.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: ItemListScreen.retryButtonKey,
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Tentar novamente'),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.message,
    required this.savedItemAwaitingRefresh,
    required this.onRetry,
  });

  final String? message;
  final bool savedItemAwaitingRefresh;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      key: ItemListScreen.errorStateKey,
      width: double.infinity,
      color: colorScheme.errorContainer,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            savedItemAwaitingRefresh
                ? _savedItemNotice
                : message ?? 'Não foi possível atualizar a lista.',
            style: TextStyle(color: colorScheme.onErrorContainer),
          ),
          if (savedItemAwaitingRefresh && message != null) ...[
            const SizedBox(height: 4),
            Text(
              message!,
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ],
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: ItemListScreen.retryButtonKey,
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ),
        ],
      ),
    );
  }
}

const _savedItemNotice =
    'O objeto foi salvo no servidor, mas a lista não foi atualizada. '
    'Tente atualizar novamente; o objeto não será cadastrado outra vez.';

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item});

  final LostFoundItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLost = item.status == ItemStatus.lost;
    final accent = isLost ? colorScheme.error : colorScheme.tertiary;
    final badgeBackground = isLost
        ? colorScheme.errorContainer
        : colorScheme.tertiaryContainer;
    final badgeForeground = isLost
        ? colorScheme.onErrorContainer
        : colorScheme.onTertiaryContainer;

    return Card(
      key: ItemListScreen.cardKey(item.id),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: accent),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.name, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(
                  color: badgeBackground,
                  borderRadius: BorderRadius.circular(999),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isLost ? Icons.search_off : Icons.inventory_2_outlined,
                      size: 16,
                      color: badgeForeground,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      item.status.label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: badgeForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(item.description),
            const SizedBox(height: 12),
            _ItemDetail(icon: Icons.place_outlined, text: item.location),
            const SizedBox(height: 4),
            _ItemDetail(
              icon: Icons.schedule,
              text: formatItemDateTime(item.createdAt),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemDetail extends StatelessWidget {
  const _ItemDetail({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
