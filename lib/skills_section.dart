import 'package:flutter/gestures.dart' show TapGestureRecognizer;
import 'package:flutter/material.dart';
import 'package:portfolio/my_card.dart';
import 'package:portfolio/my_view.dart';
import 'package:portfolio/staggered_grid.dart';

class SkillsSection extends StatelessWidget {
  final ScrollController _controller = ScrollController();

  final List<SkillCategory> skillCategories;

  SkillsSection({
    super.key,
    required this.skillCategories,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ViewTitle('Featured Skills'),
        // StaggeredGrid(children: skillCategories.map(_buildSkillCard).toList()),
        LayoutBuilder(
          builder: (context, constraints) => ScrollbarTheme(
            data: ScrollbarThemeData(
              thumbColor: WidgetStateProperty.all(Colors.grey), //accentColor),
              trackColor: WidgetStateProperty.all(Color(0xCF000000)),
            ),
            child: Scrollbar(
              controller: _controller,
              thumbVisibility: true,
              trackVisibility: true,
              scrollbarOrientation: ScrollbarOrientation.top,
              thickness: 4.0,
              radius: const Radius.circular(2.0),
              interactive: true,
              child: SingleChildScrollView(
                controller: _controller,
                scrollDirection: Axis.horizontal,
                child: Container(
                  padding: const EdgeInsets.only(top: 10.0), // for scroll thumb/track
                  child: StaggeredGrid(
                    // Horiz ScrollView in case skill cards don't fit on page (but let StaggeredGrid still think width is constrained so it doesn't just make 1 row with all children).
                    maxWidth: constraints.maxWidth,
                    children: skillCategories.map(_buildSkillCard).toList(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSkillCard(SkillCategory category) {
    return MyCard(
      child: IntrinsicWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category Title
            Row(
              children: [
                Container(
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF00B3FF),
                        const Color(0xFF00FFEE),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    category.title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          blurRadius: 4.0,
                          color: Colors.black.withValues(alpha: 0.3),
                          offset: const Offset(1.0, 1.0),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.0),
            ...category.skills,
          ],
        ),
      ),
    );
  }
}

class SkillCategory {
  static const bodyStyle = TextStyle(
    fontSize: 16,
    color: Color(0xE5FFFFFF),
    fontWeight: FontWeight.w500,
    shadows: [
      Shadow(
        blurRadius: 2.0,
        color: Color(0x4C000000),
        offset: Offset(1.0, 1.0),
      ),
    ],
  );
  static const TextStyle hyperlinkStyle = TextStyle(
    color: Colors.blue,
    decoration: TextDecoration.underline,
    decorationColor: Colors.blue,
  );

  final String title;
  late final List<Widget> skills;

  SkillCategory({
    required this.title,
    required List<dynamic> skills,
  }) {
    this.skills = List.generate(skills.length, (i) {
      var line = skills[i];
      assert(line is String || line is List);

      bool isIndented = false;
      if (line is List && line.isNotEmpty && line.first == null) {
        isIndented = true;
        line = line.skip(1).toList(); // Remove the bool from the line
      }

      Widget text = (line is String)
          ? Text(line, style: bodyStyle)
          : RichText(
              text: TextSpan(
                style: bodyStyle,
                children: [
                  for (int j = 0; j < line.length; ++j)
                    () {
                      String string = line[j];
                      dynamic next = (j + 1 < line.length) ? line[j + 1] : null;
                      TextSpan ret = TextSpan(
                        text: string,
                        recognizer: next is VoidCallback ? (TapGestureRecognizer()..onTap = next) : null,
                        style: next is VoidCallback ? hyperlinkStyle : null, // inherits bodyStyle
                      );
                      if (next is VoidCallback) ++j;
                      return ret;
                    }(),
                ],
              ),
            );
      return Container(
        margin: const EdgeInsets.only(top: 8.0),
        child: Row(
          children: [
            SizedBox(width: isIndented ? 24 : 0), // Indentation space
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: isIndented ? Colors.transparent : const Color(0xFF00FFEE),
                border: isIndented ? Border.all(color: const Color(0xFF00FFEE), width: 1) : null,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00FFEE).withValues(alpha: isIndented ? 0.3 : 0.5),
                    blurRadius: isIndented ? 3 : 4,
                    spreadRadius: isIndented ? 0.5 : 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: text),
          ],
        ),
      );
    });
  }
}

// Example usage:
class PortfolioExample extends StatelessWidget {
  const PortfolioExample({super.key});

  @override
  Widget build(BuildContext context) {
    final skillCategories = [
      SkillCategory(
        title: 'Programming Languages',
        skills: ['Python', 'C++', 'Java', 'Objective-C', 'Dart', 'Bash'],
      ),
      SkillCategory(
        title: 'Mobile Development',
        skills: ['Flutter', 'React Native', 'iOS Development', 'Android'],
      ),
      SkillCategory(
        title: 'Web Technologies',
        skills: ['React', 'Node.js', 'TypeScript', 'HTML/CSS'],
      ),
      SkillCategory(
        title: 'Databases',
        skills: ['PostgreSQL', 'MongoDB', 'Firebase', 'SQLite'],
      ),
    ];

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF00FFEE).withValues(alpha: 0.3),
              Colors.grey.shade400,
              const Color(0xFF00CCDD).withValues(alpha: 0.4),
            ],
          ),
        ),
        child: SingleChildScrollView(
          child: SkillsSection(skillCategories: skillCategories),
        ),
      ),
    );
  }
}

void main() {
  runApp(MaterialApp(home: PortfolioExample()));
}
