import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api_client.dart';
import '../../ui/tokens.dart';
import 'identity_models.dart';

/// Gets a document file from the customer: a photo now, a photo from the phone, or a file (PDF).
/// Tests use a fake.
abstract class DocumentPicker {
  /// Null when the customer cancels.
  Future<PickedDocument?> pick(BuildContext context, {required String label});
}

/// The file types and size the server and the web page accept (U5).
const documentExtensions = ['jpg', 'jpeg', 'png', 'webp', 'pdf'];
const documentMaxBytes = 5 * 1024 * 1024;

/// Checks a picked file before sending it: the type by its name and the 5 MB limit, as on the web.
/// The app doesn't check what's inside; the team reviews every document (U5).
String? documentFileError(PickedDocument f) {
  final dot = f.name.lastIndexOf('.');
  final ext = dot < 0 ? '' : f.name.substring(dot + 1).toLowerCase();
  if (!documentExtensions.contains(ext)) return 'Choose a JPG, PNG, WEBP or PDF file.';
  if (f.bytes.length > documentMaxBytes) return 'That file is over 5 MB. Choose a smaller photo or file.';
  if (f.bytes.isEmpty) return 'That file is empty. Choose another one.';
  return null;
}

class DevicePicker implements DocumentPicker {
  DevicePicker({ImagePicker? images}) : _images = images ?? ImagePicker();
  final ImagePicker _images;
  static const _permissions = MethodChannel('com.tabitalpay/permissions');

  @override
  Future<PickedDocument?> pick(BuildContext context, {required String label}) async {
    final how = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Tp.surface,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Tp.s6, 0, Tp.s6, Tp.s2),
              child: Text(label, style: Theme.of(context).textTheme.titleMedium),
            ),
            ListTile(
              leading: const Icon(LucideIcons.camera),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(context).pop('camera'),
            ),
            ListTile(
              leading: const Icon(LucideIcons.image),
              title: const Text('Choose a photo'),
              onTap: () => Navigator.of(context).pop('gallery'),
            ),
            ListTile(
              leading: const Icon(LucideIcons.fileText),
              title: const Text('Choose a PDF or file'),
              onTap: () => Navigator.of(context).pop('file'),
            ),
            const SizedBox(height: Tp.s2),
          ],
        ),
      ),
    );
    switch (how) {
      case 'camera':
        // The app holds the camera permission (Smile ID), so Android needs it granted first
        final allowed = await _permissions.invokeMethod<bool>('camera').catchError((_) => false) ?? false;
        if (!allowed) {
          throw ApiException('Tabital needs the camera to photograph your document. Allow it in your phone settings.');
        }
        return _fromImage(await _images.pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 2400));
      case 'gallery':
        return _fromImage(await _images.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 2400));
      case 'file':
        final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: documentExtensions);
        if (files.isEmpty) return null;
        final f = files.first;
        return PickedDocument(name: f.name, bytes: await f.xFile.readAsBytes());
      default:
        return null;
    }
  }

  static Future<PickedDocument?> _fromImage(XFile? x) async =>
      x == null ? null : PickedDocument(name: x.name, bytes: await x.readAsBytes());
}
