import 'package:getx_plus/get_connect/http/src/request/getx_request.dart';
import 'package:getx_plus/get_connect/http/src/response/getx_response.dart';

/// Abstract interface of [HttpRequestImpl].
abstract class IClient {
  /// Sends an HTTP [GetxRequest].
  Future<GetxResponse<T>> send<T>(GetxRequest<T> request);

  /// Closes the [GetxRequest] and cleans up any resources associated with it.
  void close();

  /// Gets and sets the timeout.
  ///
  /// For mobile, this value will be applied for both connection and request
  /// timeout.
  ///
  /// For web, this value will be the request timeout.
  Duration? timeout;
}
