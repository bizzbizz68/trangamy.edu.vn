import 'package:flutter/material.dart';
import '../../auth/models/user_model.dart';
import '../../hsk_exam/admin/screens/question_bank_dashboard.dart';
import '../widgets/app_sidebar.dart';
import '../widgets/sidebar_toggle_button.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminDashboard extends StatefulWidget {
  final UserModel user;

  const AdminDashboard({super.key, required this.user});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  final _sidebarKey = GlobalKey<AppSidebarState>();
  SidebarState _sidebarState = SidebarState.expanded;

  void _updateSidebarState(SidebarState state) {
    setState(() {
      _sidebarState = state;
    });
  }

  final List<NavigationItem> _navigationItems = [
    NavigationItem(
      icon: Icons.dashboard,
      label: 'Tổng Quan',
      color: Colors.blue,
    ),
    NavigationItem(
      icon: Icons.people,
      label: 'Quản Lý User',
      color: Colors.blue,
    ),
    NavigationItem(
      icon: Icons.quiz,
      label: 'Quản Lý Đề Thi',
      color: Colors.orange,
    ),
    NavigationItem(
      icon: Icons.analytics,
      label: 'Thống Kê & Báo Cáo',
      color: Colors.purple,
    ),
    NavigationItem(
      icon: Icons.settings,
      label: 'Cài Đặt Hệ Thống',
      color: Colors.grey,
    ),
  ];

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildOverviewContent();
      case 1:
        return _buildUserManagementContent(); 
      case 2:
        return const QuestionBankDashboard();
      case 3:
        return _buildAnalyticsContent();
      case 4:
        return _buildSettingsContent();
      default:
        return _buildOverviewContent();
    }
  }

  Widget _buildOverviewContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tổng Quan Hệ Thống',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: GridView(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 350, 
              mainAxisExtent: 180,    
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            children: [
              _buildStatCard(
                title: 'Tổng Người Dùng',
                value: '1,234',
                icon: Icons.people,
                color: Colors.blue,
              ),
              _buildStatCard(
                title: 'Giáo Viên',
                value: '56',
                icon: Icons.school,
                color: Colors.green,
              ),
              _buildStatCard(
                title: 'Học Sinh',
                value: '1,150',
                icon: Icons.person,
                color: Colors.orange,
              ),
              _buildStatCard(
                title: 'Đề Thi',
                value: '89',
                icon: Icons.quiz,
                color: Colors.purple,
              ),
              _buildStatCard(
                title: 'Bài Thi Hôm NaY',
                value: '245',
                icon: Icons.assignment_turned_in,
                color: Colors.teal,
              ),
              _buildStatCard(
                title: 'Phụ Huynh',
                value: '28',
                icon: Icons.family_restroom,
                color: Colors.red,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserManagementContent() {
    return DefaultTabController(
      length: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quản Lý Tài Khoản',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const TabBar(
            isScrollable: true,
            labelColor: Colors.blue,
            tabs: [
              Tab(text: 'Tất cả'),
              Tab(text: 'Admin'),
              Tab(text: 'Giáo viên'),
              Tab(text: 'Học sinh'),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text('Lỗi tải dữ liệu'));
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return const Center(child: Text('Chưa có người dùng nào'));
                }

                return Card(
                  child: ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final name = data['name'] ?? 'Không tên';
                      final email = data['email'] ?? 'Không email';
                      final role = data['role'] ?? 'student';

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.withOpacity(0.1),
                          child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U'),
                        ),
                        title: Text(name),
                        subtitle: Text(email),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildRoleBadge(role),
                            IconButton(
                              icon: const Icon(Icons.security, color: Colors.orange),
                              onPressed: () => _showPermissionDialog(context, docs[index].id, role),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Hàm build giao diện badge phân quyền đẹp mắt
  Widget _buildRoleBadge(String role) {
    Color badgeColor;
    switch (role.toLowerCase()) {
      case 'admin':
        badgeColor = Colors.red;
        break;
      case 'teacher':
      case 'giáo viên':
        badgeColor = Colors.green;
        break;
      case 'student':
      case 'học sinh':
        badgeColor = Colors.blue;
        break;
      default:
        badgeColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withOpacity(0.5)),
      ),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(
          color: badgeColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Hàm xử lý hiển thị dialog phân quyền
  void _showPermissionDialog(BuildContext context, String userId, String currentRole) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Thay đổi quyền tài khoản'),
          content: Text('Quyền hiện tại: $currentRole\nBạn có muốn cập nhật quyền không?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Ví dụ chuyển đổi logic mẫu hoặc bạn có thể tạo Dropdown tùy chọn quyền tại đây
                String nextRole = currentRole == 'admin' ? 'student' : 'admin'; 
                await FirebaseFirestore.instance.collection('users').doc(userId).update({
                  'role': nextRole,
                });
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Thay Đổi'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAnalyticsContent() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics, size: 64, color: Colors.purple),
          SizedBox(height: 16),
          Text(
            'Thống Kê & Báo Cáo',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text('Biểu đồ tăng trưởng và kết quả thi'),
        ],
      ),
    );
  }

  Widget _buildSettingsContent() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.settings, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Cài Đặt Hệ Thống',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text('Cấu hình các tham số hệ thống và API'),
        ],
      ),
    );
  }

  double get _contentLeftMargin {
    switch (_sidebarState) {
      case SidebarState.hidden:
        return 0.0;
      case SidebarState.collapsed:
        return 70.0;
      case SidebarState.expanded:
        return 250.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            margin: EdgeInsets.only(left: _contentLeftMargin),
            child: Column(
              children: [
                // AppBar Header
                Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Text(
                        _navigationItems[_selectedIndex].label,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.notifications_outlined),
                        onPressed: () {},
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.user.email,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                // Main Content Area
                Expanded(
                  child: Container(
                    color: Colors.grey[50],
                    padding: const EdgeInsets.all(24),
                    child: _buildContent(),
                  ),
                ),
              ],
            ),
          ),
          // Sidebar
          AppSidebar(
            key: _sidebarKey,
            user: widget.user,
            navigationItems: _navigationItems,
            selectedIndex: _selectedIndex,
            onItemSelected: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            onStateChanged: _updateSidebarState,
          ),
          // Nút toggle Sidebar
          SidebarToggleButton(
            sidebarState: _sidebarState,
            onTap: () => _sidebarKey.currentState?.toggleSidebar(),
          ),
        ],
      ),
    );
  }
}