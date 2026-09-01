import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/household_service.dart';
import '../../../core/services/storage_service.dart';

/// Widget para verificar el household usando código OTP
/// Se muestra solo si el household no está verificado
class HouseholdVerificationWidget extends StatefulWidget {
  final Map<String, dynamic> householdInfo;
  final VoidCallback? onVerified;

  const HouseholdVerificationWidget({
    super.key,
    required this.householdInfo,
    this.onVerified,
  });

  @override
  State<HouseholdVerificationWidget> createState() =>
      _HouseholdVerificationWidgetState();
}

class _HouseholdVerificationWidgetState
    extends State<HouseholdVerificationWidget> {
  final _codeController = TextEditingController();
  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verifyCode() async {
    if (_codeController.text.length != 6) {
      setState(() {
        _errorMessage = 'El código debe tener 6 dígitos';
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final success = await HouseholdService.verifyHouseholdCode(
        householdId: widget.householdInfo['household_id'],
        verificationCode: _codeController.text,
      );

      if (success && mounted) {
        // Limpiar household_data de storage (ya no necesitamos mostrar verificación)
        await StorageService.setHouseholdData({});

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Grupo verificado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );

        widget.onVerified?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().contains('incorrecto')
              ? 'Código incorrecto'
              : e.toString().contains('expirado')
              ? 'Código expirado. Solicita uno nuevo.'
              : 'Error al verificar. Intenta nuevamente.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  Future<void> _resendCode() async {
    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    try {
      final result = await HouseholdService.resendVerificationCode(
        widget.householdInfo['household_id'],
      );

      if (mounted) {
        // Actualizar storage con nuevo código
        final householdData = StorageService.householdData ?? {};
        householdData['verification_code'] = result['verification_code'];
        await StorageService.setHouseholdData(householdData);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📧 Código reenviado a ${result['owner_email']}'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al reenviar código'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = widget.householdInfo['is_owner'] ?? false;
    final verified = widget.householdInfo['verified'] ?? false;

    // Solo mostrar si es owner y no está verificado
    if (!isOwner || verified) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.orange.shade50, Colors.orange.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange.shade800,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Verifica tu grupo familiar',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Ingresa el código de 6 dígitos que recibiste por email:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    decoration: InputDecoration(
                      hintText: '000000',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.pin),
                      errorText: _errorMessage,
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isVerifying ? null : _verifyCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isVerifying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Verificar'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: _isResending ? null : _resendCode,
                  icon: _isResending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: const Text('Reenviar código'),
                ),
                TextButton(
                  onPressed: () {
                    // Cerrar el widget (marcar como "no mostrar")
                    StorageService.setHouseholdData({});
                    widget.onVerified?.call();
                  },
                  child: const Text('Verificar después'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
