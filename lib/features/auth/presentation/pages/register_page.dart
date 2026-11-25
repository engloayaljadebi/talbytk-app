import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';
import 'package:talbytk/core/router/route_names.dart';

import '../providers/auth_providers.dart';
import '../widgets/auth_surface.dart';

/// Registration follows RegisterRequest.php. It never handles access tokens.
/// Only shop and supplier accounts are supported by this mobile registration screen.
final class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

enum _AccountKind { shop, supplier }

enum _Step { kind, account, business, location, review }

final class _RegisterPageState extends ConsumerState<RegisterPage> {
  static const String _deviceName = 'talbytk-flutter-app';

  final Map<_Step, GlobalKey<FormState>> _forms = {
    for (final step in _Step.values) step: GlobalKey<FormState>(),
  };

  final _username = TextEditingController();
  final _displayName = TextEditingController();
  final _contact = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  final _businessName = TextEditingController();
  final _description = TextEditingController();
  final _locationName = TextEditingController();
  final _administrativeArea = TextEditingController();
  final _locality = TextEditingController();
  final _scrollController = ScrollController();

  _AccountKind _kind = _AccountKind.shop;
  String _contactType = 'phone';
  String? _categoryId;
  List<({String id, String name})> _categories = [];
  bool _loadingCategories = false;
  bool _categoriesLoaded = false;
  String? _categoriesError;
  bool _hidePassword = true;
  bool _hideConfirmation = true;
  int _index = 0;

  /// Server errors are hidden for a field as soon as that field is edited.
  final Set<String> _editedServerFields = <String>{};

  static const List<_Step> _steps = [
    _Step.kind,
    _Step.account,
    _Step.business,
    _Step.location,
    _Step.review,
  ];

