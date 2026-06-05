import 'package:flutter/material.dart';
import '../../auth/models/user_model.dart';
import '../../../core/utils/role_resolver.dart';
import '../../auth/screens/login_screen.dart';
import '../../auth/services/firebase_auth_service.dart';

enum SidebarState {
  hidden,    // Ẩn hoàn toàn
  collapsed, // (Không dùng tới nữa)
  expanded,  // Hiện đầy đủ
}

class AppSidebar extends StatefulWidget {
  final UserModel user;
  final List<NavigationItem> navigationItems;
  final int selectedIndex;
  final Function(int) onItemSelected;
  final Function(SidebarState)? onStateChanged;

  const AppSidebar({
    super.key,
    required this.user,
    required this.navigationItems,
    required this.selectedIndex,
    required this.onItemSelected,
    this.onStateChanged,
  });

  @override
  State<AppSidebar> createState() => AppSidebarState();
}

class AppSidebarState extends State<AppSidebar> {
  SidebarState _state = SidebarState.expanded;

  // Sửa width: Chỉ có 2 mức 0 và 250
  double get width {
    return _state == SidebarState.expanded ? 250.0 : 0.0;
  }

  // Sửa logic Toggle: Chỉ chuyển qua lại giữa expanded và hidden
  void toggleSidebar() {
    setState(() {
      if (_state == SidebarState.expanded) {
        _state = SidebarState.hidden;
      } else {
        _state = SidebarState.expanded;
      }
      widget.onStateChanged?.call(_state);
    });
  }

  Future<void> _handleLogout(BuildContext context) async {
    try {
      final authService = FirebaseAuthService();
      await authService.logout();

      if (!context.mounted) return;

      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi đăng xuất: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isExpanded = _state == SidebarState.expanded;
    final isHidden = _state == SidebarState.hidden;
    
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          width: width,
          color: Colors.grey[900],
          child: !isHidden
              ? Column(
                  children: [
                    // Header với Avatar
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.grey[850],
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: RoleResolver.getRoleColor(widget.user.role),
                            child: Icon(
                              RoleResolver.getRoleIcon(widget.user.role),
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.user.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  RoleResolver.getRoleDisplayName(widget.user.role),
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Divider(color: Colors.grey, height: 1),

                    // Navigation Items
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: widget.navigationItems.length,
                        itemBuilder: (context, index) {
                          final item = widget.navigationItems[index];
                          final isSelected = widget.selectedIndex == index;

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Material(
                              color: isSelected ? Colors.blue.withOpacity(0.2) : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              child: InkWell(
                                onTap: () => widget.onItemSelected(index),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  child: Row(
                                    children: [
                                      Icon(
                                        item.icon,
                                        color: isSelected ? Colors.blue : Colors.white70,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          item.label,
                                          style: TextStyle(
                                            color: isSelected ? Colors.white : Colors.white70,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const Divider(color: Colors.grey, height: 1),

                    // Logout Button
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          onTap: () => _handleLogout(context),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 48),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            child: const Row(
                              children: [
                                Icon(Icons.logout, color: Colors.red, size: 24),
                                SizedBox(width: 12),
                                Text(
                                  'Đăng Xuất',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class NavigationItem {
  final IconData icon;
  final String label;
  final Color color;

  NavigationItem({
    required this.icon,
    required this.label,
    required this.color,
  });
}