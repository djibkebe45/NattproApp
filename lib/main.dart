import 'package:flutter/material.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NattProApp',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: Scaffold(
        appBar: AppBar(title: Text('NattProApp')),
        body: Center(child: Text('Bienvenue sur NattProApp ! 🚀')),
      ),
    );
  }
}
