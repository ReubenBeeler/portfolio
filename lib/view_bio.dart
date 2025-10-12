import 'package:flutter/material.dart';
import 'package:portfolio/main.dart';
import 'package:portfolio/my_view.dart';

class ViewBio extends StatelessView with MyView {
  final Size size;
  ViewBio({super.key, required this.size}) : super(name: "Bio", icon: Icons.person_rounded);

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: size,
      child: Column(
        children: [
          Spacer(),
          Expanded(
            flex: 6,
            child: Row(
              children: [
                Spacer(),
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: BoxBorder.all(color: accentColor),
                      image: DecorationImage(
                        image: NetworkImage("assets/bio_pic.jpeg"),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                Spacer(),
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                      border: BoxBorder.all(color: accentColor),
                    ),
                  ),
                ),
                Spacer(),
              ],
            ),
          ),
          Spacer(),
        ],
      ),
    );
  }
}
