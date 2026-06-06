import 'package:file_picker/file_picker.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

class FileService {
  /// Opens the system picker; returns the chosen video path or null.
  Future<String?> pickVideo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video);
    return result?.files.single.path;
  }

  /// A private working directory for intermediate outputs.
  Future<String> workingDir() async {
    final dir = await getTemporaryDirectory();
    return dir.path;
  }

  /// Saves a produced video file to the public gallery.
  /// Throws if permission is denied (caller falls back to share-only).
  Future<void> saveToGallery(String path) async {
    await Gal.putVideo(path, album: 'StatusHelper');
  }

  /// Whether gallery access is currently granted.
  Future<bool> hasGalleryAccess() => Gal.hasAccess();

  /// Requests gallery access; returns whether it was granted.
  Future<bool> requestGalleryAccess() => Gal.requestAccess();
}
