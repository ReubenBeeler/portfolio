import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:portfolio/main.dart';

mixin MyView on Widget {
  String get name;
  IconData get icon;
  GlobalKey get globalKey;
  Future Function()? get precache;
}

abstract class StatefulView extends StatefulWidget with MyView {
  @override
  final String name;
  @override
  final IconData icon;
  @override
  final Future Function()? precache;
  StatefulView({GlobalKey? key, required this.name, required this.icon, this.precache}) : super(key: key ?? GlobalKey());

  @override
  GlobalKey<State<StatefulWidget>> get globalKey => key as GlobalKey;
}

abstract class StatelessView extends StatelessWidget with MyView {
  @override
  final String name;
  @override
  final IconData icon;
  @override
  final Future Function()? precache;
  StatelessView({GlobalKey? key, required this.name, required this.icon, this.precache}) : super(key: key ?? GlobalKey());

  @override
  GlobalKey<State<StatefulWidget>> get globalKey => key as GlobalKey;
}

class ViewTitle extends StatelessWidget {
  final String text;
  const ViewTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(0, 10, 0, 0),
          child: Text(
            text,
            style: GoogleFonts.roboto(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  offset: Offset(0, 2),
                  blurRadius: 4,
                  color: Colors.black.withValues(alpha: 0.8),
                ),
                Shadow(
                  offset: Offset(0, 0),
                  blurRadius: 8,
                  color: Colors.black.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
        Divider(
          color: accentColor,
          height: 4,
          thickness: 4,
        ),
        SizedBox(height: 20),
      ],
    );
  }
}
