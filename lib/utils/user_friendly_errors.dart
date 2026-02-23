import 'dart:async';
import 'dart:convert';
import 'dart:io';

String friendlyErrorFromResponse({
  required int statusCode,
  String? body,
  String? messageOverride,
}) {
  final sanitizedOverride = _sanitizeMessage(messageOverride);
  final extracted = sanitizedOverride ?? _sanitizeMessage(_extractMessage(body));
  if (extracted != null && extracted.isNotEmpty) {
    return extracted;
  }

  if (statusCode == 400) {
    return "We couldn't process that request. Please check your details and try again.";
  }
  if (statusCode == 401) {
    return "Your session has expired. Please log in again.";
  }
  if (statusCode == 403) {
    return "You do not have permission to do that.";
  }
  if (statusCode == 404) {
    return "Service not found. Please try again later.";
  }
  if (statusCode == 408) {
    return "Request timed out. Please try again.";
  }
  if (statusCode == 422) {
    return "Please check your input and try again.";
  }
  if (statusCode == 429) {
    return "Too many attempts. Please wait and try again.";
  }
  if (statusCode >= 500 && statusCode < 600) {
    return "Server error. Please try again later.";
  }

  return "Something went wrong. Please try again.";
}

String friendlyErrorFromException(Object error) {
  if (error is TimeoutException) {
    return "Request timed out. Please try again.";
  }
  if (error is SocketException) {
    return "No internet connection. Please check and try again.";
  }
  if (error is HandshakeException) {
    return "Secure connection failed. Please try again.";
  }
  return "Network error. Please try again.";
}

String? _extractMessage(String? body) {
  if (body == null || body.trim().isEmpty) {
    return null;
  }

  try {
    final decoded = jsonDecode(body);
    if (decoded is Map) {
      final message = decoded["message"] ??
          decoded["error"] ??
          decoded["detail"] ??
          decoded["title"];
      if (message != null) {
        return message.toString();
      }
      final errors = decoded["errors"];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        if (first is List && first.isNotEmpty) {
          return first.first.toString();
        }
        return first.toString();
      }
    }
    if (decoded is String) {
      return decoded;
    }
  } catch (_) {
    // ignore decode errors and fallback to raw body checks
  }

  if (body.length > 200) {
    return null;
  }
  return body;
}

String? _sanitizeMessage(String? message) {
  if (message == null) {
    return null;
  }
  final trimmed = message.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  final lowered = trimmed.toLowerCase();
  if (lowered.contains("ngrok") ||
      lowered.contains("tunnel") ||
      lowered.contains("handshake") ||
      lowered.contains("socketexception") ||
      lowered.contains("<!doctype") ||
      lowered.contains("<html") ||
      lowered.contains("bad gateway") ||
      lowered.contains("http error") ||
      lowered.contains("status code")) {
    return null;
  }

  return trimmed;
}
