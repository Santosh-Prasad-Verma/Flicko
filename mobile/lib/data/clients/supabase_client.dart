import 'dart:async';

/// Compatibility stub for legacy Supabase references during Azure transition.

class User {
  final String id;
  final String? email;
  final Map<String, dynamic>? userMetadata;
  User({required this.id, this.email, this.userMetadata});
}

class Session {
  final String accessToken;
  final User? user;
  Session({required this.accessToken, this.user});
}

class PostgrestException implements Exception {
  final String message;
  final String? code;
  final String? details;
  final String? hint;
  const PostgrestException({required this.message, this.code, this.details, this.hint});
  @override
  String toString() => 'PostgrestException: $message';
}

class AuthException implements Exception {
  final String message;
  final String? statusCode;
  const AuthException({required this.message, this.statusCode});
  @override
  String toString() => 'AuthException: $message';
}

enum OtpType { signup }

class SupabaseAuth {
  User? get currentUser => null;
  Session? get currentSession => null;
  Stream<AuthState> get onAuthStateChange => const Stream.empty();
  Future<AuthResponse> signInWithPassword({required String email, required String password}) async => AuthResponse();
  Future<AuthResponse> signUp({required String email, required String password, Map<String, dynamic>? data}) async => AuthResponse();
  Future<void> resetPasswordForEmail(String email, {String? redirectTo}) async {}
  Future<void> resend({required OtpType type, required String email}) async {}
  Future<void> signOut() async {}
  Future<bool> signInWithOAuth(OAuthProvider provider, {String? redirectTo, dynamic authScreenLaunchMode}) async => true;
  Future<AuthResponse> signInWithIdToken({required OAuthProvider provider, required String idToken}) async => AuthResponse();
}

class AuthResponse {
  final User? user;
  final Session? session;
  AuthResponse({this.user, this.session});
}

class AuthState {
  final AuthChangeEvent event;
  final Session? session;
  AuthState(this.event, this.session);
}

enum AuthChangeEvent { signedIn, signedOut, userUpdated, tokenRefreshed }
enum OAuthProvider { google, github, discord, apple }

class SupabaseStorage {
  SupabaseStorageBucket from(String bucket) => SupabaseStorageBucket(bucket);
}

class SupabaseStorageBucket {
  final String bucket;
  SupabaseStorageBucket(this.bucket);
  Future<String> upload(String path, dynamic file, {dynamic fileOptions}) async => '';
  Future<String> createSignedUrl(String path, int expiresIn) async => '';
  String getPublicUrl(String path) => '';
}

class FileOptions {
  final String? cacheControl;
  final bool upsert;
  const FileOptions({this.cacheControl, this.upsert = false});
}

class PresenceEntry {
  final Map<String, dynamic> payload;
  PresenceEntry(this.payload);
}

class PresenceState {
  final List<PresenceEntry> presences;
  PresenceState(this.presences);
}

class PostgresChangePayload {
  final dynamic eventType;
  final Map<String, dynamic> newRecord;
  final Map<String, dynamic> oldRecord;
  PostgresChangePayload({this.eventType, this.newRecord = const {}, this.oldRecord = const {}});
}

enum PostgresChangeFilterType { eq, neq, lt, lte, gt, gte }
enum ChannelResponse { ok, error }

class PostgresChangeFilter {
  final PostgresChangeFilterType type;
  final String column;
  final dynamic value;

  const PostgresChangeFilter({
    required this.type,
    required this.column,
    required this.value,
  });
}

class RealtimeChannelConfig {
  final bool ack;
  const RealtimeChannelConfig({this.ack = false});
}

class RealtimeChannel {
  RealtimeChannel onPresenceSync(Function(dynamic) cb) => this;
  RealtimeChannel onPresenceJoin(Function(dynamic) cb) => this;
  RealtimeChannel onPresenceLeave(Function(dynamic) cb) => this;
  RealtimeChannel onBroadcast({required String event, required Function(dynamic) callback}) => this;
  RealtimeChannel onPostgresChanges({
    required dynamic event,
    required String schema,
    String? table,
    dynamic filter,
    Function(PostgresChangePayload)? callback,
  }) => this;
  RealtimeChannel subscribe([Function(dynamic status, dynamic error)? callback]) => this;
  Future<void> track(Map<String, dynamic> state) async {}
  Future<ChannelResponse> sendBroadcastMessage({required String event, required Map<String, dynamic> payload}) async => ChannelResponse.ok;
  Future<void> unsubscribe() async {}
  List<PresenceState> presenceState() => [];
}

