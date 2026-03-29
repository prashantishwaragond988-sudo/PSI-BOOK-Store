import "package:flutter/foundation.dart";

const String _webBase = String.fromEnvironment(
  "BACKEND_BASE_URL_WEB",
  defaultValue: "http://127.0.0.1:5000",
);
const String _mobileBase = String.fromEnvironment(
  "BACKEND_BASE_URL_MOBILE",
  defaultValue: "http://10.0.2.2:5000",
);

String resolveBookImageUrl(String raw) {
  final value = _normalizeRaw(raw);
  if (value.isEmpty) {
    return "";
  }

  if (value.startsWith("http://") || value.startsWith("https://")) {
    return value;
  }

  final base = kIsWeb ? _webBase : _mobileBase;

  final assetsRelative = _relativeAfter(value, "assets/books/");
  if (assetsRelative != null && assetsRelative.trim().isNotEmpty) {
    return "$base/book-assets/${_encodePath(assetsRelative)}";
  }

  final bookAssetsRelative = _relativeAfter(value, "book-assets/");
  if (bookAssetsRelative != null && bookAssetsRelative.trim().isNotEmpty) {
    return "$base/book-assets/${_encodePath(bookAssetsRelative)}";
  }

  final staticRelative = _relativeAfter(value, "static/");
  if (staticRelative != null && staticRelative.trim().isNotEmpty) {
    return "$base/static/${_encodePath(staticRelative)}";
  }

  final filename = _lastSegment(value);
  if (filename.isEmpty) {
    return "$base/static/p1.jpg";
  }
  return "$base/static/${_encodePath(filename)}";
}

String? resolveBookImageAsset(String raw) {
  final value = _normalizeRaw(raw);
  if (value.isEmpty) {
    return null;
  }

  if (value.startsWith("http://") || value.startsWith("https://")) {
    return null;
  }

  final assetsRelative = _relativeAfter(value, "assets/books/");
  if (assetsRelative != null && assetsRelative.trim().isNotEmpty) {
    return "assets/books/${_normalizeAssetPath(assetsRelative)}";
  }

  if (_relativeAfter(value, "book-assets/") != null ||
      _relativeAfter(value, "static/") != null) {
    return null;
  }

  final filename = _lastSegment(value);
  if (filename.isEmpty) {
    return null;
  }
  return "assets/books/$filename";
}

String _normalizeRaw(String raw) {
  var value = raw.trim();
  value = value.replaceAll("\\", "/");
  value = value.replaceFirst("./", "");
  return value;
}

String? _relativeAfter(String source, String keyLower) {
  final lower = source.toLowerCase();
  final idx = lower.indexOf(keyLower);
  if (idx == -1) {
    return null;
  }
  final start = idx + keyLower.length;
  if (start >= source.length) {
    return "";
  }
  return source.substring(start);
}

String _lastSegment(String value) {
  final segments = value.split("/").where((part) => part.trim().isNotEmpty);
  if (segments.isEmpty) {
    return "";
  }
  return segments.last.trim();
}

String _encodePath(String path) {
  final parts = path.split("/").where((part) => part.trim().isNotEmpty);
  return parts.map(_encodeSegment).join("/");
}

String _encodeSegment(String segment) {
  try {
    return Uri.encodeComponent(Uri.decodeComponent(segment));
  } catch (_) {
    return Uri.encodeComponent(segment);
  }
}

String _normalizeAssetPath(String relative) {
  return relative
      .replaceAll("\\", "/")
      .split("/")
      .where((part) => part.trim().isNotEmpty)
      .join("/");
}
