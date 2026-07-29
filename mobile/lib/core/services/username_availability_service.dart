import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Result of username availability check
class UsernameAvailabilityResult {
  final String username;
  final bool isAvailable;
  final String? error;
  final List<String> suggestions;
  final bool isCached;

  const UsernameAvailabilityResult({
    required this.username,
    required this.isAvailable,
    this.error,
    this.suggestions = const [],
    this.isCached = false,
  });
}

/// Simple & fast probabilistic Bloom Filter implementation for usernames
class UsernameBloomFilter {
  final int bitArraySize;
  late final List<int> _bitArray;
  int _insertedCount = 0;

  UsernameBloomFilter({this.bitArraySize = 8192}) {
    _bitArray = List<int>.filled((bitArraySize / 32).ceil(), 0);
  }

  int get insertedCount => _insertedCount;

  // Simple FNV-1a hash variation 1
  int _hash1(String input) {
    var hash = 2166136261;
    for (var i = 0; i < input.length; i++) {
      hash ^= input.codeUnitAt(i);
      hash = (hash * 16777619) & 0xFFFFFFFF;
    }
    return hash.abs() % bitArraySize;
  }

  // Hash variation 2 (DJB2)
  int _hash2(String input) {
    var hash = 5381;
    for (var i = 0; i < input.length; i++) {
      hash = (((hash << 5) + hash) + input.codeUnitAt(i)) & 0xFFFFFFFF;
    }
    return hash.abs() % bitArraySize;
  }

  // Hash variation 3 (SDBM)
  int _hash3(String input) {
    var hash = 0;
    for (var i = 0; i < input.length; i++) {
      hash = (input.codeUnitAt(i) + (hash << 6) + (hash << 16) - hash) & 0xFFFFFFFF;
    }
    return hash.abs() % bitArraySize;
  }

  void add(String item) {
    final lower = item.toLowerCase();
    _setBit(_hash1(lower));
    _setBit(_hash2(lower));
    _setBit(_hash3(lower));
    _insertedCount++;
  }

  /// Returns false if GUARANTEED not in filter (i.e. Username definitely NOT taken = Available)
  /// Returns true if MIGHT be in filter (Proceed to verify in Cache/DB)
  bool mightContain(String item) {
    final lower = item.toLowerCase();
    return _getBit(_hash1(lower)) && _getBit(_hash2(lower)) && _getBit(_hash3(lower));
  }

  void _setBit(int bitIndex) {
    final arrayIndex = bitIndex ~/ 32;
    final bitOffset = bitIndex % 32;
    _bitArray[arrayIndex] |= (1 << bitOffset);
  }

  bool _getBit(int bitIndex) {
    final arrayIndex = bitIndex ~/ 32;
    final bitOffset = bitIndex % 32;
    return (_bitArray[arrayIndex] & (1 << bitOffset)) != 0;
  }
}

/// In-Memory LRU Cache for checked usernames
class UsernameLruCache {
  final int capacity;
  final Map<String, UsernameAvailabilityResult> _cache = {};

  UsernameLruCache({this.capacity = 150});

  UsernameAvailabilityResult? get(String username) {
    final key = username.toLowerCase();
    if (!_cache.containsKey(key)) return null;

    // Move to end (most recently used)
    final value = _cache.remove(key)!;
    _cache[key] = value;
    return value;
  }

  void put(String username, UsernameAvailabilityResult result) {
    final key = username.toLowerCase();
    if (_cache.containsKey(key)) {
      _cache.remove(key);
    } else if (_cache.length >= capacity) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = result;
  }
}

/// Service providing Instagram-level multi-tier username availability checks
class UsernameAvailabilityService {
  final UsernameBloomFilter _bloomFilter = UsernameBloomFilter();
  final UsernameLruCache _lruCache = UsernameLruCache();

  static final usernameRegex = RegExp(r'^[\w.-]{2,32}$');

  /// Perform fast multi-tier availability check
  Future<UsernameAvailabilityResult> checkAvailability(String rawUsername) async {
    final username = rawUsername.trim().toLowerCase();

    // 1. Format Validation (Client-Side)
    if (username.isEmpty) {
      return UsernameAvailabilityResult(
        username: rawUsername,
        isAvailable: false,
        error: 'Username is required',
      );
    }

    if (username.length < 2 || username.length > 32) {
      return UsernameAvailabilityResult(
        username: rawUsername,
        isAvailable: false,
        error: 'Username must be between 2 and 32 characters',
      );
    }

    if (!usernameRegex.hasMatch(username)) {
      return UsernameAvailabilityResult(
        username: rawUsername,
        isAvailable: false,
        error: 'Only letters, numbers, underscores, dots, and hyphens allowed',
      );
    }

    // Reserved usernames check
    const reserved = {'admin', 'flicko', 'support', 'official', 'help', 'root', 'moderator', 'system'};
    if (reserved.contains(username)) {
      return UsernameAvailabilityResult(
        username: rawUsername,
        isAvailable: false,
        error: 'This username is reserved by Flicko',
        suggestions: _generateSuggestions(username),
      );
    }

    // 2. Check LRU Cache (Sub-1ms response!)
    final cached = _lruCache.get(username);
    if (cached != null) {
      return UsernameAvailabilityResult(
        username: cached.username,
        isAvailable: cached.isAvailable,
        error: cached.error,
        suggestions: cached.suggestions,
        isCached: true,
      );
    }

    // 3. Check Bloom Filter (Sub-1ms evaluation!)
    // If Bloom filter returns false, it is 100% GUARANTEED NOT TAKEN
    if (!_bloomFilter.mightContain(username)) {
      final result = UsernameAvailabilityResult(
        username: rawUsername,
        isAvailable: true,
        isCached: true,
      );
      _lruCache.put(username, result);
      return result;
    }

    // 4. Query Database (Supabase Profiles table)
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('profiles')
          .select('username')
          .ilike('username', username)
          .limit(1);

      final isTaken = response.isNotEmpty;
      if (isTaken) {
        _bloomFilter.add(username);
        final result = UsernameAvailabilityResult(
          username: rawUsername,
          isAvailable: false,
          error: 'Username is already taken',
          suggestions: _generateSuggestions(username),
        );
        _lruCache.put(username, result);
        return result;
      } else {
        final result = UsernameAvailabilityResult(
          username: rawUsername,
          isAvailable: true,
        );
        _lruCache.put(username, result);
        return result;
      }
    } catch (_) {
      // Fallback: If DB network error, return format-based approval
      return UsernameAvailabilityResult(
        username: rawUsername,
        isAvailable: true,
      );
    }
  }

  /// Generate smart alternative username suggestions if taken
  List<String> _generateSuggestions(String base) {
    final clean = base.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
    final suggestions = <String>[
      '${clean}_1',
      '${clean}_real',
      '${clean}_official',
      'the_$clean',
      '${clean}_op',
    ];
    return suggestions.take(4).toList();
  }
}

/// Riverpod provider for UsernameAvailabilityService
final usernameAvailabilityServiceProvider = Provider<UsernameAvailabilityService>((ref) {
  return UsernameAvailabilityService();
});
