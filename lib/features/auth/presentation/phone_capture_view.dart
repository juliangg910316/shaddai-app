import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_text.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../../core/widgets/whatsapp_field.dart';
import '../../../l10n/app_localizations.dart';
import '../../booking/logic/whatsapp.dart';
import '../providers/auth_provider.dart';

class PhoneCaptureView extends ConsumerStatefulWidget {
  const PhoneCaptureView({super.key});

  @override
  ConsumerState<PhoneCaptureView> createState() => _PhoneCaptureViewState();
}

class _PhoneCaptureViewState extends ConsumerState<PhoneCaptureView> {
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  /// Si se intentó guardar un número no válido (spec 009, RF-27).
  bool _invalid = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _savePhone() async {
    final phone = _phoneController.text.trim();
    // La misma validación que al cambiarlo desde el perfil y que la de una
    // persona sin cuenta (spec 009, D-7; spec 007).
    if (!isValidWhatsApp(phone)) {
      setState(() => _invalid = true);
      return;
    }

    setState(() {
      _invalid = false;
      _isLoading = true;
    });

    final user = ref.read(currentUserProvider).value;
    if (user != null) {
      await ref.read(userRepositoryProvider).updatePhoneNumber(user.uid, phone);
      // Forzar refresco para que GoRouter detecte que ya tiene teléfono
      ref.invalidate(currentUserProvider);
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Sello de la marca, igual que en la pantalla de acceso
              const Center(child: BrandLogo(size: 76)),
              const SizedBox(height: 26),
              Center(
                child: Text(
                  l10n.completeProfileTitle,
                  style: AppText.serif(size: 30, color: brand.inkStrong),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: SizedBox(
                  width: 260,
                  child: Text(
                    l10n.completeProfileSubtitle,
                    textAlign: TextAlign.center,
                    style: AppText.sans(
                      size: 15,
                      weight: FontWeight.w300,
                      color: brand.inkMuted,
                      height: 1.6,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 34),
              WhatsAppField(
                controller: _phoneController,
                errorText: _invalid ? l10n.whatsAppInvalid : null,
              ),
              const SizedBox(height: 30),
              if (_isLoading)
                const SizedBox(
                  height: 54,
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                GoldPillButton(
                  label: l10n.saveAndContinueAction,
                  onPressed: _savePhone,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
