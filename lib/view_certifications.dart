import 'package:flutter/material.dart';
import 'package:portfolio/my_view.dart';
import 'package:url_launcher/url_launcher.dart';

class ViewCertifications extends StatelessView {
  ViewCertifications({super.key}) : super(name: "Certifications", icon: Icons.verified_rounded);

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    return FractionallySizedBox(
      widthFactor: 0.9,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ViewTitle(name),
          Center(
            child: SizedBox(
              height: 0.50 * screenSize.height,
              child: IconButton(
                icon: Image.asset("assets/java_badge.png"),
                onPressed: () => launchUrl(Uri.parse("https://www.credly.com/badges/d2f3e39d-df46-4e1d-af16-4c3aae7bcbda/public_url")),
              ), // make a gridview once I have more...
            ),
          ),
        ],
      ),
    );
  }
}
