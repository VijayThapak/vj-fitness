/// Phone vs browser differences live behind this one import.
///
/// On Android/iOS, data and photos are files in the app's folder.
/// In the browser, they are kept in the browser's local storage.
export 'platform_io.dart' if (dart.library.js_interop) 'platform_web.dart';
