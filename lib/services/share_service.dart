import 'package:share_plus/share_plus.dart';

class ShareService {
  /// Opens the system share sheet with the produced file(s).
  /// The user picks WhatsApp/Instagram/etc. from the sheet.
  Future<void> shareFiles(List<String> paths) async {
    await Share.shareXFiles(paths.map((p) => XFile(p)).toList());
  }
}
