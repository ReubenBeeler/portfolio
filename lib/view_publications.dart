import 'package:flutter/material.dart';
import 'package:portfolio/my_view.dart';
import 'package:portfolio/thumbnail_link_item.dart';

class ViewPublications extends StatelessView {
  ViewPublications({super.key}) : super(name: "Publications", icon: Icons.article_rounded);

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: 0.9,
      child: Column(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: ViewTitle(name),
          ),
          ThumbnailLinkItem(
            title: 'Remote Keylogging Attacks in Multi-user VR Applications',
            linkUrl: 'https://www.usenix.org/conference/usenixsecurity24/presentation/su-zihao',
            image: AssetImage('assets/keylogging_thumbnail.png'),
          ),
        ],
      ),
    );
  }
}
