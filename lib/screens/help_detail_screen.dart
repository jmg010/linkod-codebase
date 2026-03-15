import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../ui_constants.dart';
import 'help_center_screen.dart';

class HelpDetailScreen extends StatelessWidget {
  final HelpCategory category;

  const HelpDetailScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey.shade100,
      appBar: AppBar(
        title: Text(category.title),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        titleTextStyle: TextStyle(
          color: const Color(0xFF4CAF50),
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(kPaddingSmall),
        itemCount: category.articles.length,
        itemBuilder: (context, index) {
          final article = category.articles[index];
          return HelpArticleCard(article: article);
        },
      ),
    );
  }
}

class HelpArticleCard extends StatefulWidget {
  final HelpArticle article;

  const HelpArticleCard({super.key, required this.article});

  @override
  State<HelpArticleCard> createState() => _HelpArticleCardState();
}

class _HelpArticleCardState extends State<HelpArticleCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: kPaddingSmall / 2),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(kCardRadius),
            ),
            child: Padding(
              padding: const EdgeInsets.all(kPaddingMedium),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.article.title,
                      style: kHeadlineSmall.copyWith(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                kPaddingMedium,
                0,
                kPaddingMedium,
                kPaddingMedium,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(kCardRadius),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.article.content,
                    style: kBodyText.copyWith(
                      color:
                          isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: kPaddingMedium),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: widget.article.content),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                'Content copied to clipboard',
                              ),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copy'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF4CAF50),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
