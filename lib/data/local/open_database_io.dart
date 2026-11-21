import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

/// iOS (and other native platforms): a database file in app documents.
Future<Database> openAppDatabase() async {
  final dir = await getApplicationDocumentsDirectory();
  return databaseFactoryIo.openDatabase(p.join(dir.path, 'setlist_tracker.db'));
}
