import 'package:fl_contacts_example/features/contacts/contact_detail_page.dart';
import 'package:fl_contacts_example/features/contacts/contact_editor_page.dart';
import 'package:fl_contacts_example/features/contacts/contacts_list_page.dart';
import 'package:fl_contacts_example/features/groups/groups_page.dart';
import 'package:fl_contacts_example/features/tools/tools_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

part 'app_router.g.dart';

/// Shell holding the bottom navigation bar.
@TypedStatefulShellRoute<AppShellRouteData>(
  branches: [
    TypedStatefulShellBranch<ContactsBranchData>(
      routes: [
        TypedGoRoute<ContactsListRouteData>(path: '/contacts'),
        TypedGoRoute<ContactDetailRouteData>(path: '/contacts/:id'),
        TypedGoRoute<ContactEditorRouteData>(path: '/contacts/edit/:id'),
      ],
    ),
    TypedStatefulShellBranch<GroupsBranchData>(
      routes: [TypedGoRoute<GroupsRouteData>(path: '/groups')],
    ),
    TypedStatefulShellBranch<ToolsBranchData>(
      routes: [TypedGoRoute<ToolsRouteData>(path: '/tools')],
    ),
  ],
)
class AppShellRouteData extends StatefulShellRouteData {
  const AppShellRouteData();

  @override
  Widget builder(
    BuildContext context,
    GoRouterState state,
    StatefulNavigationShell navigationShell,
  ) {
    return AppShell(navigationShell: navigationShell);
  }
}

/// Bottom navigation shell driven by the active branch.
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _goBranch,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.contacts_outlined),
            selectedIcon: Icon(Icons.contacts),
            label: 'Contacts',
          ),
          NavigationDestination(
            icon: Icon(Icons.group_outlined),
            selectedIcon: Icon(Icons.group),
            label: 'Groups',
          ),
          NavigationDestination(
            icon: Icon(Icons.handyman_outlined),
            selectedIcon: Icon(Icons.handyman),
            label: 'Tools',
          ),
        ],
      ),
    );
  }
}

/// Contacts tab branch.
class ContactsBranchData extends StatefulShellBranchData {
  const ContactsBranchData();
}

/// Groups tab branch.
class GroupsBranchData extends StatefulShellBranchData {
  const GroupsBranchData();
}

/// Tools tab branch.
class ToolsBranchData extends StatefulShellBranchData {
  const ToolsBranchData();
}

/// Contact list: search, refresh, thumbnails and live updates.
@TypedGoRoute<ContactsListRouteData>(path: '/contacts')
class ContactsListRouteData extends GoRouteData with $ContactsListRouteData {
  const ContactsListRouteData();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const ContactsListPage();
  }
}

/// Full detail of one contact with edit, delete and export actions.
@TypedGoRoute<ContactDetailRouteData>(path: '/contacts/:id')
class ContactDetailRouteData extends GoRouteData with $ContactDetailRouteData {
  const ContactDetailRouteData({required this.id});

  final String id;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return ContactDetailPage(contactId: id);
  }
}

/// Creator (`contactId == null`) and editor for contacts.
@TypedGoRoute<ContactEditorRouteData>(path: '/contacts/edit/:id')
class ContactEditorRouteData extends GoRouteData with $ContactEditorRouteData {
  const ContactEditorRouteData({required this.id});

  /// Either a contact ID or the literal `new`.
  final String id;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return ContactEditorPage(contactId: id == 'new' ? null : id);
  }
}

/// Group list with create, rename, delete and membership editing.
@TypedGoRoute<GroupsRouteData>(path: '/groups')
class GroupsRouteData extends GoRouteData with $GroupsRouteData {
  const GroupsRouteData();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const GroupsPage();
  }
}

/// Permissions, native UI, vCard tools and device-only features.
@TypedGoRoute<ToolsRouteData>(path: '/tools')
class ToolsRouteData extends GoRouteData with $ToolsRouteData {
  const ToolsRouteData();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const ToolsPage();
  }
}

/// Builds the app router with the contacts tab as entry point.
GoRouter buildAppRouter() => GoRouter(
  routes: $appRoutes,
  initialLocation: '/contacts',
  debugLogDiagnostics: false,
);
