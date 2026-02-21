import 'package:flutter/material.dart';
import 'package:portfolio/widgets/my_view.dart';
import 'package:portfolio/widgets/thumbnail_link_item.dart';

class ViewProjects extends StatelessView {
  ViewProjects({super.key}) : super(name: "Projects", icon: Icons.build_rounded);

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: 0.9,
      child: Column(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: ViewTitle('Featured $name'),
          ),
          Align(
            // taken from Publications
            alignment: AlignmentGeometry.topLeft, // topCenter
            child: ThumbnailLinkItem(
              title: 'Remote Keylogging Attacks in Multi-user VR Applications',
              linkUrl: 'https://www.usenix.org/conference/usenixsecurity24/presentation/su-zihao',
              image: NetworkImage('assets/keylogging_thumbnail.webp'),
            ),
          ),
          const SizedBox(height: 20),
          Align(
            alignment: AlignmentGeometry.topCenter,
            child: ThumbnailLinkItem(
              title: 'Buckshot, a collection of microservices for autonomous wildlife photography',
              linkUrl: 'https://buckshot.reubenbeeler.me/about',
              image: NetworkImage('assets/buckshot.webp'),
            ),
          ),
          const SizedBox(height: 20),
          Align(
            alignment: AlignmentGeometry.topRight,
            child: ThumbnailLinkItem(
              title: 'PAOA vs. QAOA, an optimizer benchmarker on SK Ising models',
              linkUrl: null, // 'https://github.com/ReubenBeeler/PAOA-vs-QAOA',
              image: NetworkImage('assets/PAOA vs QAOA thumbnail.webp'),
            ),
          ),
          // const SizedBox(height: 20),
          // Align(
          //   alignment: AlignmentGeometry.topRight,
          //   child: ThumbnailLinkItem(
          //     title: 'Bike-Generator, a plug-and-play generator for ordinary bikes',
          //     linkUrl: 'https://github.com/ReubenBeeler/Bike-Generator',
          //     image: NetworkImage('assets/generator_thumbnail.webp'),
          //   ),
          // ),
          // const SizedBox(height: 20),
          // Align(
          //   alignment: AlignmentGeometry.topLeft,
          //   child: ThumbnailLinkItem(
          //     inProgress: true,
          //     title: 'Auchanic, a music composition tool for identifying dissonance',
          //     linkUrl: null,
          //     image: NetworkImage('assets/auchanic_thumbnail.webp'),
          //   ),
          // ),
          // const SizedBox(height: 20),
          // Align(
          //   alignment: AlignmentGeometry.topRight,
          //   child: ThumbnailLinkItem(
          //     title: 'Compass, a Minecraft Spigot plug-in for live player tracking',
          //     linkUrl: 'https://github.com/ReubenBeeler/Compass',
          //     image: NetworkImage('assets/compass_thumbnail.webp'),
          //   ),
          // ),
        ],
      ),
    );
  }
}
