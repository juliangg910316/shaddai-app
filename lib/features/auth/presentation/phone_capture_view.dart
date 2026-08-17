import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/theme_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';

class PhoneCaptureView extends ConsumerStatefulWidget {
  const PhoneCaptureView({super.key});

  @override
  ConsumerState<PhoneCaptureView> createState() => _PhoneCaptureViewState();
}

class _PhoneCaptureViewState extends ConsumerState<PhoneCaptureView> {
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _savePhone() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || phone.length < 8) return;

    setState(() => _isLoading = true);

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

    return Scaffold(
      backgroundColor: ThemeColors.bone,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Monograma, igual que en la pantalla de acceso
              Center(
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: ThemeColors.gold),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    "D'S",
                    style: AppText.serif(
                      size: 26,
                      color: ThemeColors.gold,
                      spacing: 1,
                      height: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 26),
              Center(
                child: Text(
                  l10n.completeProfileTitle,
                  style: AppText.serif(size: 30, color: ThemeColors.darkGreen),
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
                      color: ThemeColors.olive,
                      height: 1.6,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 34),
              Text(l10n.whatsappFieldLabel, style: AppText.eyebrow()),
              const SizedBox(height: 8),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                cursorColor: ThemeColors.gold,
                style: AppText.sans(size: 16, color: ThemeColors.darkGreen),
                decoration: InputDecoration(
                  hintText: l10n.phoneHintExample,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(left: 16, right: 10),
                    child: WhatsAppIcon(),
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 0,
                    minHeight: 0,
                  ),
                ),
              ),
              const SizedBox(height: 9),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  l10n.whatsappDisclaimer,
                  style: AppText.sans(
                    size: 12,
                    weight: FontWeight.w300,
                    color: ThemeColors.olive,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              if (_isLoading)
                const SizedBox(
                  height: 54,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: ThemeColors.darkGreen,
                      strokeWidth: 2,
                    ),
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
