import 'package:flutter/material.dart';
import 'package:disaster_resilience_ai/models/disaster_news_model.dart';

class AllNewsPage extends StatelessWidget {
  const AllNewsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? const Color(0xFF0F140F) : const Color(0xFFF0F2F5);
    final barBg = isDark ? const Color(0xFF1B251B) : Colors.white;
    final titleColor = isDark
        ? const Color(0xFFE5E7EB)
        : const Color(0xFF1E293B);
    final subtitleColor = isDark
        ? const Color(0xFF9AA79B)
        : const Color(0xFF64748B);
    final dividerColor = isDark
        ? const Color(0xFF334236)
        : const Color(0xFF2D5927).withAlpha(26);
    final articles = DisasterNewsData.articles;

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: barBg,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 1,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? const Color(0xFF9EDB94) : const Color(0xFF2E7D32),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Disaster News & Info',
              style: TextStyle(
                color: titleColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              'Guides, updates & preparedness',
              style: TextStyle(color: subtitleColor, fontSize: 12),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: dividerColor),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: articles.length,
        itemBuilder: (context, index) =>
            _buildArticleTile(context, articles[index], isDark),
      ),
    );
  }

  Widget _buildArticleTile(
    BuildContext context,
    DisasterNews article,
    bool isDark,
  ) {
    final surface = isDark ? const Color(0xFF1B251B) : Colors.white;
    final border = isDark ? const Color(0xFF334236) : const Color(0xFFE8E8E8);
    final titleColor = isDark
        ? const Color(0xFFE5E7EB)
        : const Color(0xFF1E293B);
    final bodyColor = isDark
        ? const Color(0xFFB8C2BA)
        : const Color(0xFF64748B);
    final metaColor = isDark
        ? const Color(0xFF9AA79B)
        : const Color(0xFF6B7280);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => NewsDetailPage(article: article)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Coloured category strip
            Container(
              height: 5,
              decoration: BoxDecoration(
                color: article.accentColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: article.accentColor.withAlpha(28),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      article.icon,
                      color: article.accentColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: article.accentColor.withAlpha(22),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            article.category,
                            style: TextStyle(
                              color: article.accentColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          article.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: titleColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          article.summary,
                          style: TextStyle(
                            color: bodyColor,
                            fontSize: 12,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 12,
                              color: metaColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${article.readMinutes} min read',
                              style: TextStyle(color: metaColor, fontSize: 11),
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              Icons.source_rounded,
                              size: 12,
                              color: metaColor,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                article.source,
                                style: TextStyle(
                                  color: metaColor,
                                  fontSize: 11,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: metaColor, size: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NewsDetailPage extends StatelessWidget {
  final DisasterNews article;

  const NewsDetailPage({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? const Color(0xFF0F140F) : Colors.white;
    final titleColor = isDark
        ? const Color(0xFFE5E7EB)
        : const Color(0xFF1E293B);
    final bodyColor = isDark
        ? const Color(0xFFB8C2BA)
        : const Color(0xFF334155);
    final metaColor = isDark
        ? const Color(0xFF9AA79B)
        : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: pageBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            backgroundColor: article.accentColor,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      article.accentColor,
                      article.accentColor.withAlpha(200),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(50),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          article.category,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        article.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Meta row
                  Row(
                    children: [
                      Icon(article.icon, color: article.accentColor, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        article.source,
                        style: TextStyle(
                          color: article.accentColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.access_time_rounded,
                        color: metaColor,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${article.readMinutes} min read',
                        style: TextStyle(color: metaColor, fontSize: 12),
                      ),
                    ],
                  ),
                  Divider(
                    height: 24,
                    color: isDark ? const Color(0xFF334236) : null,
                  ),
                  // Summary callout
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: article.accentColor.withAlpha(15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: article.accentColor.withAlpha(60),
                      ),
                    ),
                    child: Text(
                      article.summary,
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: article.accentColor,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Body
                  ..._parseBody(article.body, titleColor, bodyColor),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _parseBody(String body, Color titleColor, Color bodyColor) {
    final paragraphs = body.split('\n\n');
    return paragraphs.map<Widget>((para) {
      para = para.trim();
      if (para.isEmpty) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: _renderParagraph(para, titleColor, bodyColor),
      );
    }).toList();
  }

  Widget _renderParagraph(String para, Color titleColor, Color bodyColor) {
    final spans = <TextSpan>[];
    const regex = r'\*\*(.*?)\*\*';
    final baseStyle = TextStyle(fontSize: 14, color: bodyColor, height: 1.65);
    final boldStyle = baseStyle.copyWith(
      fontWeight: FontWeight.bold,
      color: titleColor,
    );

    int last = 0;
    for (final match in RegExp(regex).allMatches(para)) {
      if (match.start > last) {
        spans.add(
          TextSpan(text: para.substring(last, match.start), style: baseStyle),
        );
      }
      spans.add(TextSpan(text: match.group(1), style: boldStyle));
      last = match.end;
    }
    if (last < para.length) {
      spans.add(TextSpan(text: para.substring(last), style: baseStyle));
    }

    return RichText(text: TextSpan(children: spans));
  }
}
