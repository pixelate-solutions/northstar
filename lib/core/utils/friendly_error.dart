String friendlyErrorMessage(Object error, {String? fallback}) {
  final raw = error.toString();
  final text = raw.startsWith('Exception: ')
      ? raw.substring('Exception: '.length)
      : raw;
  final lower = text.toLowerCase();

  if (_looksOffline(lower)) {
    return 'You appear to be offline. Reconnect to use this online feature.';
  }

  if (lower.contains('timeout') || lower.contains('timed out')) {
    return 'The connection timed out. Check your internet connection and try again.';
  }

  if (lower.contains('no session token') ||
      lower.contains('you must be signed in')) {
    return 'Reconnect and sign in again to use this online feature.';
  }

  return fallback ?? text;
}

String friendlyAgentError(Object error) {
  final message = friendlyErrorMessage(error);
  if (message != error.toString() && message.startsWith('You appear')) {
    return 'Trip creation needs internet. Reconnect and try again.';
  }
  return message;
}

bool _looksOffline(String lower) {
  return lower.contains('socketexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('nodename nor servname provided') ||
      lower.contains('network is unreachable') ||
      lower.contains('connection failed') ||
      lower.contains('connection refused') ||
      lower.contains('connection closed') ||
      lower.contains('clientexception with socketexception') ||
      lower.contains('xmlhttprequest error') ||
      lower.contains('internetconnectionunavailable') ||
      lower.contains('not connected to the internet') ||
      lower.contains('offline');
}
