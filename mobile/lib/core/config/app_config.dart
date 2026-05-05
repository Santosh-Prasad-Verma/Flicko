import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static late final String supabaseUrl;
  static late final String supabaseAnonKey;
  static late final String livekitUrl;
  static late final String stripePublishableKey;
  static late final String apiBaseUrl;
  static late final String giphyApiKey;
  static late final String razorpayKeyId;
  
  // Appwrite
  static late final String appwriteProjectId;
  static late final String appwriteProjectName;
  static late final String appwritePublicEndpoint;
  static late final String appwriteBucketId;

  static bool get isDebug => kDebugMode;

  static void init() {
    supabaseUrl = dotenv.env['FLICKO_SUPABASE_URL'] ?? '';
    supabaseAnonKey = dotenv.env['FLICKO_SUPABASE_ANON_KEY'] ?? '';
    livekitUrl = dotenv.env['FLICKO_LIVEKIT_URL'] ?? '';
    stripePublishableKey = dotenv.env['FLICKO_STRIPE_PUBLISHABLE_KEY'] ?? '';
    apiBaseUrl = dotenv.env['FLICKO_API_URL'] ?? '';
    giphyApiKey = dotenv.env['FLICKO_GIPHY_API_KEY'] ?? '';
    razorpayKeyId = dotenv.env['FLICKO_RAZORPAY_KEY_ID'] ?? '';

    
    appwriteProjectId = dotenv.env['FLICKO_APPWRITE_PROJECT_ID'] ?? '';
    appwriteProjectName = dotenv.env['FLICKO_APPWRITE_PROJECT_NAME'] ?? '';
    appwritePublicEndpoint = dotenv.env['FLICKO_APPWRITE_PUBLIC_ENDPOINT'] ?? '';
    appwriteBucketId = dotenv.env['FLICKO_APPWRITE_BUCKET_ID'] ?? '';
  }
}