enum RealtimeSubscribeStatus { subscribed, channelError, closed, timedOut }
enum PostgresChangeEvent { all, insert, update, delete }

class PostgrestFilterBuilder implements Future<dynamic> {
  final dynamic _result;
  PostgrestFilterBuilder([this._result = const []]);

  PostgrestFilterBuilder select([String? columns]) => this;
  PostgrestFilterBuilder eq(String column, dynamic value) => this;
  PostgrestFilterBuilder neq(String column, dynamic value) => this;
  PostgrestFilterBuilder isFilter(String column, dynamic value) => this;
  PostgrestFilterBuilder lt(String column, dynamic value) => this;
  PostgrestFilterBuilder gt(String column, dynamic value) => this;
  PostgrestFilterBuilder gte(String column, dynamic value) => this;
  PostgrestFilterBuilder lte(String column, dynamic value) => this;
  PostgrestFilterBuilder ilike(String column, String pattern) => this;
  PostgrestFilterBuilder like(String column, String pattern) => this;
  PostgrestFilterBuilder contains(String column, dynamic value) => this;
  PostgrestFilterBuilder containedBy(String column, dynamic value) => this;
  PostgrestFilterBuilder filter(String column, String operator, dynamic value) => this;
  PostgrestFilterBuilder textSearch(String column, String query) => this;
  PostgrestFilterBuilder match(Map<String, dynamic> query) => this;
  PostgrestFilterBuilder inFilter(String column, List values) => this;
  PostgrestFilterBuilder or(String filters) => this;
  PostgrestFilterBuilder and(String filters) => this;
  PostgrestFilterBuilder not(String column, String operator, dynamic value) => this;
  PostgrestFilterBuilder order(String column, {bool ascending = true}) => this;
  PostgrestFilterBuilder limit(int count) => this;
  PostgrestFilterBuilder range(int from, int to) => this;

  Future<dynamic> single() async => {};
  Future<dynamic> maybeSingle() async => null;
  PostgrestFilterBuilder insert(dynamic values) => this;
  PostgrestFilterBuilder update(dynamic values) => this;
  PostgrestFilterBuilder upsert(dynamic values, {String? onConflict}) => this;
  PostgrestFilterBuilder delete() => this;
  PostgrestFilterBuilder rpc(String fn, {Map<String, dynamic>? params}) => this;

  @override
  Stream<dynamic> asStream() => Stream.value(_result);

  @override
  Future<dynamic> catchError(Function onError, {bool Function(Object error)? test}) =>
      Future<dynamic>.value(_result).catchError(onError, test: test);

  @override
  Future<R> then<R>(FutureOr<R> Function(dynamic value) onValue, {Function? onError}) =>
      Future<dynamic>.value(_result).then(onValue, onError: onError);

  @override
  Future<dynamic> timeout(Duration timeLimit, {FutureOr<Object?> Function()? onTimeout}) =>
      Future<dynamic>.value(_result).timeout(timeLimit, onTimeout: onTimeout);

  @override
  Future<dynamic> whenComplete(FutureOr<void> Function() action) =>
      Future.value(_result).whenComplete(action);
}

class SupabaseFunctions {
  Future<dynamic> invoke(String functionName, {Map<String, dynamic>? body}) async => {};
}

class SupabaseClient {
  final SupabaseAuth auth = SupabaseAuth();
  final SupabaseStorage storage = SupabaseStorage();
  final SupabaseFunctions functions = SupabaseFunctions();

  SupabaseClient([String? url, String? key]);

  PostgrestFilterBuilder from(String table) => PostgrestFilterBuilder();
  PostgrestFilterBuilder rpc(String fn, {Map<String, dynamic>? params}) => PostgrestFilterBuilder();
  RealtimeChannel channel(String name, {RealtimeChannelConfig? opts}) => RealtimeChannel();
}

class Supabase {
  static final Supabase instance = Supabase._();
  final SupabaseClient client = SupabaseClient();
  Supabase._();
  static Future<Supabase> initialize({required String url, required String anonKey}) async {
    return instance;
  }
}
