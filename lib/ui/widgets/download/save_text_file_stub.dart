/// Native builds have no browser download, so the caller copies instead.
Future<bool> saveTextFile(
  String fileName,
  String text,
  String mimeType,
) async => false;
