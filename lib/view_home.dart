import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portfolio/my_view.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:portfolio/main.dart' show accentColor;

class ViewHome extends StatelessView {
  ViewHome({super.key}) : super(name: "Home", icon: Icons.home_rounded);

  final linkedinKey = GlobalKey();
  final githubKey = GlobalKey();
  final resumeKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    const widthFactor = 0.9; // 5% padding on left and right
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final contentSize = Size(constraints.maxWidth, 0.85 * constraints.maxHeight);
          bool isRow = contentSize.width > contentSize.height;
          final ppCircleDiameter = isRow ? min(contentSize.width / 3, contentSize.height) : min(contentSize.width, contentSize.height / 2);
          return Column(
            children: [
              Spacer(),
              SizedBox.fromSize(
                size: contentSize,
                child: Flex(
                  direction: isRow ? Axis.horizontal : Axis.vertical,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: isRow ? Alignment.centerLeft : Alignment.center,
                        child: FittedBox(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            // mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "REUBEN BEELER",
                                style: GoogleFonts.rumRaisin(
                                  color: Colors.white,
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
                                "DevOps Software Engineer",
                                style: GoogleFonts.roboto(
                                  color: accentColor,
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
                    SizedBox(width: 0.02 * contentSize.width, height: 0.01 * contentSize.height),
                    Container(
                      width: ppCircleDiameter,
                      height: ppCircleDiameter,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: BoxBorder.all(color: accentColor, width: 4),
                      ),
                      child: Image.network('assets/profile_pic.webp', width: ppCircleDiameter - 8, height: ppCircleDiameter - 8), // 4px outline to match rest of dividers
                    ),
                    SizedBox(width: 0.02 * contentSize.width, height: 0.01 * contentSize.height),
                    Expanded(
                      child: FractionallySizedBox(
                        heightFactor: isRow ? 0.9 : 1,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            double radius;
                            Offset linkedinOffset, githubOffset;
                            // if (constraints.maxWidth < 1.7 * constraints.maxHeight) {
                            //   // stack icons into triangle
                            //   radius = min(constraints.maxWidth / 4, constraints.maxHeight / (2 + sqrt(3)));

                            //   final centerOfCirles = Offset(
                            //     constraints.maxWidth / 2,
                            //     constraints.maxHeight / 2 + radius * (2 + sqrt(3)) / 2 - radius * (1 + 1 / sqrt(3)),
                            //   ); // center of circles is radius*(1 + 1/sqrt(3)) above bottom

                            //   final distFromCenter = (2 / sqrt(3)) * radius; // to each circle's center

                            //   final circleCenterToTop = Offset(-radius, -radius);

                            //   final rightAlignInsteadOfCenter = Offset((constraints.maxWidth - 4 * radius) / 2, 0);
                            //   final align = isRow ? rightAlignInsteadOfCenter : Offset.zero;

                            //   resumeOffset = centerOfCirles + (Offset(0, -1) * distFromCenter) + circleCenterToTop + align;
                            //   linkedinOffset = centerOfCirles + (Offset(-sqrt(3) / 2, 1 / 2) * distFromCenter) + circleCenterToTop + align;
                            //   githubOffset = centerOfCirles + (Offset(sqrt(3) / 2, 1 / 2) * distFromCenter) + circleCenterToTop + align;
                            // } else {
                            //   radius = min(constraints.maxWidth / 6, constraints.maxHeight / 2);
                            //   final centerInsteadOfRightAlign = Offset(-(constraints.maxWidth - 6 * radius) / 2, 0);
                            //   final align = isRow ? Offset.zero : centerInsteadOfRightAlign;

                            //   resumeOffset = Offset(constraints.maxWidth - 6 * radius, constraints.maxHeight / 2 - radius) + align;
                            //   linkedinOffset = Offset(constraints.maxWidth - 4 * radius, constraints.maxHeight / 2 - radius) + align;
                            //   githubOffset = Offset(constraints.maxWidth - 2 * radius, constraints.maxHeight / 2 - radius) + align;
                            // }

                            radius = min(constraints.maxWidth / 4, constraints.maxHeight / 2);
                            final centerInsteadOfRightAlign = Offset(-(constraints.maxWidth - 4 * radius) / 2, 0);
                            final align = isRow ? Offset.zero : centerInsteadOfRightAlign;

                            linkedinOffset = Offset(constraints.maxWidth - 4 * radius, constraints.maxHeight / 2 - radius) + align;
                            githubOffset = Offset(constraints.maxWidth - 2 * radius, constraints.maxHeight / 2 - radius) + align;

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
                                // buildCircle(resumeOffset, resumeKey, "Resume", () => window.open("static/Reuben Beeler Resume.pdf", "_blank"), NetworkImage("assets/resume.webp")), // make accentColor border programmatically
                                buildCircle(linkedinOffset, linkedinKey, "LinkedIn", () => launchUrl(Uri.parse("https://linkedin.com/in/ReubenBeeler/")), NetworkImage("assets/linkedin_circle.webp")),
                                buildCircle(githubOffset, githubKey, "Github", () => launchUrl(Uri.parse("https://github.com/ReubenBeeler/")), NetworkImage("assets/github_logo_clean.webp")),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Spacer(),
              Divider(color: accentColor, height: 4, thickness: 4),
            ],
          );
        },
      ),
    );
  }
}