  _Step get _step => _steps[_index];

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadCategories);
  }

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
      _username,
      _displayName,
      _contact,
      _password,
      _confirmation,
      _businessName,
      _description,
      _locationName,
      _administrativeArea,
      _locality,
    ]) {
      controller.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  String? _required(String? value, {int min = 2, int max = 160}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'هذا الحقل مطلوب';
    }
    if (text.length < min || text.length > max) {
      return 'يجب أن يكون بين $min و$max حرفًا';
    }
    return null;
  }

  String? _optional(String? value, {int max = 160}) {
    if ((value ?? '').trim().length > max) {
      return 'الحد الأقصى $max حرفًا';
    }
    return null;
  }

  Widget _field({
    required String keyName,
    required String label,
    required TextEditingController controller,
    String? Function(String?)? validator,
    bool enabled = true,
    TextInputType? keyboard,
    List<TextInputFormatter>? formatters,
    int maxLines = 1,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        key: ValueKey('register-$keyName'),
        controller: controller,
        enabled: enabled,
        onChanged: (_) => _markServerFieldEdited(keyName),
        keyboardType: keyboard,
        inputFormatters: formatters,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          errorText: _serverError(keyName),
          hintText: hint,
          helperText: hint == null ? null : ' ',
        ),
        validator: (value) {
          final localError = validator == null
              ? _required(value)
              : validator(value);
          return localError ?? _serverError(keyName);
        },
      ),
    );
  }

  String? _serverError(String field) {
    if (_editedServerFields.contains(field)) {
      return null;
    }
    return ref.read(authProvider).state.registrationFieldErrors[field];
  }

  void _markServerFieldEdited(String field) {
    if (_serverError(field) != null) {
      setState(() => _editedServerFields.add(field));
    }
  }

  int _firstErrorStep(Map<String, String> errors) {
    const account = <String>{
      'username',
      'display_name',
      'contact_type',
      'contact_value',
      'password',
      'password_confirmation',
    };
    const business = <String>{'name', 'description', 'category_id'};
    const location = <String>{
      'location_name',
      'administrative_area',
      'locality',
    };
    final keys = errors.keys.toSet();
    if (keys.contains('account_type')) {
      return _steps.indexOf(_Step.kind);
    }
    if (keys.intersection(account).isNotEmpty) {
      return _steps.indexOf(_Step.account);
    }
    if (keys.intersection(business).isNotEmpty) {
      return _steps.indexOf(_Step.business);
    }
    if (keys.intersection(location).isNotEmpty) {
      return _steps.indexOf(_Step.location);
    }
    return _steps.indexOf(_Step.review);
  }

  Widget _heading(String title, {String? note}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          if (note != null) ...[
            const SizedBox(height: 6),
            Text(note, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }

  Widget _typeTile(
    _AccountKind kind,
    String title,
    String subtitle,
    IconData icon,
  ) {
    final selected = _kind == kind;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: selected
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.10)
            : Theme.of(context).colorScheme.surfaceContainerLow,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() {
              _editedServerFields.add('account_type');
              _kind = kind;
            });
            if (!_categoriesLoaded && !_loadingCategories) {
              _loadCategories();
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(icon, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Icon(selected ? Icons.check_circle : Icons.circle_outlined),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _kindFields() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _heading(
        'نوع الحساب التجاري',
        note:
            'اختر متجرًا أو موردًا؛ كلا النوعين يتطلب فئة نشاط وموقعًا رئيسيًا.',
      ),
      if (_serverError('account_type') != null)
        Text(
          _serverError('account_type')!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      _typeTile(
        _AccountKind.shop,
        'متجر',
        'تسجيل نشاط للبيع بعد الموافقة',
        Icons.storefront_outlined,
      ),
      _typeTile(
        _AccountKind.supplier,
        'مورد',
        'تسجيل نشاط لتوريد المنتجات بعد الموافقة',
        Icons.local_shipping_outlined,
      ),
    ],
  );

  Widget _accountFields(bool busy) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _heading(
        'بيانات الحساب',
        note:
            'أكمل جميع حقول الحساب. استخدم الحروف الإنجليزية أو الأرقام لاسم المستخدم.',
      ),
      _field(
        keyName: 'username',
        label: 'اسم المستخدم',
        controller: _username,
        enabled: !busy,
        validator: (value) =>
            RegExp(r'^[A-Za-z0-9]{3,50}$').hasMatch((value ?? '').trim())
            ? null
            : '3–50 حرفًا إنجليزيًا أو رقمًا فقط',
      ),
      _field(
        keyName: 'display_name',
        label: 'الاسم الشخصي',
        controller: _displayName,
        enabled: !busy,
        validator: (v) => _required(v, min: 2, max: 160),
      ),
      DropdownButtonFormField<String>(
        key: const ValueKey('register-contact-type'),
        initialValue: _contactType,
        decoration: InputDecoration(
          labelText: 'وسيلة الدخول الأساسية',
          errorText: _serverError('contact_type'),
        ),
        items: const [
          DropdownMenuItem(value: 'phone', child: Text('رقم هاتف')),
          DropdownMenuItem(value: 'email', child: Text('بريد إلكتروني')),
        ],
        onChanged: busy
            ? null
            : (v) {
                if (v != null) {
                  setState(() {
                    _contactType = v;
                    _contact.clear();
                    _editedServerFields.add('contact_type');
                    _editedServerFields.add('contact_value');
                  });
                }
              },
      ),
      const SizedBox(height: 14),
      _field(
        keyName: 'contact_value',
        label: _contactType == 'phone'
            ? 'رقم الجوال — 9 أرقام'
            : 'البريد الإلكتروني',
        controller: _contact,
        enabled: !busy,
        keyboard: _contactType == 'phone'
            ? TextInputType.phone
            : TextInputType.emailAddress,
        formatters: _contactType == 'phone'
            ? [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(9),
              ]
            : null,
        validator: (v) {
          final value = (v ?? '').trim();
          if (_contactType == 'phone') {
            return RegExp(r'^[0-9]{9}$').hasMatch(value)
                ? null
                : 'يجب إدخال 9 أرقام بالضبط';
          }
          return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value) &&
                  value.length <= 320
              ? null
              : 'أدخل بريدًا إلكترونيًا صحيحًا';
        },
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextFormField(
          key: const ValueKey('register-password'),
          controller: _password,
          onChanged: (_) => _markServerFieldEdited('password'),
          enabled: !busy,
          obscureText: _hidePassword,
          autofillHints: const [AutofillHints.newPassword],
          decoration: InputDecoration(
            labelText: 'كلمة المرور',
            errorText: _serverError('password'),
            suffixIcon: IconButton(
              tooltip: _hidePassword
                  ? 'إظهار كلمة المرور'
                  : 'إخفاء كلمة المرور',
              onPressed: busy
                  ? null
                  : () => setState(() => _hidePassword = !_hidePassword),
              icon: Icon(
                _hidePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
          validator: (v) {
            final value = v ?? '';
            if (value.length < 8) {
              return 'كلمة المرور لا تقل عن 8 أحرف';
            }
            if (utf8.encode(value).length > 72) {
              return 'كلمة المرور لا تزيد عن 72 بايت';
            }
            return _serverError('password');
          },
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextFormField(
          key: const ValueKey('register-password-confirmation'),
          controller: _confirmation,
          onChanged: (_) => _markServerFieldEdited('password_confirmation'),
          enabled: !busy,
          obscureText: _hideConfirmation,
          autofillHints: const [AutofillHints.newPassword],
          decoration: InputDecoration(
            labelText: 'تأكيد كلمة المرور',
            errorText: _serverError('password_confirmation'),
            suffixIcon: IconButton(
              tooltip: _hideConfirmation ? 'إظهار التأكيد' : 'إخفاء التأكيد',
              onPressed: busy
                  ? null
                  : () =>
                        setState(() => _hideConfirmation = !_hideConfirmation),
              icon: Icon(
                _hideConfirmation
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
          validator: (v) => v == _password.text
              ? _serverError('password_confirmation')
              : 'كلمتا المرور غير متطابقتين',
        ),
      ),
    ],
  );

  Future<void> _loadCategories() async {
    if (_loadingCategories) {
      return;
    }
    setState(() {
      _loadingCategories = true;
      _categoriesError = null;
    });
    try {
      final categories = await ref
          .read(authProvider)
          .fetchRegistrationCategories();
      if (!mounted) {
        return;
      }
      setState(() {
        _categories = categories;
        _categoriesLoaded = true;
        _categoryId = categories.any((c) => c.id == _categoryId)
            ? _categoryId
            : null;
        _loadingCategories = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingCategories = false;
        _categoriesError =
            'تعذر جلب فئات النشاط. تحقق من الاتصال وحاول مرة أخرى.';
      });
    }
  }

  Widget _businessFields(bool busy) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _heading(
        'بيانات النشاط التجاري',
        note: 'يُسمح بفئة نهائية واحدة فقط لكل نشاط.',
      ),
      _field(
        keyName: 'name',
        label: 'اسم النشاط',
        controller: _businessName,
        enabled: !busy,
        validator: (v) => _required(v, min: 2, max: 200),
      ),
      _field(
        keyName: 'description',
        label: 'وصف النشاط (اختياري)',
        controller: _description,
        enabled: !busy,
        maxLines: 3,
        validator: (v) => _optional(v, max: 5000),
      ),
      if (_loadingCategories)
        const Center(child: CircularProgressIndicator())
      else if (_categoriesError != null) ...[
        Text(
          _categoriesError!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        TextButton.icon(
          onPressed: busy ? null : _loadCategories,
          icon: const Icon(Icons.refresh),
          label: const Text('إعادة محاولة جلب الفئات'),
        ),
      ] else if (_categories.isEmpty) ...[
        const Text('لا توجد فئات نشطة متاحة حاليًا.'),
        TextButton(
          onPressed: busy ? null : _loadCategories,
          child: const Text('تحديث الفئات'),
        ),
      ] else ...[
        DropdownButtonFormField<String>(
          key: ValueKey('register-category-${_categoryId ?? 'empty'}'),
          initialValue: _categoryId,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'فئة النشاط (مطلوب)',
            errorText: _serverError('category_id'),
          ),
          items: [
            for (final category in _categories)
              DropdownMenuItem(
                value: category.id,
                child: Text(category.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: busy
              ? null
              : (v) => setState(() {
                  _categoryId = v;
                  _editedServerFields.add('category_id');
                }),
          validator: (v) =>
              v == null ? 'اختر فئة النشاط' : _serverError('category_id'),
        ),
      ],
    ],
  );

  Widget _locationFields(bool busy) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading(
          'الموقع الرئيسي للنشاط',
          note: 'أدخل اسم الموقع والمحافظة والمدينة.',
        ),
        _field(
          keyName: 'location_name',
          label: 'اسم الموقع',
          controller: _locationName,
          enabled: !busy,
          validator: (v) => _required(v, min: 2, max: 160),
        ),
        _field(
          keyName: 'administrative_area',
          label: 'المحافظة / المنطقة الإدارية',
          controller: _administrativeArea,
          enabled: !busy,
          validator: (v) => _required(v, min: 2, max: 160),
        ),
        _field(
          keyName: 'locality',
          label: 'المدينة / المديرية',
          controller: _locality,
          enabled: !busy,
          validator: (v) => _required(v, min: 2, max: 160),
        ),
      ],
    );
  }

  Widget _reviewItem(String title, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 118,
          child: Text(title, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(child: Text(value.isEmpty ? '—' : value)),
      ],
    ),
  );

  Widget _reviewFields(bool busy) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading(
          'مراجعة البيانات',
          note: 'راجع البيانات قبل إنشاء الحساب. لا تُعرض كلمة المرور.',
        ),
        _reviewItem('نوع الحساب', switch (_kind) {
          _AccountKind.shop => 'متجر',
          _AccountKind.supplier => 'مورد',
        }),
        _reviewItem('اسم المستخدم', _username.text.trim()),
        _reviewItem('الاسم الشخصي', _displayName.text.trim()),
        _reviewItem('وسيلة الاتصال', _contact.text.trim()),
        const SizedBox(height: 16),
        _reviewItem('النشاط', _businessName.text.trim()),
        _reviewItem('الفئة', _categoryName()),
        _reviewItem('اسم الموقع', _locationName.text.trim()),
        _reviewItem('المحافظة', _administrativeArea.text.trim()),
        _reviewItem('المدينة', _locality.text.trim()),
        const SizedBox(height: 12),
        const Text(
          'سيُنشأ طلب اعتماد للنشاط، وتبقى صلاحياته التجارية بانتظار قرار الإدارة.',
        ),
        if (busy)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }

  String _categoryName() {
    for (final category in _categories) {
      if (category.id == _categoryId) {
        return category.name;
      }
    }
    return 'لم تُحدد';
  }

  Widget _buildStep(bool busy) => switch (_step) {
    _Step.kind => _kindFields(),
    _Step.account => _accountFields(busy),
    _Step.business => _businessFields(busy),
    _Step.location => _locationFields(busy),
    _Step.review => _reviewFields(busy),
  };

  Future<void> _next() async {
    if (ref.read(authProvider).state.isRegistering) {
      return;
    }
    final valid = _forms[_step]!.currentState?.validate() ?? true;
    if (!valid) {
      return;
    }
    if (_step == _Step.business &&
        (_loadingCategories ||
            _categoriesError != null ||
            _categoryId == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر فئة نشاط متاحة قبل المتابعة.')),
      );
      return;
    }
    if (_index + 1 < _steps.length) {
      _goToStep(_index + 1);
    }
  }

  void _goToStep(int nextIndex) {
    if (nextIndex < 0 || nextIndex >= _steps.length) {
      return;
    }
    setState(() => _index = nextIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  Map<String, Object?> _payload() {
    final description = _description.text.trim();
    return {
      'username': _username.text.trim(),
      'display_name': _displayName.text.trim(),
      'contact_type': _contactType,
      'contact_value': _contact.text.trim(),
      'password': _password.text,
      'password_confirmation': _confirmation.text,
      'device_name': _deviceName,
      'account_type': _kind == _AccountKind.shop ? 'shop' : 'supplier',
      'name': _businessName.text.trim(),
      if (description.isNotEmpty) 'description': description,
      'category_id': _categoryId,
      'location_name': _locationName.text.trim(),
      'administrative_area': _administrativeArea.text.trim(),
      'locality': _locality.text.trim(),
    };
  }

  Future<void> _submit() async {
    if (ref.read(authProvider).state.isRegistering) {
      return;
    }
    if (_categoryId == null || !_categories.any((c) => c.id == _categoryId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر فئة نشاط صحيحة أولًا.')),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    final success = await ref.read(authProvider).registerFromMobile(_payload());
    if (!mounted || success) {
      return;
    }

    final fieldErrors = ref.read(authProvider).state.registrationFieldErrors;
    if (fieldErrors.isNotEmpty) {
      _editedServerFields.clear();
      _goToStep(_firstErrorStep(fieldErrors));
    }
    // Authentication state drives GoRouter on success. Validation failures
    // navigate to the earliest step containing a server-rejected field.
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authProvider).state;
    final busy = state.isRegistering;
    final steps = _steps;
    final step = _step;
    final isLast = _index == steps.length - 1;
    const titles = <_Step, String>{
      _Step.kind: 'النوع',
      _Step.account: 'الحساب',
      _Step.business: 'النشاط',
      _Step.location: 'الموقع',
      _Step.review: 'المراجعة',
    };

    return AuthSurface(
      appBar: AppBar(title: const Text('إنشاء حساب جديد')),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'المرحلة ${_index + 1} من ${steps.length} — ${titles[step]}',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 9),
                    LinearProgressIndicator(
                      value: (_index + 1) / steps.length,
                      borderRadius: BorderRadius.circular(4),
                      minHeight: 5,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  key: const ValueKey('register-scroll'),
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                  child: Form(
                    key: _forms[step],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildStep(busy),
                        if (_step == _Step.kind)
                          TextButton(
                            onPressed: busy
                                ? null
                                : () {
                                    if (context.canPop()) {
                                      context.pop();
                                    } else {
                                      context.go(RouteNames.login);
                                    }
                                  },
                            child: const Text('لديك حساب؟ تسجيل الدخول'),
                          ),
                        if (state.registrationErrorMessage != null) ...[
                          const SizedBox(height: 16),
                          AuthErrorMessage(state.registrationErrorMessage!),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    if (_index > 0) ...[
                      TextButton.icon(
                        onPressed: busy ? null : () => _goToStep(_index - 1),
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('السابق'),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: AuthPrimaryButton(
                        key: const ValueKey('register-continue'),
                        busy: busy,
                        onPressed: isLast ? _submit : _next,
                        label: isLast ? 'إنشاء الحساب' : 'التالي',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
