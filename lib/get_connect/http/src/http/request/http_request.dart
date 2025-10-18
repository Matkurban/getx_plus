import 'package:getx_plus/get_connect/http/src/certificates/certificates.dart';
import 'package:getx_plus/get_connect/http/src/http/stub/http_request_stub.dart'
    if (dart.library.js_interop) 'package:getx_plus/get_connect/http/src/http/html/http_request_html.dart'
    if (dart.library.io) 'package:getx_plus/get_connect/http/src/http/io/http_request_io.dart';

HttpRequestImpl createHttp({
  bool allowAutoSignedCert = true,
  List<TrustedCertificate>? trustedCertificates,
  bool withCredentials = false,
  String Function(Uri url)? findProxy,
}) {
  return HttpRequestImpl(
    allowAutoSignedCert: allowAutoSignedCert,
    trustedCertificates: trustedCertificates,
    withCredentials: withCredentials,
    findProxy: findProxy,
  );
}
