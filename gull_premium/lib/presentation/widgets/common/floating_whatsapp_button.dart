import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../l10n/app_localizations.dart';

class FloatingWhatsappButton extends StatelessWidget {
  const FloatingWhatsappButton({super.key});

  static const String _supportPhone = '+9647709818181';

  Uri _buildWhatsappUri(String prefilledMessage) {
    final text = Uri.encodeComponent(prefilledMessage);
    return Uri.parse('https://wa.me/$_supportPhone?text=$text');
  }

  Future<void> _openWhatsapp(
    BuildContext context,
    String prefilledMessage,
  ) async {
    final uri = _buildWhatsappUri(prefilledMessage);
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open WhatsApp right now.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: () => _openWhatsapp(context, l10n.whatsapp_support_message),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFCFCFB),
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [
              BoxShadow(
                color: Color(0x26000000),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
            border: Border.all(
              color: const Color(0xFFEDEDED),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FaIcon(
                FontAwesomeIcons.whatsapp,
                color: Color(0xFF25D366),
                size: 20,
              ),
              SizedBox(width: 10),
              Text(
                l10n.how_can_i_help,
                style: const TextStyle(
                  fontFamily: 'Rudaw',
                  color: Color(0xFF243126),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
