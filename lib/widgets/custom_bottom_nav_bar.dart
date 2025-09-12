import 'package:auth0_flutter/auth0_flutter.dart';
import 'package:easibite/screens/scan_menu_page.dart';
import 'package:flutter/material.dart';

class CustomBottomNavBar extends StatefulWidget {
  final UserProfile? user;
  final Function(int) setIndex;
  final int selectedIndex;

  const CustomBottomNavBar({
    Key? key,
    this.user,
    required this.setIndex,
    required this.selectedIndex,
  }) : super(key: key);

  @override
  _CustomBottomNavBarState createState() => _CustomBottomNavBarState();
}

class _CustomBottomNavBarState extends State<CustomBottomNavBar> {
  @override
  Widget build(BuildContext context) {
    // Clamp index to valid range (0 to 2) for BottomNavigationBar
    // Use 0 when selectedIndex is 3 to avoid highlighting any item
    final int validIndex = widget.selectedIndex == 3 ? 0 : widget.selectedIndex.clamp(0, 2);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: validIndex,
        onTap: (index) {
          widget.setIndex(index); // Notify parent
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFFF7931E), // Orange for selected item
        unselectedItemColor: Colors.grey[600],
        backgroundColor: Colors.white,
        elevation: 0,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home, size: 24),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group, size: 24),
            label: 'Group Dining',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner, size: 24),
            label: 'Scan Menu',
          ),
        ],
        selectedFontSize: 12,
        unselectedFontSize: 12,
        selectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
        unselectedLabelStyle: TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: 12,
        ),
      ),
    );
  }
}