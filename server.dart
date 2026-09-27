import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_static/shelf_static.dart';

// Permissive local originsf
const _allowedOrigins = {
  'http://localhost:51328',
  'http://127.0.0.1:51328',
  'http://localhost:8080',
};

Middleware corsMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      final origin = request.headers['origin'];

      if (request.method == 'OPTIONS') {
        return Response.ok(
          '',
          headers: {
            'Access-Control-Allow-Origin': origin ?? '*',
            'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
            'Access-Control-Allow-Headers':
                'Origin, Content-Type, Accept, Authorization, X-Requested-With',
            'Access-Control-Max-Age': '3600',
            'Vary': 'Origin',
          },
        );
      }

      final response = await innerHandler(request);

      return response.change(
        headers: {
          ...response.headers,
          'Access-Control-Allow-Origin': origin ?? '*',
          'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
          'Access-Control-Allow-Headers':
              'Origin, Content-Type, Accept, Authorization, X-Requested-With',
          'Vary': 'Origin',
        },
      );
    };
  };
}

void main() async {
  final targetDir = 'build/web';

  if (!Directory(targetDir).existsSync()) {
    print('Error: The directory "$targetDir" does not exist.');
    print('Please run "flutter build web" first to generate the web assets.');
    return;
  }

  // Handle static assets
  final staticHandler = createStaticHandler(
    targetDir,
    defaultDocument: 'index.html',
  );

  // Router handling both files and SPA Fallback routing
  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsMiddleware())
      .addHandler((request) async {
        final response = await staticHandler(request);

        // If the file is not found (404), fallback to index.html for Flutter routing
        if (response.statusCode == 404) {
          final indexFile = File('$targetDir/index.html');
          if (indexFile.existsSync()) {
            final bytes = await indexFile.readAsBytes();
            return Response.ok(
              bytes,
              headers: {
                'content-type': 'text/html',
                'cache-control': 'no-store, no-cache, must-revalidate',
              },
            );
          }
        }
        return response;
      });

  final server = await io.serve(handler, 'localhost', 51328);
  print('Server successfully running on http://localhost:${server.port}');
}
