import 'dart:convert';
import 'package:crypto/crypto.dart';

String hashText(String input) {
  final bytes = utf8.encode(input.trim());
  final digest = sha256.convert(bytes);
  return digest.toString();
}
