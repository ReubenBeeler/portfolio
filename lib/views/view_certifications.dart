import 'package:flutter/material.dart';
import 'package:portfolio/widgets/my_view.dart';
import 'package:url_launcher/url_launcher.dart';

class ViewCertifications extends StatelessView {
  ViewCertifications({super.key}) : super(name: "Certifications", icon: Icons.verified_rounded);

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.sizeOf(context);
    final double widthFactor = 0.9;
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ViewTitle(name),
          Center(
            // replace Wrap with GridView?
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 40.0,
              runSpacing: 40.0,
              children: [
                SizedBox(
                  height: 0.5 * screenSize.height,
                  child: IconButton(
                    style: IconButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    icon: Image.network("assets/IBM Applied DevOps Engineering Certificate.webp"),
                    onPressed: () => launchUrl(Uri.parse("https://www.credly.com/badges/b3e055ee-ed80-441a-abcf-10bd80ed8d8f/public_url")),
                  ),
                ),
                SizedBox(
                  height: 0.5 * screenSize.height,
                  child: IconButton(
                    icon: Image.network("assets/java_badge.webp"),
                    onPressed: () => launchUrl(Uri.parse("https://www.credly.com/badges/d2f3e39d-df46-4e1d-af16-4c3aae7bcbda/public_url")),
                  ),
                ),
              ],
            ),
          ),
          // TODO include pending certificates widget!
        ],
      ),
    );
  }
}
