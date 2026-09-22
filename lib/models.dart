class SessionUser {
  final int id; final String name; final String email; final List<String> roles; final List<String> permissions;
  SessionUser({required this.id,required this.name,required this.email,this.roles=const [],this.permissions=const []});
  factory SessionUser.fromJson(Map<String,dynamic> j)=>SessionUser(id:(j['id'] as num?)?.toInt()??0,name:'\${j['name']??''}',email:'\${j['email']??''}',roles:(j['roles'] as List? ?? []).map((e)=>'$e').toList(),permissions:(j['permissions'] as List? ?? []).map((e)=>'$e').toList());
}
class ApiList { final List<Map<String,dynamic>> items; final int total; ApiList(this.items,this.total); }