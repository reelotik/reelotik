import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});

  @override
  State<AppLockScreen> createState() =>
      _AppLockScreenState();
}

class _AppLockScreenState
    extends State<AppLockScreen> {

  bool enabled = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final prefs =
        await SharedPreferences.getInstance();

    enabled =
        prefs.getBool("app_lock_enabled") ?? false;

    setState(() {});
  }

  Future<void> save(bool value) async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setBool(
      "app_lock_enabled",
      value,
    );

    setState(() {
      enabled = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("App Lock"),
      ),
      body: SwitchListTile(
        value: enabled,
        onChanged: save,
        title: const Text(
          "Enable App Lock",
        ),
      ),
    );
  }
}