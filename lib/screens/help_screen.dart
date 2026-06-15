import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  Future<void> _launchEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'support@reelotik.com',
      query: 'subject=App Support Required&body=Please describe your issue here...',
    );
    if (!await launchUrl(emailLaunchUri)) {
      debugPrint('Could not launch email');
    }
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xff1f2937),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("Help", style: TextStyle(color: Colors.white)),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.info, color: Color(0xff25D366)),
            title: const Text("About Reelotik", style: TextStyle(color: Colors.white)),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => const AlertDialog(
                  backgroundColor: Color(0xff1f2937),
                  title: Text("Reelotik", style: TextStyle(color: Colors.white)),
                  content: Text("Version 1.0.0\nSecure and fast messaging app.", style: TextStyle(color: Colors.white70)),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.contact_support, color: Color(0xff25D366)),
            title: const Text("Contact Support", style: TextStyle(color: Colors.white)),
            onTap: _launchEmail,
          ),
          ListTile(
            leading: const Icon(Icons.description, color: Color(0xff25D366)),
            title: const Text("Terms & Conditions", style: TextStyle(color: Colors.white)),
            onTap: () => _launchURL("https://yourwebsite.com/terms"), // Replace with actual URL
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip, color: Color(0xff25D366)),
            title: const Text("Privacy Policy", style: TextStyle(color: Colors.white)),
            onTap: () => _launchURL("https://yourwebsite.com/privacy"), // Replace with actual URL
          ),
        ],
      ),
    );
  }
}