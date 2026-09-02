import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'api_exception.dart';

typedef JsonMap = Map<String, dynamic>;

const String _authorization = 'Authorization';

String _bearer(String token) => 'Bearer $token';

class ApiClient {
  ApiClient({required Uri baseUrl})
    : _dio = Dio(
        BaseOptions(
          baseUrl: '$baseUrl/api',
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          contentType: Headers.jsonContentType,
          // The API binds a list from a repeated name, which is not the
          // bracketed form dio reaches for on its own.
          listFormat: ListFormat.multi,
        ),
      ) {
    // The session interceptor is added before the failure one because that one
    // rejects, which ends the chain: put it second and no 401 is ever seen.
    _dio.interceptors.add(_TokenInterceptor(() => token));
    _dio.interceptors.add(
      _SessionInterceptor(() => token, _reportUnauthorized),
    );
    _dio.interceptors.add(_FailureInterceptor());
  }

  final Dio _dio;

  String? _token;
  int _tokenGeneration = 0;

  void Function()? onUnauthorized;

  String? get token => _token;

  int get tokenGeneration => _tokenGeneration;

  set token(String? value) {
    _token = value;
    _tokenGeneration++;
  }

  Future<JsonMap> get(String path, {JsonMap? query}) async =>
      _asObject(await _request('GET', path, query: query));

  Future<JsonMap> post(String path, {Object? body}) async =>
      _asObject(await _request('POST', path, body: body));

  Future<void> postNoContent(String path, {Object? body}) async {
    await _request('POST', path, body: body);
  }

  Future<JsonMap> put(String path, {Object? body}) async =>
      _asObject(await _request('PUT', path, body: body));

  Future<void> putNoContent(String path, {Object? body}) async {
    await _request('PUT', path, body: body);
  }

  // The boundary is only known once the body is built, so dio writes the
  // content type itself and the one on the client is left alone.
  Future<JsonMap> upload(
    String path, {
    required String field,
    required String name,
    required Uint8List bytes,
    required String contentType,
  }) async => _asObject(
    await _request(
      'POST',
      path,
      body: FormData.fromMap(<String, dynamic>{
        field: MultipartFile.fromBytes(
          bytes,
          filename: name,
          contentType: DioMediaType.parse(contentType),
        ),
      }),
    ),
  );

  Future<List<dynamic>> putList(String path, {Object? body}) async =>
      _asArray(await _request('PUT', path, body: body));

  Future<void> delete(String path) async {
    await _request('DELETE', path);
  }

  Future<Uint8List> bytes(String path) async {
    final Response<dynamic> response = await _request(
      'GET',
      path,
      responseType: ResponseType.bytes,
    );

    final dynamic body = response.data;
    if (body is Uint8List) {
      return body;
    }
    if (body is List<int>) {
      return Uint8List.fromList(body);
    }

    throw ApiException(
      message: 'The API answered ${response.statusCode} without an image.',
      statusCode: response.statusCode,
    );
  }

  void close() => _dio.close();

  void _reportUnauthorized() => onUnauthorized?.call();

  Future<Response<dynamic>> _request(
    String method,
    String path, {
    Object? body,
    JsonMap? query,
    ResponseType? responseType,
  }) async {
    try {
      return await _dio.request<dynamic>(
        path,
        data: body,
        queryParameters: query,
        options: Options(method: method, responseType: responseType),
      );
    } on DioException catch (failure) {
      final Object? translated = failure.error;

      throw translated is ApiException
          ? translated
          : ApiException(message: failure.message ?? _unexpectedMessage);
    }
  }

  static const String _unexpectedMessage =
      'The request could not be completed.';

  static List<dynamic> _asArray(Response<dynamic> response) {
    final dynamic body = response.data;
    if (body is List) {
      return body;
    }

    throw ApiException(
      message:
          'The API answered ${response.statusCode} without a list to read.',
      statusCode: response.statusCode,
    );
  }

  static JsonMap _asObject(Response<dynamic> response) {
    final dynamic body = response.data;
    if (body is JsonMap) {
      return body;
    }

    throw ApiException(
      message:
          'The API answered ${response.statusCode} without a body to read.',
      statusCode: response.statusCode,
    );
  }
}

class _TokenInterceptor extends Interceptor {
  _TokenInterceptor(this._token);

  final String? Function() _token;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final String? token = _token();
    if (token != null) {
      options.headers[_authorization] = _bearer(token);
    }

    handler.next(options);
  }
}

class _SessionInterceptor extends Interceptor {
  _SessionInterceptor(this._token, this._onUnauthorized);

  final String? Function() _token;
  final void Function() _onUnauthorized;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401 &&
        _carriedTheTokenInForce(err.requestOptions)) {
      _onUnauthorized();
    }

    handler.next(err);
  }

  // The token this answer is about is the one its own request carried, not the
  // one held now: a refused sign in carries none, and a late answer to a call
  // made before the current sign in would otherwise end a healthy session.
  bool _carriedTheTokenInForce(RequestOptions options) {
    final String? token = _token();

    return token != null && options.headers[_authorization] == _bearer(token);
  }
}

class _FailureInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: _translate(err),
      ),
    );
  }

  static ApiException _translate(DioException failure) {
    final Response<dynamic>? response = failure.response;
    final dynamic body = response?.data;

    if (body is JsonMap && body.containsKey('message')) {
      return ApiException.fromBody(response?.statusCode, body);
    }

    return ApiException(
      message: _messageFor(failure),
      statusCode: response?.statusCode,
    );
  }

  static String _messageFor(DioException failure) {
    final String address = failure.requestOptions.baseUrl;

    return switch (failure.type) {
      DioExceptionType.connectionError || DioExceptionType.connectionTimeout =>
        'The API at $address could not be reached. Check that it is running.',
      DioExceptionType.sendTimeout || DioExceptionType.receiveTimeout =>
        'The API at $address did not answer in time.',
      _ =>
        failure.response == null
            ? 'The API at $address could not be reached. Check that it is running.'
            : 'The API answered ${failure.response?.statusCode} and nothing more.',
    };
  }
}
