import 'package:getx_plus/get_connect/http/src/http/interface/request_base.dart';
import 'package:getx_plus/get_connect/http/src/http/utils/body_decoder.dart';
import 'package:getx_plus/get_connect/http/src/request/getx_request.dart';
import 'package:getx_plus/get_connect/http/src/response/getx_response.dart';

typedef MockClientHandler = Future<GetxResponse> Function(GetxRequest request);

class MockClient extends IClient {
  /// The handler for than transforms request on response
  final MockClientHandler _handler;

  /// Creates a [MockClient] with a handler that receives [GetxRequest]s and sends
  /// [GetxResponse]s.
  MockClient(this._handler);

  @override
  Future<GetxResponse<T>> send<T>(GetxRequest<T> request) async {
    var requestBody = await request.bodyBytes.toBytes();
    var bodyBytes = requestBody.toStream();

    var response = await _handler(request);

    final stringBody = await bodyBytesToString(bodyBytes, response.headers!);

    var mimeType = response.headers!.containsKey('content-type')
        ? response.headers!['content-type']
        : '';

    final body = bodyDecoded<T>(
      request,
      stringBody,
      mimeType,
    );
    return GetxResponse(
      headers: response.headers,
      request: request,
      statusCode: response.statusCode,
      statusText: response.statusText,
      bodyBytes: bodyBytes,
      body: body,
      bodyString: stringBody,
    );
  }

  @override
  void close() {}
}
