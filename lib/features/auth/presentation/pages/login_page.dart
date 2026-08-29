import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

/// Sign-in screen: an angled hero band (logo + glow, app identity) that
/// the sign-in panel overlaps into, rather than a centered card floating
/// on a plain background. Every field, icon, and the primary button use
/// bespoke widgets ([_LoginField], [_PrimaryButton]) instead of the
/// theme's generic Material defaults, so this screen has its own
/// distinct shape language while still pulling every color from
/// [AppTheme].
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const _heroHeight = 250.0;
  static const _panelOverlap = 44.0;

  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = true;

  @override
  void initState() {
    super.initState();
    if (AppConfig.appVersion.isEmpty) {
      AppConfig.initPackageInfo().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthBloc>().add(
      LoginRequested(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        rememberMe: _rememberMe,
      ),
    );
  }

  Future<void> _confirmExit(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Exit app?',
      message: 'Are you sure you want to close the app?',
      confirmLabel: 'Exit',
    );

    if (confirmed) SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _confirmExit(context);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          backgroundColor: scheme.surface,
          body: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                Column(
                  children: [
                    _HeroBand(height: _heroHeight, scheme: scheme),
                    const Expanded(child: SizedBox.shrink()),
                  ],
                ),
                Positioned.fill(
                  top: _heroHeight - _panelOverlap,
                  child: BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, state) {
                      final loading = state.status == AuthStatus.loading;
                      return _SignInPanel(
                        scheme: scheme,
                        textTheme: textTheme,
                        formKey: _formKey,
                        loading: loading,
                        errorMessage: state.status == AuthStatus.error
                            ? (state.errorMessage ?? 'Login failed')
                            : null,
                        usernameController: _usernameController,
                        passwordController: _passwordController,
                        obscurePassword: _obscurePassword,
                        onToggleObscure: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        rememberMe: _rememberMe,
                        onRememberMeChanged: (v) =>
                            setState(() => _rememberMe = v ?? true),
                        onSubmit: _submit,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The identity moment: an angled band (only the bottom corners curve,
/// like a banner rather than a card) carrying the logo on a soft accent
/// glow — no boxed/circled logo badge — plus the wordmark. Deliberately
/// not a centered-everything layout: the sign-in panel below overlaps
/// its bottom edge.
class _HeroBand extends StatelessWidget {
  const _HeroBand({required this.height, required this.scheme});

  final double height;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(48),
        bottomRight: Radius.circular(48),
      ),
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(scheme.surface, scheme.primary, 0.16)!,
              scheme.surface,
            ],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 76,
                  height: 76,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // A borderless, boxless glow orb behind the logo —
                      // replaces the previous white circular badge, which
                      // read as a placeholder rather than a brand choice.
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: AppTheme.glow(
                            scheme.primary,
                            opacity: 0.55,
                            blur: 40,
                          ),
                        ),
                      ),
                      Image.asset(
                        'assets/logo/app_launcher.png',
                        width: 68,
                        height: 68,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'BATAAN LGU SCANNER',
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The overlapping sign-in sheet: rounded on the top two corners only
/// (an attached sheet, not a floating centered card), holding the
/// bespoke [_LoginField]s and [_PrimaryButton].
class _SignInPanel extends StatelessWidget {
  const _SignInPanel({
    required this.scheme,
    required this.textTheme,
    required this.formKey,
    required this.loading,
    required this.errorMessage,
    required this.usernameController,
    required this.passwordController,
    required this.obscurePassword,
    required this.onToggleObscure,
    required this.rememberMe,
    required this.onRememberMeChanged,
    required this.onSubmit,
  });

  final ColorScheme scheme;
  final TextTheme textTheme;
  final GlobalKey<FormState> formKey;
  final bool loading;
  final String? errorMessage;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onToggleObscure;
  final bool rememberMe;
  final ValueChanged<bool?> onRememberMeChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Sign in', style: textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(
                  'Use your scanner-staff account to continue.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 28),
                _LoginField(
                  label: 'Username',
                  icon: Icons.badge_outlined,
                  controller: usernameController,
                  textInputAction: TextInputAction.next,
                  enabled: !loading,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Required'
                      : null,
                ),
                const SizedBox(height: 18),
                _LoginField(
                  label: 'Password',
                  icon: Icons.shield_outlined,
                  controller: passwordController,
                  obscureText: obscurePassword,
                  textInputAction: TextInputAction.done,
                  enabled: !loading,
                  onFieldSubmitted: (_) => onSubmit(),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                  trailing: _FieldIconButton(
                    icon: obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    onPressed: onToggleObscure,
                  ),
                ),
                const SizedBox(height: 6),
                _RememberMeToggle(
                  value: rememberMe,
                  onChanged: loading ? null : onRememberMeChanged,
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          size: 18,
                          color: scheme.onErrorContainer,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            errorMessage!,
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onErrorContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                _PrimaryButton(
                  loading: loading,
                  label: 'Log in',
                  onPressed: loading ? null : onSubmit,
                ),
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    AppConfig.appVersion.isEmpty
                        ? ''
                        : 'v${AppConfig.appVersion}',
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A bespoke text field: a square icon badge to the left, label above
/// the input, and a bottom hairline that thickens and turns accent-blue
/// on focus — replaces the app-wide filled rounded-box field with a
/// leaner, distinctly "sign-in screen" shape.
class _LoginField extends StatefulWidget {
  const _LoginField({
    required this.label,
    required this.icon,
    required this.controller,
    this.obscureText = false,
    this.textInputAction,
    this.enabled = true,
    this.onFieldSubmitted,
    this.validator,
    this.trailing,
  });

  final String label;
  final IconData icon;
  final TextEditingController controller;
  final bool obscureText;
  final TextInputAction? textInputAction;
  final bool enabled;
  final ValueChanged<String>? onFieldSubmitted;
  final FormFieldValidator<String>? validator;
  final Widget? trailing;

  @override
  State<_LoginField> createState() => _LoginFieldState();
}

class _LoginFieldState extends State<_LoginField> {
  final _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _focused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final accent = _focused ? scheme.primary : scheme.onSurfaceVariant;

    return FormField<String>(
      validator: widget.validator,
      builder: (field) {
        final hasError = field.hasError;
        final borderColor = hasError
            ? scheme.error
            : (_focused ? scheme.primary : scheme.outlineVariant);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.label.toUpperCase(),
              style: textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: borderColor,
                  width: (_focused || hasError) ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: _focused
                          ? scheme.primary.withValues(alpha: 0.16)
                          : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(widget.icon, size: 18, color: accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      focusNode: _focusNode,
                      obscureText: widget.obscureText,
                      textInputAction: widget.textInputAction,
                      enabled: widget.enabled,
                      autofillHints: const [],
                      onSubmitted: widget.onFieldSubmitted,
                      onChanged: (v) => field.didChange(v),
                      style: textTheme.bodyLarge,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        isDense: true,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (widget.trailing != null) widget.trailing!,
                ],
              ),
            ),
            if (hasError) ...[
              const SizedBox(height: 6),
              Text(
                field.errorText!,
                style: textTheme.bodySmall?.copyWith(color: scheme.error),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _FieldIconButton extends StatelessWidget {
  const _FieldIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// "Remember me" as a tappable pill row with a custom check chip instead
/// of a full-width [CheckboxListTile] — keeps the panel's leaner,
/// left-aligned rhythm instead of Material's default list-item padding.
class _RememberMeToggle extends StatelessWidget {
  const _RememberMeToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: value ? scheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: value ? scheme.primary : scheme.outline,
                  width: 1.5,
                ),
              ),
              child: value
                  ? Icon(Icons.check_rounded, size: 14, color: scheme.onPrimary)
                  : null,
            ),
            const SizedBox(width: 10),
            Text(
              'Remember me',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

/// The one full-pill button on this screen: fully rounded (999), a
/// trailing arrow that swaps for a spinner while loading, and the
/// signature accent glow — distinct from the app-wide 14px-radius
/// [FilledButton] shape used everywhere else, since this is the single
/// highest-stakes action a staff member takes each shift.
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.loading,
    required this.label,
    required this.onPressed,
  });

  final bool loading;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: loading
            ? const []
            : AppTheme.glow(scheme.primary, opacity: 0.4, blur: 22),
      ),
      child: Material(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onPressed,
          child: Center(
            child: loading
                ? SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: scheme.onPrimary,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: scheme.onPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: scheme.onPrimary,
                        size: 20,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
