/*
|--------------------------------------------------------------------------
| Login Page
|--------------------------------------------------------------------------
|
| محتويات الملف:
| - إدخال اسم المستخدم أو وسيلة تسجيل الدخول.
| - إدخال كلمة المرور.
| - تنفيذ تسجيل الدخول عبر AuthController.
| - عرض حالة التحميل ورسالة الخطأ.
|
| ملاحظة:
| لا تقوم الصفحة بالتنقل يدويًا بعد نجاح تسجيل الدخول.
| GoRouter يراقب AuthController وينتقل تلقائيًا إلى MainPage.
|
*/

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:talbytk/core/router/route_names.dart';

import '../providers/auth_providers.dart';
import '../states/auth_state.dart';
import '../widgets/auth_surface.dart';

final class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

final class _LoginPageState extends ConsumerState<LoginPage> {
  static const String _deviceName = 'talbytk-flutter-app';

  final _formKey = GlobalKey<FormState>();

  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid) {
      return;
    }

    FocusScope.of(context).unfocus();

    await ref
        .read(authProvider)
        .login(
          login: _loginController.text,
          password: _passwordController.text,
          deviceName: _deviceName,
        );
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(authProvider);
    final state = controller.state;

    final isLoading = state.status == AuthStatus.authenticating;

    return AuthSurface(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset(
                        'assets/icon/logo.png',
                        width: 64,
                        height: 64,
                        semanticLabel: 'طلبيتك',
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'أهلًا بك في طلبيتك',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text('سجّل الدخول إلى حسابك'),
                  const SizedBox(height: 28),

                  TextFormField(
                    controller: _loginController,
                    enabled: !isLoading,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.username],
                    decoration: const InputDecoration(
                      labelText: 'اسم المستخدم أو البريد أو الهاتف',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'أدخل بيانات تسجيل الدخول';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _passwordController,
                    enabled: !isLoading,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    onFieldSubmitted: (_) {
                      if (!isLoading) {
                        _submit();
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        tooltip: _obscurePassword
                            ? 'إظهار كلمة المرور'
                            : 'إخفاء كلمة المرور',
                        onPressed: isLoading
                            ? null
                            : () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (value) {
                      /*
                         * لا نستخدم trim هنا؛ لأن المسافات
                         * قد تكون جزءًا من كلمة المرور.
                         */
                      if (value == null || value.isEmpty) {
                        return 'أدخل كلمة المرور';
                      }

                      return null;
                    },
                  ),

                  if (state.status == AuthStatus.failure &&
                      state.errorMessage != null) ...[
                    const SizedBox(height: 16),
                    AuthErrorMessage(state.errorMessage!),
                  ],

                  const SizedBox(height: 24),

                  AuthPrimaryButton(
                    label: 'تسجيل الدخول',
                    busy: isLoading,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: isLoading
                        ? null
                        : () => context.push(RouteNames.register),
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: const Text('إنشاء حساب جديد'),
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
