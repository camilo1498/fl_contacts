// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_router.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [
  $appShellRouteData,
  $contactsListRouteData,
  $contactDetailRouteData,
  $contactEditorRouteData,
  $groupsRouteData,
  $toolsRouteData,
];

RouteBase get $appShellRouteData => StatefulShellRouteData.$route(
  factory: $AppShellRouteDataExtension._fromState,
  branches: [
    StatefulShellBranchData.$branch(
      routes: [
        GoRouteData.$route(
          path: '/contacts',
          hasOverriddenOnExit: false,
          factory: $ContactsListRouteData._fromState,
        ),
        GoRouteData.$route(
          path: '/contacts/:id',
          hasOverriddenOnExit: false,
          factory: $ContactDetailRouteData._fromState,
        ),
        GoRouteData.$route(
          path: '/contacts/edit/:id',
          hasOverriddenOnExit: false,
          factory: $ContactEditorRouteData._fromState,
        ),
      ],
    ),
    StatefulShellBranchData.$branch(
      routes: [
        GoRouteData.$route(
          path: '/groups',
          hasOverriddenOnExit: false,
          factory: $GroupsRouteData._fromState,
        ),
      ],
    ),
    StatefulShellBranchData.$branch(
      routes: [
        GoRouteData.$route(
          path: '/tools',
          hasOverriddenOnExit: false,
          factory: $ToolsRouteData._fromState,
        ),
      ],
    ),
  ],
);

extension $AppShellRouteDataExtension on AppShellRouteData {
  static AppShellRouteData _fromState(GoRouterState state) =>
      const AppShellRouteData();
}

mixin $ContactsListRouteData on GoRouteData {
  static ContactsListRouteData _fromState(GoRouterState state) =>
      const ContactsListRouteData();

  @override
  String get location => GoRouteData.$location('/contacts');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $ContactDetailRouteData on GoRouteData {
  static ContactDetailRouteData _fromState(GoRouterState state) =>
      ContactDetailRouteData(id: state.pathParameters['id']!);

  ContactDetailRouteData get _self => this as ContactDetailRouteData;

  @override
  String get location =>
      GoRouteData.$location('/contacts/${Uri.encodeComponent(_self.id)}');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $ContactEditorRouteData on GoRouteData {
  static ContactEditorRouteData _fromState(GoRouterState state) =>
      ContactEditorRouteData(id: state.pathParameters['id']!);

  ContactEditorRouteData get _self => this as ContactEditorRouteData;

  @override
  String get location =>
      GoRouteData.$location('/contacts/edit/${Uri.encodeComponent(_self.id)}');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $GroupsRouteData on GoRouteData {
  static GroupsRouteData _fromState(GoRouterState state) =>
      const GroupsRouteData();

  @override
  String get location => GoRouteData.$location('/groups');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $ToolsRouteData on GoRouteData {
  static ToolsRouteData _fromState(GoRouterState state) =>
      const ToolsRouteData();

  @override
  String get location => GoRouteData.$location('/tools');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $contactsListRouteData => GoRouteData.$route(
  path: '/contacts',
  hasOverriddenOnExit: false,
  factory: $ContactsListRouteData._fromState,
);

RouteBase get $contactDetailRouteData => GoRouteData.$route(
  path: '/contacts/:id',
  hasOverriddenOnExit: false,
  factory: $ContactDetailRouteData._fromState,
);

RouteBase get $contactEditorRouteData => GoRouteData.$route(
  path: '/contacts/edit/:id',
  hasOverriddenOnExit: false,
  factory: $ContactEditorRouteData._fromState,
);

RouteBase get $groupsRouteData => GoRouteData.$route(
  path: '/groups',
  hasOverriddenOnExit: false,
  factory: $GroupsRouteData._fromState,
);

RouteBase get $toolsRouteData => GoRouteData.$route(
  path: '/tools',
  hasOverriddenOnExit: false,
  factory: $ToolsRouteData._fromState,
);
