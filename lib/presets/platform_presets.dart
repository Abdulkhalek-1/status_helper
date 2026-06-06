/// A target app's status constraints. v1 only models the length limit;
/// the compatible codecs (H.264/AAC in MP4) are the same across targets
/// and live in compatibility.dart.
class Preset {
  final String id;
  final String displayName;
  final Duration maxDuration;

  const Preset({
    required this.id,
    required this.displayName,
    required this.maxDuration,
  });
}

const List<Preset> kPresets = [
  Preset(id: 'whatsapp', displayName: 'WhatsApp', maxDuration: Duration(seconds: 90)),
  Preset(id: 'instagram', displayName: 'Instagram', maxDuration: Duration(seconds: 60)),
  Preset(id: 'facebook', displayName: 'Facebook', maxDuration: Duration(seconds: 90)),
  Preset(id: 'telegram', displayName: 'Telegram', maxDuration: Duration(seconds: 60)),
];

const Preset kDefaultPreset = Preset(id: 'whatsapp', displayName: 'WhatsApp', maxDuration: Duration(seconds: 90));
