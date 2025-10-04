import 'package:flutter/material.dart';

class SideMenu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Colors.deepPurple),
            child: Text("Menu", style: TextStyle(color: Colors.white, fontSize: 24)),
          ),
          ListTile(
            leading: Icon(Icons.dashboard),
            title: Text("Dashboard"),
            onTap: () {},
          ),
          ListTile(
            leading: Icon(Icons.send),
            title: Text("Send Token"),
            onTap: () {},
          ),
          ListTile(
            leading: Icon(Icons.swap_horiz),
            title: Text("Trade"),
            onTap: () {},
          ),
          ListTile(
            leading: Icon(Icons.account_balance_wallet),
            title: Text("Wallet"),
            onTap: () {},
          ),
          ListTile(
            leading: Icon(Icons.logout),
            title: Text("Log out"),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
