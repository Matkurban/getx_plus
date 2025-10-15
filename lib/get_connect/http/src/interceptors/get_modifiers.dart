import 'dart:async';

import 'package:getx_plus/get_connect/http/src/request/getx_request.dart';
import 'package:getx_plus/get_connect/http/src/response/getx_response.dart';

typedef RequestModifier<T> = FutureOr<GetxRequest<T>> Function(
    GetxRequest<T?> request);

typedef ResponseModifier<T> = FutureOr Function(
    GetxRequest<T?> request, GetxResponse<T?> response);

typedef HandlerExecute<T> = Future<GetxRequest<T>> Function();

class GetModifier<S> {
  final _requestModifiers = <RequestModifier>[];
  final _responseModifiers = <ResponseModifier>[];
  RequestModifier? authenticator;

  void addRequestModifier<T>(RequestModifier<T> interceptor) {
    _requestModifiers.add(interceptor as RequestModifier);
  }

  void removeRequestModifier<T>(RequestModifier<T> interceptor) {
    _requestModifiers.remove(interceptor);
  }

  void addResponseModifier<T>(ResponseModifier<T> interceptor) {
    _responseModifiers.add(interceptor as ResponseModifier);
  }

  void removeResponseModifier<T>(ResponseModifier<T> interceptor) {
    _requestModifiers.remove(interceptor);
  }

  Future<GetxRequest<T>> modifyRequest<T>(GetxRequest<T> request) async {
    var newRequest = request;
    if (_requestModifiers.isNotEmpty) {
      for (var interceptor in _requestModifiers) {
        newRequest = await interceptor(newRequest) as GetxRequest<T>;
      }
    }

    return newRequest;
  }

  Future<GetxResponse<T>> modifyResponse<T>(
      GetxRequest<T> request, GetxResponse<T> response) async {
    var newResponse = response;
    if (_responseModifiers.isNotEmpty) {
      for (var interceptor in _responseModifiers) {
        newResponse =
            await interceptor(request, newResponse) as GetxResponse<T>;
      }
    }

    return newResponse;
  }
}
