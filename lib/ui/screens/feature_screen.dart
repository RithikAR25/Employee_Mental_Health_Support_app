import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stylish_bottom_bar/stylish_bottom_bar.dart';

// Dummy pages
class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Home Page Content', style: TextStyle(color: Colors.white)));
  }
}

class ChatPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Chat Page Content', style: TextStyle(color: Colors.white)));
  }
}

class AddPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Add Page Content', style: TextStyle(color: Colors.white)));
  }
}

class ArticlesPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Articles Page Content', style: TextStyle(color: Colors.white)));
  }
}

class SettingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Settings Page Content', style: TextStyle(color: Colors.white)));
  }
}



class FeaturePage extends StatefulWidget {
  static const String id = '/home';

  @override
  _FeaturePageState createState() => _FeaturePageState();
}

class _FeaturePageState extends State<FeaturePage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    HomePage(),
    ChatPage(),
    AddPage(),
    ArticlesPage(),
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
      backgroundColor: Color(0xFFf1f2f6),
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
        backgroundColor: Colors.white,
        onTap: _onTabTapped,
        items: [
          BottomBarItem(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            selectedColor: Color(0xFF27187e),
            unSelectedColor: Color(0xFF758bfd),
            title: Text('Home'),
          ),
          BottomBarItem(
            icon: Icon(Icons.chat_outlined),
            selectedIcon: Icon(Icons.chat),
            selectedColor: Color(0xFF27187e),
            unSelectedColor: Color(0xFF758bfd),
            title: Text('Chat'),
            badge: Text('0'),
            showBadge: true,
            badgeColor: Colors.red,
          ),
          BottomBarItem(
            icon: Icon(Icons.add),
            selectedIcon: Icon(Icons.add_circle),
            selectedColor: Color(0xFF27187e),
            unSelectedColor: Color(0xFF758bfd),
            title: Text('Add'),
          ),
          BottomBarItem(
            icon: Icon(Icons.article_outlined),
            selectedIcon: Icon(Icons.article),
            selectedColor:Color(0xFF27187e),
            unSelectedColor: Color(0xFF758bfd),
            title: Text('Articles'),
          ),
          BottomBarItem(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            selectedColor: Color(0xFF27187e),
            unSelectedColor: Color(0xFF758bfd),
            title: Text('Settings'),
          ),
        ],
      ),
    );
  }
}
