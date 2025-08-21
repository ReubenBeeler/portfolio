import 'package:flutter/material.dart';
import 'package:portfolio/bootstrapper.dart';
import 'package:portfolio/reubicon.dart';

void main() {
  runApp(
    MaterialApp(
      title: "Reuben's Portfolio",
      // theme: ...
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: <Widget>[
            SizedBox.expand(
              child: Image.asset(
                "assets/black_background.jpg",
                fit: BoxFit.fill,
              ),
            ),
            Bootstrapper(
              child: ReubIcon(
                asset_path: "assets/linkedin_logo.webp",
                square_size: 200,
                default_color: const Color.fromARGB(0xff, 0x02, 0x74, 0xb3),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
