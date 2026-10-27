import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseClient get supabase => Supabase.instance.client;

/// Bangladeshi mobile number: 01XXXXXXXXX (11 digit). +880 / 880 prefix o cholbe.
String? normalizePhone(String input) {
  var d = input.replaceAll(RegExp(r'[^0-9]'), '');
  if (d.startsWith('880')) d = '0${d.substring(3)}';
  if (RegExp(r'^01[3-9][0-9]{8}$').hasMatch(d)) return d;
  return null;
}

/// Supabase er phone auth e SMS provider lage (paid). Tai phone number ke
/// ekta internal email banai: 01712345678@blooddonor.app
/// Password Supabase Auth nijei hash kore, amader table e password thake na.
String phoneToEmail(String normalizedPhone) => '$normalizedPhone@blooddonor.app';

void showMsg(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

String friendlyError(Object e) {
  if (e is AuthException) return e.message;
  if (e is PostgrestException) return e.message;
  return e.toString();
}
