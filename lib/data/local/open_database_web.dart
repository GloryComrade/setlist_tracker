import 'package:sembast_web/sembast_web.dart';

/// Web: the browser's IndexedDB.
Future<Database> openAppDatabase() =>
    databaseFactoryWeb.openDatabase('setlist_tracker');
