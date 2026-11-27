import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/item_model.dart';
import '../services/firestore_service.dart';

/// The live feed of the newest reports, exactly as stored (no filtering).
///
/// Filters and search texts belong to the screen that shows them (see
/// `ItemFilter`). They used to live here, which is why a search made on the
/// Search tab was still applied to the Home tab afterwards: both screens read
/// the same filtered list. Now every screen filters its own copy.
///
/// The feed is only readable by signed-in users, so the subscription follows
/// the sign-in state: call [setSignedIn] whenever it changes (done by the
/// `ChangeNotifierProxyProvider` in `main.dart`).
class ItemsState extends ChangeNotifier {
  ItemsState();

  StreamSubscription<List<ItemModel>>? _sub;

  bool _signedIn = false;
  List<ItemModel> _items = const [];
  bool _isLoading = false;
  String? _error;

  List<ItemModel> get items => _items;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Reports that are still open (not reunited).
  List<ItemModel> get openItems =>
      _items.where((i) => !i.reunited).toList(growable: false);

  /// Starts / stops listening to Firestore. Safe to call repeatedly with the
  /// same value.
  void setSignedIn(bool signedIn) {
    if (signedIn == _signedIn) return;
    _signedIn = signedIn;
    if (signedIn) {
      _subscribe();
    } else {
      _sub?.cancel();
      _sub = null;
      _items = const [];
      _error = null;
      _isLoading = false;
      // Called from Provider's update() while widgets are building.
      scheduleMicrotask(notifyListeners);
    }
  }

  void _subscribe() {
    _sub?.cancel();
    _isLoading = true;
    _error = null;
    scheduleMicrotask(notifyListeners);
    _sub = FirestoreService.instance.watchItems().listen(
      (items) {
        _items = items;
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (Object e) {
        debugPrint('[items] feed error: $e');
        _error = 'Could not load items. Check your connection and permissions.';
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  /// Re-subscribes (pull-to-refresh / "Retry").
  void refresh() {
    if (_signedIn) _subscribe();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
