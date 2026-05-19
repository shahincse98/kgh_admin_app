import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Dials [phone] using the device's phone app.
Future<void> launchPhone(String phone) async {
  if (phone.isEmpty) return;
  final uri = Uri(scheme: 'tel', path: phone);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  }
}

/// A small tappable phone icon that dials [phone] when tapped.
/// Renders nothing if [phone] is empty.
class CallButton extends StatelessWidget {
  final String phone;
  final double size;
  final Color? color;

  const CallButton({
    super.key,
    required this.phone,
    this.size = 16,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (phone.isEmpty) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => launchPhone(phone),
      child: Padding(
        padding: const EdgeInsets.only(left: 6),
        child: Icon(
          Icons.call_rounded,
          size: size,
          color: color ?? Colors.green.shade600,
        ),
      ),
    );
  }
}
