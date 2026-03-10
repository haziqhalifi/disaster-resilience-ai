import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:disaster_resilience_ai/localization/app_language.dart';
import 'package:disaster_resilience_ai/services/chatbot_service.dart';
import 'package:disaster_resilience_ai/ui/widgets/landa_wordmark.dart';

enum _Sender { user, bot }

class _ChatMessage {
  final String text;
  final _Sender sender;
  final DateTime time;

  _ChatMessage({required this.text, required this.sender})
    : time = DateTime.now();
}

class ChatbotPage extends StatefulWidget {
  const ChatbotPage({super.key});

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage>
    with TickerProviderStateMixin {
  final _chatbot = ChatbotService();
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isTyping = false;
  bool _isScrolled = false;
  bool _welcomeInitialized = false;

  static const _botGreen = Color(0xFF2E7D32);
  static const _botBubble = Color(0xFFE8F5E9);
  static const _userBubble = Color(0xFF2E7D32);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_welcomeInitialized) return;
    _welcomeInitialized = true;
    final language = AppLanguageScope.of(context).language;
    _messages.add(
      _ChatMessage(text: _welcomeText(language), sender: _Sender.bot),
    );
  }

  String _welcomeText(AppLanguage language) {
    return switch (language) {
      AppLanguage.english =>
        'Hi there! 👋 I\'m your LANDA assistant.\n\nAsk me anything about floods, earthquakes, evacuation, emergency kits, or how to use this app!',
      AppLanguage.malay =>
        'Hai! 👋 Saya pembantu LANDA anda.\n\nTanya saya apa-apa tentang banjir, gempa bumi, pemindahan, kit kecemasan, atau cara menggunakan aplikasi ini!',
      AppLanguage.chinese =>
        '你好！👋 我是你的 LANDA 助手。\n\n你可以问我任何关于洪水、地震、撤离、应急包，或如何使用本应用的问题！',
    };
  }

  List<String> _localizedSuggestions(AppLanguage language) {
    return switch (language) {
      AppLanguage.english => ChatbotService.suggestions,
      AppLanguage.malay => const [
        'Apa perlu dibuat semasa banjir?',
        'Bagaimana jika gempa bumi berlaku?',
        'Apa ada dalam kit kecemasan?',
        'Bagaimana cari pusat pemindahan?',
      ],
      AppLanguage.chinese => const [
        '洪水时我该怎么做？',
        '地震发生时怎么办？',
        '应急包里应该有什么？',
        '如何找到疏散中心？',
      ],
    };
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final next = _scrollController.offset > 2;
    if (next != _isScrolled && mounted) {
      setState(() => _isScrolled = next);
    }
  }

  Future<void> _send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    _textController.clear();
    setState(() {
      _messages.add(_ChatMessage(text: trimmed, sender: _Sender.user));
      _isTyping = true;
    });
    _scrollToBottom();

    // Simulate typing delay for realism
    await Future.delayed(const Duration(milliseconds: 800));

    final reply = _chatbot.getResponse(trimmed);
    if (!mounted) return;
    setState(() {
      _isTyping = false;
      _messages.add(_ChatMessage(text: reply, sender: _Sender.bot));
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final language = AppLanguageScope.of(context).language;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? const Color(0xFF0F140F) : Colors.white;
    final barBg = isDark ? const Color(0xFF1B251B) : _botGreen;
    final botBubble = isDark ? const Color(0xFF223123) : _botBubble;
    final botText = isDark ? const Color(0xFFE5E7EB) : const Color(0xFF1E293B);
    final suggestionBg = isDark ? const Color(0xFF223123) : _botBubble;
    final suggestionBorder = isDark
        ? const Color(0xFF86C77C).withAlpha(120)
        : _botGreen.withAlpha(128);
    final suggestionText = isDark
        ? const Color(0xFF9EDB94)
        : const Color(0xFF2E7D32);
    final inputBarBg = isDark ? const Color(0xFF1B251B) : Colors.white;
    final inputFieldBg = isDark
        ? const Color(0xFF243024)
        : const Color(0xFFF5F5F5);
    final inputText = isDark
        ? const Color(0xFFE5E7EB)
        : const Color(0xFF111827);

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: _isScrolled
            ? barBg.withAlpha(isDark ? 220 : 240)
            : barBg,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        flexibleSpace: _isScrolled
            ? ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    decoration: BoxDecoration(
                      color: barBg.withAlpha(isDark ? 180 : 210),
                      border: Border(
                        bottom: BorderSide(
                          color:
                              (isDark
                                      ? const Color(0xFF334236)
                                      : Colors.white.withAlpha(120))
                                  .withAlpha(120),
                        ),
                      ),
                    ),
                  ),
                ),
              )
            : null,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const LandaBrandTitle(
                  wordmarkSize: 19,
                  iconColor: Colors.white,
                  wordmarkColors: [Color(0xFFFFFFFF), Color(0xFFEAF7E7)],
                  wordmarkStrokeColor: Color(0x66FFFFFF),
                ),
                Text(
                  switch (language) {
                    AppLanguage.english => 'Assistant Chatbot',
                    AppLanguage.malay => 'Pembantu Chatbot',
                    AppLanguage.chinese => '智能助手',
                  },
                  style: TextStyle(
                    color: Colors.white.withAlpha(204),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Message list ─────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isTyping && index == _messages.length) {
                  return _buildTypingIndicator();
                }
                final msg = _messages[index];
                return _buildBubble(msg, botBubble, botText);
              },
            ),
          ),
          // ── Suggestions (shown only when last message is from bot) ───
          if (!_isTyping &&
              _messages.isNotEmpty &&
              _messages.last.sender == _Sender.bot &&
              _messages.length == 1)
            _buildSuggestions(
              suggestionBg,
              suggestionBorder,
              suggestionText,
              language,
            ),
          // ── Input bar ────────────────────────────────────────────────
          _buildInputBar(inputBarBg, inputFieldBg, inputText),
        ],
      ),
    );
  }

  Widget _buildBubble(_ChatMessage msg, Color botBubble, Color botText) {
    final isUser = msg.sender == _Sender.user;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: _botGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.smart_toy_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? _userBubble : botBubble,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(13),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _buildMessageText(msg.text, isUser, botText),
            ),
          ),
          if (isUser) const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildMessageText(String text, bool isUser, Color botText) {
    // Render **bold** markdown inline
    final spans = <TextSpan>[];
    final baseStyle = TextStyle(
      color: isUser ? Colors.white : botText,
      fontSize: 14,
      height: 1.5,
    );
    final boldStyle = baseStyle.copyWith(fontWeight: FontWeight.bold);

    final regex = RegExp(r'\*\*(.*?)\*\*');
    int last = 0;
    for (final match in regex.allMatches(text)) {
      if (match.start > last) {
        spans.add(
          TextSpan(text: text.substring(last, match.start), style: baseStyle),
        );
      }
      spans.add(TextSpan(text: match.group(1), style: boldStyle));
      last = match.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last), style: baseStyle));
    }

    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildTypingIndicator() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final botBubble = isDark ? const Color(0xFF223123) : _botBubble;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              color: _botGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.smart_toy_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: botBubble,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
            ),
            child: _TypingDots(),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestions(
    Color suggestionBg,
    Color suggestionBorder,
    Color suggestionText,
    AppLanguage language,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _localizedSuggestions(language).map((suggestion) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => _send(suggestion),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: suggestionBorder),
                    borderRadius: BorderRadius.circular(20),
                    color: suggestionBg,
                  ),
                  child: Text(
                    suggestion,
                    style: TextStyle(
                      color: suggestionText,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildInputBar(Color inputBarBg, Color inputFieldBg, Color inputText) {
    final language = AppLanguageScope.of(context).language;
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 8,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: inputBarBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(18),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(color: inputText),
              decoration: InputDecoration(
                hintText: switch (language) {
                  AppLanguage.english => 'Ask about disasters...',
                  AppLanguage.malay => 'Tanya tentang bencana...',
                  AppLanguage.chinese => '询问灾害相关问题...',
                },
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                filled: true,
                fillColor: inputFieldBg,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: _send,
              maxLines: null,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _send(_textController.text),
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: _botGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated three-dot typing indicator.
class _TypingDots extends StatefulWidget {
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _animations = List.generate(3, (i) {
      final start = i * 0.2;
      return Tween<double>(begin: 0, end: -6).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(start, start + 0.4, curve: Curves.easeInOut),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Transform.translate(
                offset: Offset(0, _animations[i].value),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32).withAlpha(180),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
