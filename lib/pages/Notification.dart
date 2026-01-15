import 'package:flutter/material.dart';
import 'package:pfs_agent/layouts/Colors.dart';


class Notification1 extends StatefulWidget {
  const Notification1({super.key});

  @override
  NotificationState createState() => NotificationState();
}

class NotificationState extends State<Notification1> {
  final String _headerImage = 'assets/images/back1.png';

  // Dummy data – you can later replace with real API data
  final List<Map<String, dynamic>> _notifications = [
    {
      "title": "New client approved",
      "message": "Your client John Banda has been approved.",
      "time": "10:24 AM",
      "type": "success",
      "unread": true,
    },
    {
      "title": "Pending application",
      "message": "2 client applications are still pending review.",
      "time": "Yesterday",
      "type": "warning",
      "unread": true,
    },
    {
      "title": "Target update",
      "message": "You have reached 72% of your monthly sales target.",
      "time": "2 days ago",
      "type": "info",
      "unread": false,
    },
  ];

  String _selectedFilter = "All";

  @override
  Widget build(BuildContext context) {
    final filtered = _notifications.where((n) {
      if (_selectedFilter == "All") return true;
      if (_selectedFilter == "Unread") return n["unread"] == true;
      if (_selectedFilter == "System") return n["type"] == "info";
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // hero background
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: SizedBox(
              height: 220,
              child: Image.asset(
                _headerImage,
                fit: BoxFit.cover,
              ),
            ),
          ),
          // gradient overlay
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              height: 220,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xE6000000),
                    Color(0x00000000),
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildTopBar(context),
                const SizedBox(height: 12),

                // main sheet
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 10,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(filtered.length),
                          const SizedBox(height: 12),
                          _buildFilterChips(),
                          const SizedBox(height: 12),
                          Expanded(
                            child: filtered.isEmpty
                                ? _buildEmptyState()
                                : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                              const SizedBox(height: 6),
                              itemBuilder: (context, index) {
                                final n = filtered[index];
                                return _buildNotificationItem(n);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============ TOP BAR ============

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Text(
              "Notifications",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          IconButton(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(
                AppColors.accent,
              ),
              shape: WidgetStateProperty.all(
                const CircleBorder(),
              ),
            ),
            icon: const Icon(Icons.notifications_off_outlined,
                color: Colors.white),
            onPressed: () {
              // future: mute / manage notification settings
            },
          ),
        ],
      ),
    );
  }

  // ============ HEADER & FILTERS ============

  Widget _buildHeader(int count) {
    return Row(
      children: [
        Text(
          "Notifications",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            "$count",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChips() {
    final filters = ["All", "Unread", "System"];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final bool selected = _selectedFilter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                f,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: selected
                      ? Colors.white
                      : AppColors.textSecondary,
                ),
              ),
              selected: selected,
              onSelected: (_) {
                setState(() {
                  _selectedFilter = f;
                });
              },
              selectedColor: AppColors.primary,
              backgroundColor: AppColors.cardBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: selected
                      ? AppColors.primary
                      : AppColors.textSecondary.withOpacity(0.15),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ============ SINGLE NOTIFICATION ITEM ============

  Widget _buildNotificationItem(Map<String, dynamic> n) {
    final String type = n["type"] ?? "info";
    final bool unread = n["unread"] == true;

    IconData icon;
    Color iconColor;

    switch (type) {
      case "success":
        icon = Icons.check_circle_outline;
        iconColor = AppColors.success;
        break;
      case "warning":
        icon = Icons.warning_amber_rounded;
        iconColor = AppColors.warning;
        break;
      case "error":
        icon = Icons.error_outline;
        iconColor = AppColors.danger;
        break;
      default:
        icon = Icons.info_outline;
        iconColor = AppColors.info;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: unread
              ? AppColors.primary.withOpacity(0.3)
              : AppColors.primary.withOpacity(0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // icon
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 20,
              color: iconColor,
            ),
          ),
          const SizedBox(width: 10),

          // text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        n["title"] ?? "",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                          unread ? FontWeight.w700 : FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      n["time"] ?? "",
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  n["message"] ?? "",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 6),

          // unread dot
          if (unread)
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }

  // ============ EMPTY STATE ============

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 60,
              color: AppColors.textSecondary.withOpacity(0.4),
            ),
            const SizedBox(height: 12),
            Text(
              "You're all caught up",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "You don’t have any notifications at the moment.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
