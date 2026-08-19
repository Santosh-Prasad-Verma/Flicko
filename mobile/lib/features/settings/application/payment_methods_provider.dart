import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/data/clients/supabase_client.dart';
import 'package:mobile/data/models/payment_method_model.dart';

final paymentMethodsProvider = FutureProvider<List<PaymentMethodModel>>((ref) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) return [];
  
  final response = await client
      .from('payment_methods')
      .select()
      .eq('user_id', user.id)
      .order('is_default', ascending: false)
      .order('created_at', ascending: false);
  
  return (response as List).map((json) => PaymentMethodModel.fromJson(json)).toList();
});

final subscriptionProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) return null;
  
  final response = await client
      .from('subscriptions')
      .select()
      .eq('user_id', user.id)
      .eq('status', 'active')
      .maybeSingle();
  
  return response;
});
