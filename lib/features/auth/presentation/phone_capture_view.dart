import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/theme_colors.dart';
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
    
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColors.bone,
      appBar: AppBar(
        title: const Text('Completar Perfil'),
        automaticallyImplyLeading: false, 
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Tu número se usará para mantener contacto directo con la manicuri por WhatsApp, lo que permitirá confirmar, mover o cancelar turnos.",
              style: TextStyle(
                fontSize: 16,
                color: ThemeColors.olive,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Número de WhatsApp',
                prefixIcon: const Icon(Icons.phone, color: ThemeColors.darkGreen),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: ThemeColors.darkGreen, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _savePhone,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: ThemeColors.darkGreen,
                ),
                child: _isLoading 
                    ? const CircularProgressIndicator(color: ThemeColors.gold)
                    : const Text(
                        'GUARDAR Y CONTINUAR',
                        style: TextStyle(
                          color: ThemeColors.gold,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
