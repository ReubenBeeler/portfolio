import 'package:flutter/material.dart';
import 'package:portfolio/my_view.dart';
import 'package:portfolio/thumbnail_link_item.dart';

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
            alignment: AlignmentGeometry.topLeft,
            child: ThumbnailLinkItem(
              inProgress: true,
              title: 'Auchanic, a music composition tool for identifying dissonance',
              linkUrl: null,
              image: AssetImage('assets/auchanic_thumbnail.webp'),
            ),
          ),
          const SizedBox(height: 20),
          Align(
            alignment: AlignmentGeometry.topCenter,
            child: ThumbnailLinkItem(
              title: 'PAOA vs. QAOA, an optimizer benchmarker on SK Ising models',
              linkUrl: null, // 'https://github.com/ReubenBeeler/PAOA-vs-QAOA',
              image: AssetImage('assets/PAOA vs QAOA thumbnail.webp'),
            ),
          ),
          const SizedBox(height: 20),
          Align(
            alignment: AlignmentGeometry.topRight,
            child: ThumbnailLinkItem(
              title: 'Bike-Generator, a plug-and-play generator for ordinary bikes',
              linkUrl: 'https://github.com/ReubenBeeler/Bike-Generator',
              image: AssetImage('assets/generator_thumbnail.webp'),
            ),
          ),
          // const SizedBox(height: 20),
          // Align(
          //   alignment: AlignmentGeometry.topRight,
          //   child: ThumbnailLinkItem(
          //     title: 'Compass, a Minecraft Spigot plug-in for live player tracking',
          //     linkUrl: 'https://github.com/ReubenBeeler/Compass',
          //     image: AssetImage('assets/compass_thumbnail.webp'),
          //   ),
          // ),
        ],
      ),
    );
  }
}
