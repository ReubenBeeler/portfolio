import 'package:flutter/material.dart';
import 'package:portfolio/widgets/my_view.dart';
import 'package:portfolio/views/view_certifications.dart';
import 'package:portfolio/views/view_home.dart';
import 'package:portfolio/views/view_projects.dart';
import 'package:portfolio/views/view_publications.dart';
import 'package:portfolio/views/view_skills.dart';

List<MyView> views = [
  ViewHome(), //           navbar Size(58.0, 77.0)
  ViewProjects(), //       navbar Size(65.0, 77.0)
  ViewPublications(), //   navbar Size(93.5, 77.0)
  ViewSkills(), //         navbar Size(58.0, 77.0)
  ViewCertifications(), // navbar Size(101.2, 77.0)
];
final accentColor = Color.lerp(Color(0xFF00FFEE), Color(0xFF00B3FF), 0.3)!;

void main() {
  assert(views.isNotEmpty);
  const String title = "Measure NavBar buttons";
  final mainColor = Colors.red;
  final List<GlobalKey> keys = views.map((e) => GlobalKey()).toList();
  runApp(
    MaterialApp(
      title: title,
      color: accentColor,
      // theme: ...
      home: Scaffold(
        body: Column(
          children: [
            Row(
              children: List.generate(
                views.length,
                (i) => Container(
                  key: keys[i],
                  padding: const EdgeInsets.all(4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        views[i].icon,
                        color: mainColor,
                        size: 50,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        views[i].name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: mainColor,
                          fontSize: 15,
                          height: 1,
                          fontWeight: FontWeight.w400,
                        ),
                        // maxLines: 1,
                        // overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ).toList(),
            ),
            GestureDetector(
              onTap: () {
                for (var k in keys) {
                  print((k.currentContext?.findRenderObject() as RenderBox?)?.size);
                }
              },
              child: SizedBox.fromSize(
                size: Size(100, 100),
                child: ColoredBox(color: Colors.yellow),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
