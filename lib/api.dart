import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';
import 'models.dart';
class ApiException implements Exception { final int status; final String message; const ApiException(this.status,this.message); @override String toString()=>message; }
class ApiClient {
  static const _tokenKey='auth_token',_userKey='auth_user',_pendingKey='pending_actions';
  final String baseUrl; ApiClient({this.baseUrl=AppConfig.apiBaseUrl});
  Future<SharedPreferences> get _prefs async=>SharedPreferences.getInstance();
  Future<Map<String,String>> _headers() async {final p=await _prefs;final t=p.getString(_tokenKey);return {'Accept':'application/json','Content-Type':'application/json',if(t!=null)'Authorization':'Bearer $t'};}
  Future<dynamic> _send(String method,String path,{Object? body,Map<String,String>? query}) async {
    final uri=Uri.parse('$baseUrl$path').replace(queryParameters:query);final h=await _headers();http.Response r;
    try {if(method=='GET'){r=await http.get(uri,headers:h).timeout(AppConfig.requestTimeout);}else if(method=='POST'){r=await http.post(uri,headers:h,body:body==null?null:jsonEncode(body)).timeout(AppConfig.requestTimeout);}else if(method=='PUT'){r=await http.put(uri,headers:h,body:body==null?null:jsonEncode(body)).timeout(AppConfig.requestTimeout);}else{r=await http.delete(uri,headers:h).timeout(AppConfig.requestTimeout);}}
    catch(_){throw const ApiException(0,'تعذر الاتصال بالخادم. تحقق من الإنترنت أو عنوان API.');}
    dynamic d;try{d=jsonDecode(r.body);}catch(_){d=r.body;}if(r.statusCode<200||r.statusCode>=300){throw ApiException(r.statusCode,d is Map?'${d['message']??'حدث خطأ في الخادم'}':'حدث خطأ في الخادم');}return d;
  }
  Future<Map<String,dynamic>> login(String email,String password) async {final d=Map<String,dynamic>.from(await _send('POST','/login',body:{'email':email,'password':password}));final p=await _prefs;await p.setString(_tokenKey,'${d['token']}');await p.setString(_userKey,jsonEncode(d['user']));return d;}
  Future<void> logout() async {try{await _send('POST','/logout');}catch(_){ }final p=await _prefs;await p.remove(_tokenKey);await p.remove(_userKey);}
  Future<bool> isLoggedIn() async=>(await _prefs).getString(_tokenKey)!=null;
  Future<SessionUser?> session() async {final raw=(await _prefs).getString(_userKey);return raw==null?null:SessionUser.fromJson(jsonDecode(raw));}
  Future<Map<String,dynamic>> summary() async=>Map<String,dynamic>.from(await _send('GET','/reports/summary'));
  Future<Map<String,dynamic>> operationalMap() async=>Map<String,dynamic>.from(await _send('GET','/map/operational'));
  Future<ApiList> list(String endpoint) async {final d=await _send('GET',endpoint);final raw=d is List?d:(d is Map&&d['data'] is List?d['data']:(d is Map&&d['items'] is List?d['items']:[]));final a=(raw as List).map((e)=>Map<String,dynamic>.from(e)).toList();return ApiList(a,d is Map?(d['total'] as num?)?.toInt()??a.length:a.length);}
  Future<Map<String,dynamic>> create(String endpoint,Map<String,dynamic> body) async {try{return Map<String,dynamic>.from(await _send('POST',endpoint,body:body));}on ApiException catch(e){if(e.status!=0)rethrow;final p=await _prefs;final q=p.getStringList(_pendingKey)??[];q.add(jsonEncode({'method':'POST','endpoint':endpoint,'body':body}));await p.setStringList(_pendingKey,q);return {'queued':true};}}
  Future<int> pendingCount() async=>(await _prefs).getStringList(_pendingKey)?.length??0;
  Future<int> syncPending() async {final p=await _prefs;final old=p.getStringList(_pendingKey)??[];final keep=<String>[];var done=0;for(final raw in old){final a=jsonDecode(raw);try{await _send(a['method'],a['endpoint'],body:a['body']);done++;}catch(_){keep.add(raw);}}await p.setStringList(_pendingKey,keep);return done;}
}