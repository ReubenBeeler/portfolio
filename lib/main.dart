import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portfolio/bootstrapper.dart';
import 'package:portfolio/reubicon.dart';
import 'package:portfolio/util.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  const String title = "Reuben's Portfolio";
  const String background_path = "assets/original_dark_background.jpg";
  runApp(
    MaterialApp(
      title: title,
      // theme: ...
      home: Bootstrapper(
        precache: [AssetImage(background_path)],
        child: Scaffold(
          body: Stack(
            children: [
              SizedBox.expand(
                child: Image.asset(
                  background_path,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.high,
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final screenSize = MediaQuery.of(context).size;
                  return Stack(
                    children: [
                      Transform.translate(
                        offset: Offset(0, -0.25 * screenSize.height),
                        child: Center(
                          child: Text(
                            "REUBEN BEELER",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.roboto(
                              color: Colors.white,
                              fontSize: 0.5 * min(screenSize.width * 0.15, screenSize.height * 0.4),
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ),
                      ),
                      Transform.translate(
                        offset: Offset(0, 0.25 * screenSize.height),
                        child: Center(
                          child: Text(
                            "This website is under construction...",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.roboto(
                              color: Colors.white,
                              fontSize: 0.2 * min(screenSize.width * 0.15, screenSize.height * 0.4),
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              Center(
                child: ReubIcon(
                  backgroundColor: const Color.fromARGB(0xff, 0x02, 0x74, 0xb3),
                  child: IconButton(
                    icon: Image.asset("assets/linkedin_logo.webp", width: 200, height: 200),
                    onPressed: () => launchUrl(Uri.parse("https://linkedin.com/in/ReubenBeeler/")),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
