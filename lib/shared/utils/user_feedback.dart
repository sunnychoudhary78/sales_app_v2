/// Strips wrapper prefixes from thrown errors for UI display.
String formatUserFacingError(Object error) {
  var msg = error.toString().trim();
  msg = msg.replaceFirst(RegExp(r'^Exception:\s*'), '');
  msg = msg.replaceFirst(RegExp(r'^Error:\s*'), '');
  return msg.trim();
}
