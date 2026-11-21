/// Native platforms make normal HTTP requests, so JSONP is never needed.
Future<String> fetchJsonp(Uri uri) =>
    Future.error(UnsupportedError('JSONP is only used on web'));
