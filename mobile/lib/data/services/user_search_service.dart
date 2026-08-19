import 'package:mobile/data/clients/supabase_client.dart';
import 'package:mobile/data/models/user_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

final userSearchServiceProvider = Provider((ref) => UserSearchService(Supabase.instance.client));

final userSearchQueryProvider = StateProvider<String>((ref) => '');

final userSearchResultsProvider = FutureProvider.autoDispose<List<UserModel>>((ref) async {
  final query = ref.watch(userSearchQueryProvider);
  if (query.isEmpty) return [];
  
  final service = ref.watch(userSearchServiceProvider);
  return await service.searchUsers(query);
});

class UserSearchService {
  final SupabaseClient _client;

  UserSearchService(this._client);

  Future<List<UserModel>> searchUsers(String query) async {
    final response = await _client
        .from('profiles')
        .select()
        .ilike('username', '%$query%')
        .limit(20);
        
    return (response as List).map((json) => UserModel.fromJson(json)).toList();
  }
}
