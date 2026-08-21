import 'package:mobile/data/clients/api_client.dart';
import 'package:mobile/data/models/payment_method_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final paymentServiceProvider = Provider((ref) => PaymentService(Supabase.instance.client));

class PaymentService {
  final SupabaseClient _client;

  PaymentService(this._client);

  Future<List<PaymentMethodModel>> getPaymentMethods() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    
    final response = await _client.from('payment_methods')
        .select()
        .eq('user_id', user.id)
        .order('is_default', ascending: false)
        .order('created_at', ascending: false);
    
    return (response as List).map((json) => PaymentMethodModel.fromJson(json)).toList();
  }
}
