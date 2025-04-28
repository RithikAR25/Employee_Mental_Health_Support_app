import 'package:flutter/material.dart';
import 'package:stylish_bottom_bar/stylish_bottom_bar.dart';

import '../feature_pages/article_page.dart';
import '../feature_pages/chat_page.dart';
import '../feature_pages/home_page.dart';
import '../feature_pages/settings_page.dart';

class AddPage extends StatelessWidget {
  const AddPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('Add Page Content', style: TextStyle(color: Colors.white)),
    );
  }
}

class FeaturePage extends StatefulWidget {
  static const String id = '/home';

  const FeaturePage({super.key});

  @override
  _FeaturePageState createState() => _FeaturePageState();
}

class _FeaturePageState extends State<FeaturePage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    HomePage(),
    ChatPage(),
    AddPage(),
    ArticlePage(),
    SettingsPage(),
  ];

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Color(0xFFF0F0F5),
      body: _pages[_currentIndex],

      bottomNavigationBar: StylishBottomBar(
        option: AnimatedBarOptions(
          iconStyle: IconStyle.animated,
          barAnimation: BarAnimation.fade,
        ),
        currentIndex: _currentIndex,
        hasNotch: true,
        fabLocation: StylishBarFabLocation.center,
        notchStyle: NotchStyle.circle,
        backgroundColor: Color(0xFFffffff),
        onTap: _onTabTapped,
        items: [
          BottomBarItem(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            selectedColor: Color(0xFF003459),
            unSelectedColor: Color(0xFF00a8e8),
            title: Text('Home'),
          ),
          BottomBarItem(
            icon: Icon(Icons.chat_outlined),
            selectedIcon: Icon(Icons.chat),
            selectedColor: Color(0xFF003459),
            unSelectedColor: Color(0xFF00a8e8),
            title: Text('Chat'),
            badgeColor: Colors.red,
          ),
          BottomBarItem(
            icon: Icon(Icons.add),
            selectedIcon: Icon(Icons.add_circle),
            selectedColor: Color(0xFF003459),
            unSelectedColor: Color(0xFF00a8e8),
            title: Text('Add'),
          ),
          BottomBarItem(
            icon: Icon(Icons.article_outlined),
            selectedIcon: Icon(Icons.article),
            selectedColor: Color(0xFF003459),
            unSelectedColor: Color(0xFF00a8e8),
            title: Text('Articles'),
          ),
          BottomBarItem(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            selectedColor: Color(0xFF003459),
            unSelectedColor: Color(0xFF00a8e8),
            title: Text('Settings'),
          ),
        ],
      ),
    );
  }
}
