import 'package:flutter/material.dart';
import 'package:getx_plus/get.dart';

void main(){
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'GetX 5 Demo',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.green)),
      getPages: [
        GetPage(name: '/home', page: () => HomePage()),
        GetPage(name: '/page1', page: () => Page1()),
        GetPage(name: '/page2', page: () => Page2()),
      ],
      initialRoute: '/home',
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('GetX')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: ElevatedButton(
              onPressed: () => Get.toNamed('/page1'),
              child: Text('TO NAMED PAGE 1!'),
            ),
          ),
        ],
      ),
    );
  }
}

class Page1 extends StatelessWidget {
  const Page1({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Center(
            child: ElevatedButton(onPressed: () => Get.offAllNamed('/page2'), child: Text('OFF ALL PAGE 2')),
          ),
        ],
      ),
    );
  }
}

class Page2 extends StatelessWidget {
  const Page2({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(children: [Center(child: Text("We shouldn't be able to go back from here"))]),
    );
  }
}