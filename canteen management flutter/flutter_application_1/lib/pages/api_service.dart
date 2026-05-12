import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  ////////////////////////////////////////////////////////////
  /// 🌐 BASE URL (WORKS FOR BOTH EMULATOR + REAL DEVICE)
  ////////////////////////////////////////////////////////////

  // 🔥 Use your PC IP (works everywhere)
  // static const String baseUrl = "http://10.0.102.241:8000/api";
  static const String baseUrl = "http://192.168.0.105:8000/api";
  // static const String baseUrl = "http://10.106.138.3:8000/api";


  ////////////////////////////////////////////////////////////
  /// PUBLIC POST (NO AUTH) 🔥 IMPORTANT FOR LOGIN
  ////////////////////////////////////////////////////////////
  static Future<http.Response> publicPost(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    return http.post(
      Uri.parse("$baseUrl$endpoint"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );
  }

  ////////////////////////////////////////////////////////////
  /// REFRESH TOKEN
  ////////////////////////////////////////////////////////////
  static Future<String?> refreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    final refresh = prefs.getString("refresh");

    if (refresh == null) return null;

    final res = await http.post(
      Uri.parse("$baseUrl/token/refresh/"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"refresh": refresh}),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final newAccess = data["access"];

      await prefs.setString("access", newAccess);

      if (data.containsKey("refresh")) {
        await prefs.setString("refresh", data["refresh"]);
      }

      return newAccess;
    }

    await prefs.remove("access");
    await prefs.remove("refresh");
    return null;
  }

  ////////////////////////////////////////////////////////////
  /// HEADER BUILDER
  ////////////////////////////////////////////////////////////
  static Map<String, String> _headers(String token, {bool json = false}) {
    return {
      "Authorization": "Bearer $token",
      if (json) "Content-Type": "application/json",
    };
  }

  ////////////////////////////////////////////////////////////
  /// CORE AUTH REQUEST HANDLER
  ////////////////////////////////////////////////////////////
  static Future<http.Response> _withRefresh(
    Future<http.Response> Function(String token) request,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString("access");

    if (token == null) throw Exception("Not authenticated");

    http.Response res = await request(token);

    if (res.statusCode == 401) {
      final newToken = await refreshToken();

      if (newToken == null) {
        throw Exception("Session expired");
      }

      res = await request(newToken);
    }

    return res;
  }

  ////////////////////////////////////////////////////////////
  /// AUTH GET
  ////////////////////////////////////////////////////////////
  static Future<http.Response> get(String endpoint) {
    return _withRefresh(
      (token) => http.get(
        Uri.parse("$baseUrl$endpoint"),
        headers: _headers(token),
      ),
    );
  }

  ////////////////////////////////////////////////////////////
  /// AUTH POST
  ////////////////////////////////////////////////////////////
  static Future<http.Response> post(
    String endpoint,
    Map<String, dynamic> body,
  ) {
    return _withRefresh(
      (token) => http.post(
        Uri.parse("$baseUrl$endpoint"),
        headers: _headers(token, json: true),
        body: jsonEncode(body),
      ),
    );
  }

  ////////////////////////////////////////////////////////////
  /// AUTH PUT
  ////////////////////////////////////////////////////////////
  static Future<http.Response> put(
    String endpoint,
    Map<String, dynamic> body,
  ) {
    return _withRefresh(
      (token) => http.put(
        Uri.parse("$baseUrl$endpoint"),
        headers: _headers(token, json: true),
        body: jsonEncode(body),
      ),
    );
  }

  ////////////////////////////////////////////////////////////
  /// AUTH DELETE
  ////////////////////////////////////////////////////////////
  static Future<http.Response> delete(String endpoint) {
    return _withRefresh(
      (token) => http.delete(
        Uri.parse("$baseUrl$endpoint"),
        headers: _headers(token),
      ),
    );
  }

  ////////////////////////////////////////////////////////////
  /// AUTH PUT MULTIPART (FOR FILES/IMAGES)
  ////////////////////////////////////////////////////////////
  static Future<http.StreamedResponse> putMultipart(
    String endpoint,
    Map<String, String> fields,
    String fileKey,
    String? filePath,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString("access");

    if (token == null) throw Exception("Not authenticated");

    var request = http.MultipartRequest("PUT", Uri.parse("$baseUrl$endpoint"));
    request.headers["Authorization"] = "Bearer $token";
    request.fields.addAll(fields);

    if (filePath != null) {
      request.files.add(await http.MultipartFile.fromPath(fileKey, filePath));
    }

    return request.send();
  }
}