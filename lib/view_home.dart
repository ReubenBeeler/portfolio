import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portfolio/my_view.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web/web.dart' show window;

import 'package:portfolio/main.dart' show accentColor;

class ViewHome extends StatelessView {
  ViewHome({super.key}) : super(name: "Home", icon: Icons.home_rounded);

  final tc1Key = GlobalKey();
  final linkedinKey = GlobalKey();
  final githubKey = GlobalKey();
  final resumeKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final widthFactor = 0.9;
    final screenSize = MediaQuery.of(context).size;
    final contentSize = Size(widthFactor * screenSize.width, screenSize.height);
    // final scale = min(contentSize.width * 0.15, contentSize.height * 0.4) / 220.5;
    // final tc1Scale = min(((contentSize.width - ppCircleDiameter) / 2) / 609.075, 0.9 * 0.65 * contentSize.height / 286.0);
    bool isRow = screenSize.width > screenSize.height;
    final ppCircleDiameter = min((isRow ? contentSize.width : contentSize.height) / 3, 0.65 * contentSize.height);
    return SizedBox(
      width: screenSize.width,
      child: Center(
        child: FractionallySizedBox(
          widthFactor: widthFactor, // 5% padding on left and right
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.fromSize(size: Size(contentSize.width, 0.05 * contentSize.height)),
              SizedBox.fromSize(
                size: Size(contentSize.width, 0.65 * contentSize.height),
                child: Flex(
                  direction: isRow ? Axis.horizontal : Axis.vertical,
                  children: [
                    Expanded(
                      child: Align(
                        // to fill the Expanded space so Column's tc1Key can get min dimensions
                        alignment: isRow ? Alignment.centerLeft : Alignment.center,
                        child: FittedBox(
                          child: Column(
                            key: tc1Key,
                            mainAxisSize: MainAxisSize.min,
                            // mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "REUBEN BEELER",
                                style: GoogleFonts.rumRaisin(
                                  color: Colors.white,
                                  // fontSize: 100 * tc1Scale,
                                  fontSize: 100,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 5.0,
                                      color: Colors.black,
                                      offset: Offset(0, 2.5),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                "Full-Stack Software Engineer",
                                style: GoogleFonts.roboto(
                                  color: accentColor,
                                  // fontSize: 60 * tc1Scale,
                                  fontSize: 50,
                                  fontWeight: FontWeight.w500,
                                  fontStyle: FontStyle.italic,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 2.0,
                                      color: Colors.black,
                                      offset: Offset(-0.1, 0.75),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                "I spin projects into production",
                                style: GoogleFonts.roboto(
                                  color: Colors.white,
                                  // fontSize: 40 * tc1Scale,
                                  fontSize: 40,
                                  fontWeight: FontWeight.w400,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 2.0,
                                      color: Colors.black,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 40, height: 10),
                    Center(
                      child: ClipOval(
                        child: Container(
                          width: ppCircleDiameter,
                          height: ppCircleDiameter,
                          color: accentColor,
                          child: Center(
                            child: Image.asset(
                              "assets/profile_pic.png",
                              width: ppCircleDiameter - 8,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 40, height: 40),
                    Expanded(
                      child: SizedBox(
                        height: 0.9 * 0.65 * contentSize.height,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            double radius;
                            Offset resume, linkedin, github;
                            if (constraints.maxWidth < 1.7 * constraints.maxHeight) {
                              // stack icons into triangle
                              radius = min(constraints.maxWidth / 4, constraints.maxHeight / (2 + sqrt(3)));

                              final centerOfCirles = Offset(
                                constraints.maxWidth / 2,
                                constraints.maxHeight / 2 + radius * (2 + sqrt(3)) / 2 - radius * (1 + 1 / sqrt(3)),
                              ); // center of circles is radius*(1 + 1/sqrt(3)) above bottom

                              final distFromCenter = (2 / sqrt(3)) * radius; // to each circle's center

                              final circleCenterToTop = Offset(-radius, -radius);

                              final rightAlignInsteadOfCenter = Offset((constraints.maxWidth - 4 * radius) / 2, 0);
                              final align = isRow ? rightAlignInsteadOfCenter : Offset.zero;

                              resume = centerOfCirles + (Offset(0, -1) * distFromCenter) + circleCenterToTop + align;
                              linkedin = centerOfCirles + (Offset(-sqrt(3) / 2, 1 / 2) * distFromCenter) + circleCenterToTop + align;
                              github = centerOfCirles + (Offset(sqrt(3) / 2, 1 / 2) * distFromCenter) + circleCenterToTop + align;
                            } else {
                              radius = min(constraints.maxWidth / 6, constraints.maxHeight / 2);
                              final centerInsteadOfRightAlign = Offset(-(constraints.maxWidth - 6 * radius) / 2, 0);
                              final align = isRow ? Offset.zero : centerInsteadOfRightAlign;

                              resume = Offset(constraints.maxWidth - 6 * radius, constraints.maxHeight / 2 - radius) + align;
                              linkedin = Offset(constraints.maxWidth - 4 * radius, constraints.maxHeight / 2 - radius) + align;
                              github = Offset(constraints.maxWidth - 2 * radius, constraints.maxHeight / 2 - radius) + align;
                            }

                            Widget buildCircle(Offset pos, GlobalKey key, String tooltip, VoidCallback onTap, ImageProvider imageProvider) {
                              return Positioned(
                                left: pos.dx,
                                top: pos.dy,
                                child: Tooltip(
                                  key: key,
                                  message: tooltip,
                                  waitDuration: const Duration(seconds: 1),
                                  child: MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: GestureDetector(
                                      onTap: onTap,
                                      child: Image(
                                        image: imageProvider,
                                        width: 2 * radius,
                                        height: 2 * radius,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }

                            return Stack(
                              children: [
                                buildCircle(resume, resumeKey, "Resume", () => window.open("assets/Reuben Beeler Resume.pdf", "_blank"), AssetImage("assets/resume.webp")), // make accentColor border programmatically
                                buildCircle(linkedin, linkedinKey, "LinkedIn", () => launchUrl(Uri.parse("https://linkedin.com/in/ReubenBeeler/")), AssetImage("assets/linkedin_circle.png")),
                                buildCircle(github, githubKey, "Github", () => launchUrl(Uri.parse("https://github.com/ReubenBeeler/")), AssetImage("assets/github_logo_clean.webp")),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox.fromSize(size: Size(contentSize.width, 0.05 * contentSize.height)),
              Divider(color: accentColor, height: 4, thickness: 4),
            ],
          ),
        ),
      ),
    );
  }
}
