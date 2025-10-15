import 'package:getx_plus/get_connect/http/src/certificates/certificates.dart';
import 'package:getx_plus/get_connect/http/src/http/interface/request_base.dart';
import 'package:getx_plus/get_connect/http/src/request/getx_request.dart';
import 'package:getx_plus/get_connect/http/src/response/getx_response.dart';

class HttpRequestImpl extends IClient {
  HttpRequestImpl({
    bool allowAutoSignedCert = true,
    List<TrustedCertificate>? trustedCertificates,
    bool withCredentials = false,
    String Function(Uri url)? findProxy,
  });
  @override
  void close() {}

  @override
  Future<GetxResponse<T>> send<T>(GetxRequest<T> request) {
    throw UnimplementedError();
  }
}
