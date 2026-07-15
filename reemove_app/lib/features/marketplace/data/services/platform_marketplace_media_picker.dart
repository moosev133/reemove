import 'package:image_picker/image_picker.dart';

import '../../domain/services/marketplace_media_picker.dart';

class PlatformMarketplaceMediaPicker implements MarketplaceMediaPicker {
  PlatformMarketplaceMediaPicker(this._picker);

  final ImagePicker _picker;

  @override
  Future<List<String>> pickImages({int limit = 8}) async {
    final List<XFile> files = await _picker.pickMultiImage(
      imageQuality: 90,
      limit: limit.clamp(1, 8).toInt(),
    );
    return files.map((XFile file) => file.path).toList(growable: false);
  }
}
