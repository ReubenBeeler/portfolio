import 'package:flutter/material.dart';
import 'package:portfolio/main.dart';
import 'package:portfolio/widgets/my_card.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Portfolio Publications',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const PublicationsDemo(),
    );
  }
}

class PublicationsDemo extends StatelessWidget {
  const PublicationsDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Publications'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Publications',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 20),
            const ThumbnailLinkItem(
              title: 'Machine Learning in Healthcare: A Comprehensive Review',
              linkUrl: 'https://example.com/ml-healthcare-paper',
              image: NetworkImage('https://images.unsplash.com/photo-1559757148-5c350d0d3c56?w=600&h=400&fit=crop&crop=center'),
            ),
            const SizedBox(height: 24),
            const ThumbnailLinkItem(
              title: 'Sustainable Energy Systems: Future Perspectives',
              linkUrl: 'https://example.com/energy-systems-paper',
              image: NetworkImage('https://images.unsplash.com/photo-1473341304170-971dccb5ac1e?w=600&h=400&fit=crop&crop=center'),
            ),
            const SizedBox(height: 24),
            const ThumbnailLinkItem(
              title: 'Neural Networks for Climate Prediction',
              linkUrl: 'https://example.com/neural-climate-paper',
              image: NetworkImage('https://images.unsplash.com/photo-1451187580459-43490279c0fa?w=600&h=400&fit=crop&crop=center'),
            ),
            const SizedBox(height: 24),
            const ThumbnailLinkItem(
              title: 'Quantum Computing in Cryptography',
              linkUrl: 'https://example.com/quantum-crypto-paper',
              image: NetworkImage('https://images.unsplash.com/photo-1518709268805-4e9042af2176?w=600&h=400&fit=crop&crop=center'),
            ),
            const SizedBox(height: 24),
            const ThumbnailLinkItem(
              title: 'Data Science Applications in Modern Biology',
              linkUrl: 'https://example.com/biology-data-paper',
              image: NetworkImage('https://images.unsplash.com/photo-1532187863486-abf9dbad1b69?w=600&h=400&fit=crop&crop=center'),
            ),
            const SizedBox(height: 24),
            const ThumbnailLinkItem(
              title: 'Advanced Algorithms for Financial Markets',
              linkUrl: 'https://example.com/finance-algorithms-paper',
              image: NetworkImage('https://images.unsplash.com/photo-1611974789855-9c2a0a7236a3?w=600&h=400&fit=crop&crop=center'),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconLink extends StatelessWidget {
  final String? linkUrl;
  const _IconLink({this.linkUrl});

  @override
  Widget build(BuildContext context) {
    Widget icon = Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Icon(
        linkUrl == null ? Icons.question_mark : Icons.open_in_new,
        size: 30,
        color: accentColor,
      ),
    );
    if (linkUrl != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            final Uri url = Uri.parse(linkUrl!);
            if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
              debugPrint('Could not launch $linkUrl');
            }
          },
          borderRadius: BorderRadius.circular(23),
          child: icon,
        ),
      );
    } else {
      return Tooltip(
        message: 'Private project! Contact me for details',
        child: Material(
          color: Colors.transparent,
          child: icon,
        ),
      );
    }
  }
}

class ThumbnailLinkItem extends StatelessWidget {
  final bool inProgress;
  final String title;
  final String? linkUrl;
  final ImageProvider image;

  const ThumbnailLinkItem({
    super.key,
    this.inProgress = false,
    required this.title,
    required this.linkUrl,
    required this.image,
  });

  @override
  Widget build(BuildContext context) {
    // TODO make the whole thumbnail or card clickable instead of just the icon in the upper right
    return MyCard(
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(
          maxWidth: 800,
        ),
        // decoration: BoxDecoration(
        //   color: Colors.grey[700],
        //   borderRadius: BorderRadius.circular(16),
        //   boxShadow: [
        //     BoxShadow(
        //       color: Colors.grey.withValues(alpha: 0.12),
        //       spreadRadius: 1,
        //       blurRadius: 12,
        //       offset: const Offset(0, 4),
        //     ),
        //   ],
        //   border: Border.all(
        //     color: Colors.grey.withValues(alpha: 0.15),
        //     width: 1,
        //   ),
        // ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title and Icon Row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
              child: Row(
                children: [
                  // Title
                  Expanded(
                    child: RichText(
                      // maxLines: 2,
                      // overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                        children: [
                          if (inProgress)
                            TextSpan(
                              text: 'In Progress: ',
                              style: TextStyle(color: Colors.amber),
                            ),
                          TextSpan(
                            text: title,
                            style: TextStyle(color: Colors.grey[100]),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _IconLink(linkUrl: linkUrl),
                ],
              ),
            ),

            // Large Thumbnail Image
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(
                  minHeight: 200,
                  // maxHeight: 600,
                ),
                decoration: BoxDecoration(
                  border: BoxBorder.all(color: Colors.black, width: 4),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      spreadRadius: 1,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image(
                    image: image,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: double.infinity,
                        height: 250,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.article_outlined,
                              color: Colors.grey[500],
                              size: 48,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Missing Thumbnail',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        width: double.infinity,
                        height: 250,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes! : null,
                            strokeWidth: 2,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
