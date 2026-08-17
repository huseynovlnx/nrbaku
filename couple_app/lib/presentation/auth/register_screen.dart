import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/terminal_fx.dart';
import '../../providers/auth_providers.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final ok = await ref
        .read(authControllerProvider.notifier)
        .register(_emailCtrl.text, _passCtrl.text);

    if (!mounted) return;

    if (ok) {
      await ref.read(authRepositoryProvider).signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Qeydiyyat uğurludur! İndi giriş edin.'),
          backgroundColor: Color(0xFF4CD2A0),
        ),
      );
      Navigator.of(context).pop();
    } else {
      final error = ref.read(authControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Qeydiyyat uğursuz.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.status == AuthStatus.loading;

    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ShaderMask(
                    shaderCallback: (rect) =>
                        AppTheme.gradient.createShader(rect),
                    child: const Icon(Icons.shield_outlined,
                        size: 56, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Hesab Yarat',
                    textAlign: TextAlign.center,
                    style: AppTheme.heading(size: 24),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Cihazınızı izləmə sistemində qeydiyyatdan keçirin',
                    textAlign: TextAlign.center,
                    style: AppTheme.body(size: 14, color: AppTheme.textDim),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: AppTheme.body(size: 15),
                    decoration: const InputDecoration(
                      labelText: 'E-poçt',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'E-poçt tələb olunur';
                      }
                      if (!v.contains('@')) {
                        return 'Düzgün e-poçt daxil edin';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: _obscure,
                    style: AppTheme.body(size: 15),
                    decoration: InputDecoration(
                      labelText: 'Şifrə',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () =>
                            setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.length < 6) {
                        return 'Ən az 6 simvol daxil edin';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmCtrl,
                    obscureText: _obscure,
                    style: AppTheme.body(size: 15),
                    decoration: const InputDecoration(
                      labelText: 'Şifrə (təkrar)',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Şifrəni təkrar daxil edin';
                      }
                      if (v != _passCtrl.text) {
                        return 'Şifrələr uyğun gəlmir';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: isLoading ? null : _submit,
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text('QEYDIYYAT',
                            style: AppTheme.mono(
                                size: 14,
                                weight: FontWeight.w700,
                                spacing: 2)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
