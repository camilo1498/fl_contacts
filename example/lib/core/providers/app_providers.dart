import 'package:fl_contacts_example/core/router/app_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Router instance shared across rebuilds.
final appRouterProvider = Provider<GoRouter>((ref) => buildAppRouter());
