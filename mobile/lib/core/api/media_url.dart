import 'api_client.dart';

String? resolveMediaUrl(String? rawUrl) {
  final value = rawUrl?.trim();
  if (value == null || value.isEmpty) return null;

  if (value.startsWith('http://') || value.startsWith('https://')) {
    return value;
  }

  final apiUri = Uri.tryParse(baseUrl);
  if (apiUri == null || apiUri.scheme.isEmpty || apiUri.host.isEmpty) {
    return value;
  }

  final origin = '${apiUri.scheme}://${apiUri.host}'
      '${apiUri.hasPort ? ':${apiUri.port}' : ''}';
  if (value.startsWith('/')) {
    return '$origin$value';
  }
  return '$origin/$value';
}
