import 'dart:convert';
import 'package:shelf/shelf.dart';

Middleware errorHandler() {
  return (Handler innerHandler) {
    return (Request request) async {
      try {
        final response = await innerHandler(request);
        return response;
      } catch (error, stackTrace) {
        print(
            'Unhandled error on ${request.method} ${request.url}: $error\n$stackTrace');

        return Response.internalServerError(
          body: jsonEncode({
            'error': 'Internal Server Error',
            'statusCode': 500,
          }),
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
    };
  };
}
