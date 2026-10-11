import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/motion.dart';
import '../../data/repo.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';

final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Numéro au format international : retire espaces, tirets et parenthèses, « 00… » devient « +… ».
String normalizePhone(String v) {
  final p = v.replaceAll(RegExp(r'[\s\-.()]'), '');
  return p.startsWith('00') ? '+${p.substring(2)}' : p;
}

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, this.next, this.signup = false});
  final String? next;
  final bool signup;
  @override
  ConsumerState<AuthScreen> createState() => _AuthState();
}

class _AuthState extends ConsumerState<AuthScreen> {
  late bool signup = widget.signup;
  bool forgot = false, busy = false, terms = false, otpStage = false, phoneMode = false, showPw = false;
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pw = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  String? info;

  @override
  void dispose() {
    for (final c in [_email, _pw, _name, _phone, _otp]) {
      c.dispose();
    }
    super.dispose();
  }

  void _done() {
    if (!mounted) return;
    context.go(widget.next ?? '/');
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    if (signup && !terms && !(phoneMode && otpStage)) return toast(context, context.t('auth.err.terms'), error: true);
    setState(() {
      busy = true;
      info = null;
    });
    try {
      final auth = sb.auth;
      if (forgot) {
        await auth.resetPasswordForEmail(_email.text.trim(), redirectTo: '${AppConfig.siteUrl}/auth/reset');
        setState(() => info = context.t('auth.reset_sent'));
      } else if (phoneMode) {
        if (!otpStage) {
          await _sendCode();
        } else {
          await auth.verifyOTP(phone: normalizePhone(_phone.text), token: _otp.text.trim(), type: OtpType.sms);
          _done();
        }
      } else if (signup) {
        final r = await auth.signUp(email: _email.text.trim(), password: _pw.text, data: {'display_name': _name.text.trim()});
        if (r.session != null) {
          _done();
        } else {
          setState(() => info = context.t('auth.check_email'));
        }
      } else {
        await auth.signInWithPassword(email: _email.text.trim(), password: _pw.text);
        _done();
      }
    } catch (e) {
      if (mounted) toast(context, context.t(errorKey(e)), error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  /// Envoie (ou renvoie) le code SMS. Un nouveau numéro crée le compte ; le nom saisi à l'inscription devient le nom affiché.
  Future<void> _sendCode() async {
    final name = _name.text.trim();
    await sb.auth.signInWithOtp(phone: normalizePhone(_phone.text), data: signup && name.length >= 2 ? {'display_name': name} : null);
    if (mounted) setState(() => otpStage = true);
  }

  Future<void> _google() async {
    try {
      await sb.auth.signInWithOAuth(OAuthProvider.google, redirectTo: AppConfig.siteUrl);
    } catch (e) {
      if (mounted) toast(context, context.t('auth.err.provider_disabled'), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final wide = isWide(context);
    final title = forgot ? context.t('auth.forgot') : (signup ? context.t('auth.signup') : context.t('auth.login'));

    final formCard = Container(
      constraints: const BoxConstraints(maxWidth: 440),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(28), border: Border.all(color: cs.outlineVariant.withValues(alpha: .6)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .06), blurRadius: 30, offset: const Offset(0, 14))]),
      child: Form(
        key: _form,
        child: AnimatedSize(
          duration: Motion.base,
          curve: Motion.emphasized,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            AnimatedSwitcher(duration: Motion.base, child: Text(title, key: ValueKey(title), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800))),
            const SizedBox(height: 18),
            if (AppConfig.phoneAuth && !forgot) ...[
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: false, icon: const Icon(Icons.mail_outline_rounded, size: 18), label: Text(context.t('auth.email'))),
                    ButtonSegment(value: true, icon: const Icon(Icons.phone_outlined, size: 18), label: Text(context.t('auth.phone'))),
                  ],
                  selected: {phoneMode},
                  onSelectionChanged: (v) => setState(() {
                    phoneMode = v.first;
                    otpStage = false;
                    info = null;
                  }),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (info != null) Container(margin: const EdgeInsets.only(bottom: 14), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: WM.signal.withValues(alpha: .12), borderRadius: BorderRadius.circular(14)), child: Text(info!)).popIn(),
            if (phoneMode && !forgot) ...[
              if (signup && !otpStage) field(_name, context.t('auth.display_name'), icon: Icons.person_outline_rounded, validator: (v) => (v ?? '').trim().length < 2 ? context.t('err.generic') : null),
              field(_phone, context.t('auth.phone'), hint: '+22670000000', type: TextInputType.phone, icon: Icons.phone_outlined, validator: (v) => RegExp(r'^\+\d{8,15}$').hasMatch(normalizePhone(v ?? '')) ? null : context.t('auth.err.phone_format')),
              if (!otpStage) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(context.t('auth.phone_hint'), style: Theme.of(context).textTheme.bodySmall)),
              if (otpStage) ...[
                field(_otp, context.t('auth.otp_code', {'phone': _phone.text}), type: TextInputType.number, icon: Icons.sms_outlined),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(spacing: 4, children: [
                    TextButton(onPressed: busy ? null : () => guard(context, _sendCode, ok: 'auth.code_resent'), child: Text(context.t('auth.resend_code'))),
                    TextButton(onPressed: () => setState(() => otpStage = false), child: Text(context.t('auth.change_number'))),
                  ]),
                ),
              ],
            ] else ...[
              if (signup && !forgot) field(_name, context.t('auth.display_name'), icon: Icons.person_outline_rounded, validator: (v) => (v ?? '').trim().length < 2 ? context.t('err.generic') : null),
              field(_email, context.t('auth.email'), type: TextInputType.emailAddress, icon: Icons.mail_outline_rounded, validator: (v) => _emailRe.hasMatch((v ?? '').trim()) ? null : context.t('auth.err.invalid_email')),
              if (!forgot)
                field(_pw, context.t('auth.password'), obscure: !showPw, icon: Icons.lock_outline_rounded, suffix: IconButton(icon: Icon(showPw ? Icons.visibility_off_outlined : Icons.visibility_outlined), onPressed: () => setState(() => showPw = !showPw)), validator: (v) => (v ?? '').length < 8 ? context.t('auth.err.weak_password') : null),
            ],
            if (signup && !forgot && !(phoneMode && otpStage))
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: terms,
                onChanged: (v) => setState(() => terms = v ?? false),
                title: Wrap(children: [Text('${context.t('auth.accept_terms')} '), GestureDetector(onTap: () => context.push('/info/terms'), child: Text(context.t('footer.terms'), style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700)))]),
              ),
            const SizedBox(height: 6),
            GradientButton(
              label: forgot ? context.t('auth.send_link') : phoneMode ? (otpStage ? context.t('auth.verify') : context.t('auth.send_code')) : title,
              loading: busy,
              onPressed: _submit,
            ),
            const SizedBox(height: 10),
            if (!forgot && !signup && !phoneMode) Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => setState(() => forgot = true), child: Text(context.t('auth.forgot')))),
            if (AppConfig.googleAuth && !forgot) ...[
              const SizedBox(height: 4),
              OutlinedButton.icon(onPressed: _google, icon: const Icon(Icons.g_mobiledata_rounded, size: 28), label: Text(context.t('auth.google')), style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50))),
            ],
            Center(
              child: TextButton(
                onPressed: () => setState(() {
                  if (forgot) {
                    forgot = false;
                  } else {
                    signup = !signup;
                  }
                  info = null;
                }),
                child: Text(forgot || signup ? '${context.t('auth.have_account')} ${context.t('auth.login')}' : '${context.t('auth.no_account')} ${context.t('auth.signup')}'),
              ),
            ),
          ]),
        ),
      ),
    ).animate().fadeIn(duration: Motion.slow).slideY(begin: .08, end: 0, curve: Motion.emphasized, duration: 650.ms);

    return Scaffold(
      body: Stack(children: [
        Positioned.fill(child: Container(decoration: const BoxDecoration(gradient: WM.nightGradient))),
        const Positioned.fill(child: WifiRings(rings: 6, alignment: Alignment.topLeft)),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const LogoWordmark(light: true, size: 40).popIn(),
                SizedBox(height: wide ? 28 : 18),
                formCard,
                const SizedBox(height: 10),
                TextButton(onPressed: () => context.go('/'), child: const Text('← WiFiMarket', style: TextStyle(color: Colors.white70))),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});
  @override
  State<ResetPasswordScreen> createState() => _ResetState();
}

class _ResetState extends State<ResetPasswordScreen> {
  final _pw = TextEditingController();
  bool busy = false;
  @override
  void dispose() {
    _pw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => WPage(
        title: context.t('auth.new_password'),
        maxWidth: 480,
        child: Column(children: [
          const SizedBox(height: 16),
          field(_pw, context.t('auth.new_password'), obscure: true),
          Text(context.t('auth.password_hint'), style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          GradientButton(
            label: context.t('common.save'),
            loading: busy,
            onPressed: () async {
              if (_pw.text.length < 8) return toast(context, context.t('auth.err.weak_password'), error: true);
              setState(() => busy = true);
              await guard(context, () async {
                await sb.auth.updateUser(UserAttributes(password: _pw.text));
                if (context.mounted) context.go('/');
              }, ok: 'auth.password_updated');
              if (mounted) setState(() => busy = false);
            },
          ),
        ]),
      );
}
