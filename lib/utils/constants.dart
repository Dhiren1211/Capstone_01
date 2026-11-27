import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// App-wide constants: categories, default locations, paddings, routes.
class AppConstants {
  AppConstants._();

  // Brand
  static const appName = 'smartFind';
  static const appVersion = '1.0.0';
  static const appTagline = 'Lost Items. Found Faster.';
  static const appSubTagline = 'Report · Search · Reunite';

  // Item categories — matches design board's filter chip set
  static const List<ItemCategory> categories = [
    ItemCategory(value: 'all', label: 'All', icon: Icons.grid_view_rounded),
    ItemCategory(
      value: 'electronics',
      label: 'Electronics',
      icon: Icons.devices_rounded,
    ),
    ItemCategory(value: 'bags', label: 'Bags', icon: Icons.backpack_rounded),
    ItemCategory(
      value: 'wallets',
      label: 'Wallets',
      icon: Icons.account_balance_wallet_rounded,
    ),
    ItemCategory(value: 'keys', label: 'Keys', icon: Icons.key_rounded),
    ItemCategory(value: 'pets', label: 'Pets', icon: Icons.pets_rounded),
    ItemCategory(value: 'books', label: 'Books', icon: Icons.menu_book_rounded),
    ItemCategory(
      value: 'clothing',
      label: 'Clothing',
      icon: Icons.checkroom_rounded,
    ),
    ItemCategory(
      value: 'accessories',
      label: 'Accessories',
      icon: Icons.watch_rounded,
    ),
    ItemCategory(value: 'other', label: 'Other', icon: Icons.category_rounded),
  ];

  // Campus VR tour published by Kyungsung University (opens inside the app).
  static const String campusVrUrl =
      'https://kscms.ks.ac.kr/resources/cw/App/ksvr2019/index.html';

  // Default campus locations (used by the location picker) —
  // Kyungsung University building names.
  static const List<String> defaultLocations = [
    'Hansung Building',
    'Natural Sciences Building',
    'Arts Building',
    'Concert Hall',
    'Commerce Building',
    'Social Sciences Building',
    'Humanities Building',
    'Engineering Building I',
    'Engineering Building II',
    'Pharmacy & Sciences Building',
    'Industry-University Cooperation Building',
    'Nightingale Building',
    'Multimedia Building',
    'Culture Building',
    'Student Union Building I',
    'Student Union Building II',
    'ROTC Building',
    'Multimedia Information Building',
    'Central Library Building',
    'Nuri International Dormitory I',
    'Nuri International Dormitory II',
    'THE GENESIS',
    'Gymnasium',
    'Grand Stadium',
    'Tennis Court',
    'Front Gate',
    'East Gate',
  ];

  // Default map center — Kyungsung University, Busan, South Korea.
  // Address: 309 Suyeong-ro, Nam-gu, Busan. Campus pin on Google Maps:
  // 35.1397716, 129.0984966 (the former value was ~4 km too far west).
  // test/ksu_buildings_test.dart fails if the campus data drifts away again.
  static const double defaultMapCenterLat = 35.139279;
  static const double defaultMapCenterLng = 129.098716;
  static const double defaultMapZoom = 17.2;

  // Kyungsung campus bounding box — used to constrain the map viewport.
  // Items outside this box are still listed but the camera stays bounded.
  static const double ksuCampusNorth = 35.142679;
  static const double ksuCampusSouth = 35.135879;
  static const double ksuCampusEast = 129.102716;
  static const double ksuCampusWest = 129.094716;

  // Tighter camera bounds for the map screen — keeps users focused on campus.
  static const double ksuCameraNorth = 35.142979;
  static const double ksuCameraSouth = 35.135579;
  static const double ksuCameraEast = 129.103316;
  static const double ksuCameraWest = 129.094116;
  static const double ksuCameraMinZoom = 16.0;
  static const double ksuCameraMaxZoom = 19.5;

  // Spacing tokens — used across screens.
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 12;
  static const double spaceLg = 16;
  static const double spaceXl = 24;
  static const double space2xl = 32;
  static const double space3xl = 48;

  // Radii
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 24;
  static const double radiusFull = 999;

  // Touch targets
  static const double touchTarget = 48;

  // Routes (route names used by the navigator)
  static const routeSplash = '/';
  static const routeOnboarding = '/onboarding';
  static const routeLogin = '/login';
  static const routeSignup = '/signup';
  static const routeHome = '/home';
  static const routeItemDetail = '/item';
  static const routeReportLost = '/report-lost';
  static const routeReportFound = '/report-found';
  static const routeMap = '/map';
  static const routeProfile = '/profile';
  static const routeNotifications = '/notifications';
  static const routeChats = '/chats';
  static const routeChatDetail = '/chat';
  static const routeSettings = '/settings';
  static const routeSavedItems = '/saved-items';
  static const routeForgotPassword = '/forgot-password';
  static const routeEditProfile = '/edit-profile';
  static const routeTerms = '/terms';
  static const routePrivacy = '/privacy';
  static const routeGuidelines = '/guidelines';
  static const routeAbout = '/about';
  static const routeBuildingDetail = '/building';
  static const routeCampusVr = '/campus-vr';
  static const routeAdmin = '/admin';

  // Firestore collection names
  static const colItems = 'items';
  static const colUsers = 'users';
  static const colChats = 'chats';
  static const colMessages = 'messages';
  static const colNotifications = 'notifications';
  static const colAdmins = 'admins';
  static const colConfig = 'config';
  static const docBuildings = 'buildings';

  // How many of the newest items the live feed loads (filters by status /
  // category are then applied on the device — no Firestore index needed).
  static const int itemsFeedLimit = 200;
}

/// Category descriptor used by the home/search filter chips and report forms.
class ItemCategory {
  const ItemCategory({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  static ItemCategory fromValue(String value) {
    return AppConstants.categories.firstWhere(
      (c) => c.value == value,
      orElse: () => AppConstants.categories.last,
    );
  }
}

/// Item status: lost or found (matching the design board's red/green badges).
enum ItemStatus { lost, found, reunited }

extension ItemStatusX on ItemStatus {
  String get label {
    switch (this) {
      case ItemStatus.lost:
        return 'Lost';
      case ItemStatus.found:
        return 'Found';
      case ItemStatus.reunited:
        return 'Reunited';
    }
  }

  String get value {
    switch (this) {
      case ItemStatus.lost:
        return 'lost';
      case ItemStatus.found:
        return 'found';
      case ItemStatus.reunited:
        return 'reunited';
    }
  }

  Color get fgColor {
    switch (this) {
      case ItemStatus.lost:
        return AppColors.errorFg;
      case ItemStatus.found:
        return AppColors.successFg;
      case ItemStatus.reunited:
        return AppColors.primaryDark;
    }
  }

  Color get bgColor {
    switch (this) {
      case ItemStatus.lost:
        return AppColors.errorBg;
      case ItemStatus.found:
        return AppColors.successBg;
      case ItemStatus.reunited:
        return AppColors.primarySurface;
    }
  }

  static ItemStatus fromValue(String value) {
    switch (value) {
      case 'lost':
        return ItemStatus.lost;
      case 'found':
        return ItemStatus.found;
      case 'reunited':
        return ItemStatus.reunited;
      default:
        return ItemStatus.lost;
    }
  }
}
