import 'package:getx_plus/get_connect/http/src/http/stub/file_decoder_stub.dart'
    if (dart.library.js_interop) 'package:getx_plus/get_connect/http/src/http/html/file_decoder_html.dart'
    if (dart.library.io) 'package:getx_plus/get_connect/http/src/http/io/file_decoder_io.dart';
import 'package:getx_plus/get_connect/http/src/request/getx_request.dart';

class MultipartFile {
  MultipartFile(
    dynamic data, {
    required this.filename,
    this.contentType = 'application/octet-stream',
  }) : _bytes = fileToBytes(data) {
    _length = _bytes.length;
    _stream = _bytes.toStream();
  }

  final List<int> _bytes;

  final String contentType;

  /// This stream will emit the file content of File.
  Stream<List<int>>? _stream;

  int? _length;

  Stream<List<int>>? get stream => _stream;

  int? get length => _length;

  final String filename;
}
