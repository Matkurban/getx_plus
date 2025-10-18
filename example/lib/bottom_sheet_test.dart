import 'package:flutter/material.dart';
import 'package:getx_plus/get.dart';

class BottomSheetTest extends StatelessWidget {
  const BottomSheetTest({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bottom Sheet Test')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Get.bottomSheet(
              backgroundColor: Colors.amber,
              Column(
                children: [
                  ListTile(leading: Icon(Icons.wb_sunny_outlined), title: Text("Day Mode")),
                  ListTile(leading: Icon(Icons.wb_sunny_outlined), title: Text("Day Mode")),
                ],
              ),
            );
          },
          child: const Text('Show Bottom Sheet'),
        ),
      ),
    );
  }
}
