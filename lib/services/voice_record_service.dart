import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class VoiceRecordService {
  static final AudioRecorder recorder =
      AudioRecorder();

  static Future<String?> start() async {
    final dir =
        await getApplicationDocumentsDirectory();

    final path =
        "${dir.path}/${DateTime.now().millisecondsSinceEpoch}.m4a";

    await recorder.start(
      const RecordConfig(),
      path: path,
    );

    return path;
  }

  static Future<String?> stop() async {
    return await recorder.stop();
  }
}