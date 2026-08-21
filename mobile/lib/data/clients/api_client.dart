import 'dart:async';
import 'package:mobile/data/models/auth_user.dart';

export 'package:mobile/data/models/auth_user.dart';

class Session {
  final String accessToken;
  final AuthUser? user;
  Session({required this.accessToken, this.user});
}

class ApiException implements Exception {
  final String message;
  final String? code;
  final String? details;
  final String? hint;
  const ApiException({required this.message, this.code, this.details, this.hint});
  @override
  String toString() => 'ApiException: $message';
}

typedef PostgrestException = ApiException;

class AuthException implements Exception {
  final String message;
  final String? statusCode;
  const AuthException({required this.message, this.statusCode});
  @override
  String toString() => 'AuthException: $message';
}

enum OtpType { signup }

class ApiAuth {
  AuthUser? get currentUser => null;
  Session? get currentSession => null;
  Stream<dynamic> get onAuthStateChange => const Stream.empty();
  Future<dynamic> signInWithPassword({required String email, required String password}) async => null;
  Future<dynamic> signUp({required String email, required String password, Map<String, dynamic>? data}) async => null;
  Future<void> resetPasswordForEmail(String email, {String? redirectTo}) async {}
  Future<void> resend({required OtpType type, required String email}) async {}
  Future<void> signOut() async {}
  Future<bool> signInWithOAuth(dynamic provider, {String? redirectTo, dynamic authScreenLaunchMode}) async => true;
  Future<dynamic> signInWithIdToken({required dynamic provider, required String idToken}) async => null;
}

typedef SupabaseAuth = ApiAuth;

class ApiStorage {
  ApiStorageBucket from(String bucket) => ApiStorageBucket(bucket);
}

typedef SupabaseStorage = ApiStorage;

class ApiStorageBucket {
  final String bucket;
  ApiStorageBucket(this.bucket);
  Future<String> upload(String path, dynamic file, {dynamic fileOptions}) async => '';
  Future<String> createSignedUrl(String path, int expiresIn) async => '';
  String getPublicUrl(String path) => '';
}

typedef SupabaseStorageBucket = ApiStorageBucket;

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

class RealtimeChangePayload {
  final dynamic eventType;
  final Map<String, dynamic> newRecord;
  final Map<String, dynamic> oldRecord;
  RealtimeChangePayload({this.eventType, this.newRecord = const {}, this.oldRecord = const {}});
}

typedef PostgresChangePayload = RealtimeChangePayload;

enum RealtimeChangeFilterType { eq, neq, lt, lte, gt, gte }
typedef PostgresChangeFilterType = RealtimeChangeFilterType;

enum ChannelResponse { ok, error }

class RealtimeChangeFilter {
  final RealtimeChangeFilterType type;
  final String column;
  final dynamic value;

  const RealtimeChangeFilter({
    required this.type,
    required this.column,
    required this.value,
  });
}

typedef PostgresChangeFilter = RealtimeChangeFilter;

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
    Function(RealtimeChangePayload)? callback,
  }) => this;
  RealtimeChannel subscribe([Function(dynamic status, dynamic error)? callback]) => this;
  Future<void> track(Map<String, dynamic> state) async {}
  Future<ChannelResponse> sendBroadcastMessage({required String event, required Map<String, dynamic> payload}) async => ChannelResponse.ok;
  Future<void> unsubscribe() async {}
  List<PresenceState> presenceState() => [];
}

enum RealtimeSubscribeStatus { subscribed, channelError, closed, timedOut }
enum RealtimeChangeEvent { all, insert, update, delete }
typedef PostgresChangeEvent = RealtimeChangeEvent;

class ApiFilterBuilder implements Future<dynamic> {
  final dynamic _result;
  ApiFilterBuilder([this._result = const []]);

  ApiFilterBuilder select([String? columns]) => this;
  ApiFilterBuilder eq(String column, dynamic value) => this;
  ApiFilterBuilder neq(String column, dynamic value) => this;
  ApiFilterBuilder isFilter(String column, dynamic value) => this;
  ApiFilterBuilder lt(String column, dynamic value) => this;
  ApiFilterBuilder gt(String column, dynamic value) => this;
  ApiFilterBuilder gte(String column, dynamic value) => this;
  ApiFilterBuilder lte(String column, dynamic value) => this;
  ApiFilterBuilder ilike(String column, String pattern) => this;
  ApiFilterBuilder like(String column, String pattern) => this;
  ApiFilterBuilder contains(String column, dynamic value) => this;
  ApiFilterBuilder containedBy(String column, dynamic value) => this;
  ApiFilterBuilder filter(String column, String operator, dynamic value) => this;
  ApiFilterBuilder textSearch(String column, String query) => this;
  ApiFilterBuilder match(Map<String, dynamic> query) => this;
  ApiFilterBuilder inFilter(String column, List values) => this;
  ApiFilterBuilder or(String filters) => this;
  ApiFilterBuilder and(String filters) => this;
  ApiFilterBuilder not(String column, String operator, dynamic value) => this;
  ApiFilterBuilder order(String column, {bool ascending = true}) => this;
  ApiFilterBuilder limit(int count) => this;
  ApiFilterBuilder range(int from, int to) => this;

  Future<dynamic> single() async => {};
  Future<dynamic> maybeSingle() async => null;
  ApiFilterBuilder insert(dynamic values) => this;
  ApiFilterBuilder update(dynamic values) => this;
  ApiFilterBuilder upsert(dynamic values, {String? onConflict}) => this;
  ApiFilterBuilder delete() => this;
  ApiFilterBuilder rpc(String fn, {Map<String, dynamic>? params}) => this;

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

typedef PostgrestFilterBuilder = ApiFilterBuilder;

class ApiFunctions {
  Future<dynamic> invoke(String functionName, {Map<String, dynamic>? body}) async => {};
}

typedef SupabaseFunctions = ApiFunctions;

class ApiClient {
  final ApiAuth auth = ApiAuth();
  final ApiStorage storage = ApiStorage();
  final ApiFunctions functions = ApiFunctions();

  ApiClient([String? url, String? key]);

  ApiFilterBuilder from(String table) => ApiFilterBuilder();
  ApiFilterBuilder rpc(String fn, {Map<String, dynamic>? params}) => ApiFilterBuilder();
  RealtimeChannel channel(String name, {RealtimeChannelConfig? opts}) => RealtimeChannel();
  Future<String> removeChannel(RealtimeChannel channel) async => 'ok';
  Future<List<String>> removeAllChannels() async => [];
}

typedef SupabaseClient = ApiClient;

class FlickoApi {
  static final FlickoApi instance = FlickoApi._();
  final ApiClient client = ApiClient();
  FlickoApi._();
  static Future<FlickoApi> initialize({String? url, String? anonKey}) async {
    return instance;
  }
}

typedef Supabase = FlickoApi;
