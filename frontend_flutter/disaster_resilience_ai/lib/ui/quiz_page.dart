import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:disaster_resilience_ai/services/api_service.dart';
import 'package:disaster_resilience_ai/localization/app_language.dart';

/// AI-driven adaptive quiz page for a specific hazard type.
class QuizPage extends StatefulWidget {
  final String hazardType;
  final String hazardTitle;
  final Color themeColor;

  const QuizPage({
    super.key,
    required this.hazardType,
    required this.hazardTitle,
    required this.themeColor,
  });

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final ApiService _api = ApiService();
  String? _accessToken;

  // Quiz state
  bool _loading = true;
  String? _error;
  String _adaptiveInfo = '';
  List<Map<String, dynamic>> _questions = [];
  Map<int, String> _selectedAnswers = {}; // index -> A/B/C/D
  int _currentQuestion = 0;

  // Results state
  bool _submitted = false;
  bool _submitting = false;
  Map<String, dynamic>? _results;

  @override
  void initState() {
    super.initState();
    _init();
  }

  String _tr({required String en, required String ms, String? zh}) {
    final lang = AppLanguageScope.of(context).language;
    if (lang == AppLanguage.malay) return ms;
    if (lang == AppLanguage.chinese) return zh ?? en;
    return en;
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('auth_access_token');
    if (_accessToken == null) {
      setState(() {
        _error = 'Not signed in';
        _loading = false;
      });
      return;
    }
    await _generateQuiz();
  }

  Future<void> _generateQuiz() async {
    setState(() {
      _loading = true;
      _error = null;
      _submitted = false;
      _results = null;
      _selectedAnswers = {};
      _currentQuestion = 0;
    });
    try {
      final data = await _api.generateQuiz(
        accessToken: _accessToken!,
        hazardType: widget.hazardType,
      );
      final questions = (data['questions'] as List)
          .map((q) => q as Map<String, dynamic>)
          .toList();
      setState(() {
        _questions = questions;
        _adaptiveInfo = data['adaptive_info'] as String? ?? '';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _submitQuiz() async {
    if (_selectedAnswers.length < _questions.length) return;
    setState(() => _submitting = true);

    try {
      final answers = _questions.map((q) {
        final idx = q['index'] as int;
        return {
          'question_text': q['text'] as String,
          'selected': _selectedAnswers[idx]!,
        };
      }).toList();

      final result = await _api.submitQuiz(
        accessToken: _accessToken!,
        hazardType: widget.hazardType,
        answers: answers,
      );

      setState(() {
        _results = result;
        _submitted = true;
        _submitting = false;
      });
    } catch (e) {
      setState(() {
        _submitting = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? const Color(0xFF0F140F) : const Color(0xFFF0F2F5);
    final barBg = isDark ? const Color(0xFF1B251B) : Colors.white;
    final titleColor = isDark
        ? const Color(0xFFE5E7EB)
        : const Color(0xFF1E293B);
    final divColor = isDark
        ? const Color(0xFF334236)
        : const Color(0xFF2D5927).withAlpha(26);

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: barBg,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 1,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: titleColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _tr(en: 'Quiz', ms: 'Kuiz', zh: '测验'),
          style: TextStyle(
            color: titleColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: divColor),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
            )
          : _error != null
          ? _buildErrorView(isDark)
          : _submitted
          ? _buildResultsView(isDark)
          : _buildQuizView(isDark),
    );
  }

  // ── Error ─────────────────────────────────────────────────────────────

  Widget _buildErrorView(bool isDark) {
    final textColor = isDark
        ? const Color(0xFF9AA79B)
        : const Color(0xFF64748B);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.red[400], size: 48),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: textColor, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _generateQuiz,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.themeColor,
              ),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Quiz View ─────────────────────────────────────────────────────────

  Widget _buildQuizView(bool isDark) {
    final cardBg = isDark ? const Color(0xFF1B251B) : Colors.white;
    final titleColor = isDark
        ? const Color(0xFFE5E7EB)
        : const Color(0xFF1E293B);
    final bodyColor = isDark
        ? const Color(0xFFCCD3CD)
        : const Color(0xFF374151);
    final subtitleColor = isDark
        ? const Color(0xFF9AA79B)
        : const Color(0xFF64748B);

    if (_questions.isEmpty) {
      return Center(
        child: Text(
          _tr(en: 'No questions available', ms: 'Tiada soalan', zh: '没有可用的问题'),
          style: TextStyle(color: subtitleColor),
        ),
      );
    }

    final q = _questions[_currentQuestion];
    final options = (q['options'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, v as String),
    );
    final idx = q['index'] as int;
    final phase = q['phase'] as String;
    final diff = q['difficulty'] as int;
    final allAnswered = _selectedAnswers.length == _questions.length;

    return Column(
      children: [
        // Progress bar
        LinearProgressIndicator(
          value: (_currentQuestion + 1) / _questions.length,
          backgroundColor: isDark
              ? widget.themeColor.withAlpha(40)
              : widget.themeColor.withAlpha(30),
          valueColor: AlwaysStoppedAnimation<Color>(widget.themeColor),
          minHeight: 4,
        ),

        // AI adaptive info banner
        if (_adaptiveInfo.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: widget.themeColor.withAlpha(isDark ? 30 : 15),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, size: 16, color: widget.themeColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _adaptiveInfo,
                    style: TextStyle(
                      fontSize: 11,
                      color: widget.themeColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Question counter & meta
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: widget.themeColor.withAlpha(isDark ? 50 : 25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_currentQuestion + 1} / ${_questions.length}',
                        style: TextStyle(
                          color: widget.themeColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildPhaseChip(phase, isDark),
                    const SizedBox(width: 6),
                    _buildDifficultyChip(diff, isDark),
                  ],
                ),
                const SizedBox(height: 18),

                // Question text
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    q['text'] as String,
                    style: TextStyle(
                      color: titleColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Options
                ...options.entries.map((e) {
                  final isSelected = _selectedAnswers[idx] == e.key;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selectedAnswers[idx] = e.key);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? widget.themeColor.withAlpha(isDark ? 50 : 25)
                              : cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? widget.themeColor
                                : (isDark
                                      ? const Color(0xFF334236)
                                      : const Color(0xFFE5E7EB)),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? widget.themeColor
                                    : (isDark
                                          ? const Color(0xFF263226)
                                          : const Color(0xFFF1F5F1)),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  e.key,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : bodyColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                e.value,
                                style: TextStyle(
                                  color: titleColor,
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),

        // Navigation buttons
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          color: cardBg,
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                if (_currentQuestion > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _currentQuestion--),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: widget.themeColor,
                        side: BorderSide(color: widget.themeColor),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _tr(en: 'Previous', ms: 'Sebelum', zh: '上一题'),
                      ),
                    ),
                  ),
                if (_currentQuestion > 0) const SizedBox(width: 12),
                Expanded(
                  child: _currentQuestion < _questions.length - 1
                      ? ElevatedButton(
                          onPressed: _selectedAnswers.containsKey(idx)
                              ? () => setState(() => _currentQuestion++)
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.themeColor,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: widget.themeColor
                                .withAlpha(80),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _tr(en: 'Next', ms: 'Seterusnya', zh: '下一题'),
                          ),
                        )
                      : ElevatedButton(
                          onPressed: allAnswered && !_submitting
                              ? _submitQuiz
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.themeColor,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: widget.themeColor
                                .withAlpha(80),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _submitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  _tr(
                                    en: 'Submit Quiz',
                                    ms: 'Hantar Kuiz',
                                    zh: '提交测验',
                                  ),
                                ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhaseChip(String phase, bool isDark) {
    final label =
        {
          'before': _tr(en: 'Before', ms: 'Sebelum', zh: '之前'),
          'during': _tr(en: 'During', ms: 'Semasa', zh: '期间'),
          'after': _tr(en: 'After', ms: 'Selepas', zh: '之后'),
        }[phase] ??
        phase;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF2D5927).withAlpha(40)
            : const Color(0xFF2D5927).withAlpha(20),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFF86C77C) : const Color(0xFF2D5927),
        ),
      ),
    );
  }

  Widget _buildDifficultyChip(int diff, bool isDark) {
    final label = diff == 1
        ? _tr(en: 'Easy', ms: 'Mudah', zh: '简单')
        : diff == 2
        ? _tr(en: 'Medium', ms: 'Sederhana', zh: '中等')
        : _tr(en: 'Hard', ms: 'Sukar', zh: '困难');
    final color = diff == 1
        ? Colors.green
        : diff == 2
        ? Colors.orange
        : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(isDark ? 40 : 20),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  // ── Results View ──────────────────────────────────────────────────────

  Widget _buildResultsView(bool isDark) {
    final cardBg = isDark ? const Color(0xFF1B251B) : Colors.white;
    final titleColor = isDark
        ? const Color(0xFFE5E7EB)
        : const Color(0xFF1E293B);
    final bodyColor = isDark
        ? const Color(0xFFCCD3CD)
        : const Color(0xFF374151);
    final subtitleColor = isDark
        ? const Color(0xFF9AA79B)
        : const Color(0xFF64748B);

    final score = _results!['score'] as int;
    final total = _results!['total'] as int;
    final pct = (_results!['percentage'] as num).toDouble();
    final mastery = (_results!['mastery_level'] as num?)?.toDouble() ?? 0;
    final weakAreas =
        (_results!['weak_areas'] as List?)?.map((e) => e.toString()).toList() ??
        [];
    final recommendations =
        (_results!['recommendations'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final results =
        (_results!['results'] as List?)
            ?.map((e) => e as Map<String, dynamic>)
            .toList() ??
        [];

    final scoreColor = pct >= 80
        ? Colors.green
        : pct >= 60
        ? Colors.orange
        : Colors.red;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Score card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scoreColor.withAlpha(80)),
          ),
          child: Column(
            children: [
              Icon(
                pct >= 80
                    ? Icons.emoji_events_rounded
                    : pct >= 60
                    ? Icons.thumb_up_rounded
                    : Icons.school_rounded,
                color: scoreColor,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                '$score / $total',
                style: TextStyle(
                  color: titleColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 32,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${pct.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: scoreColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 12),
              // Mastery bar
              Row(
                children: [
                  Text(
                    _tr(
                      en: 'Overall Mastery',
                      ms: 'Penguasaan Keseluruhan',
                      zh: '总体掌握度',
                    ),
                    style: TextStyle(color: subtitleColor, fontSize: 12),
                  ),
                  const Spacer(),
                  Text(
                    '${(mastery * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: titleColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: mastery,
                  backgroundColor: isDark
                      ? const Color(0xFF263226)
                      : const Color(0xFFE5E7EB),
                  valueColor: AlwaysStoppedAnimation<Color>(widget.themeColor),
                  minHeight: 8,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Weak areas
        if (weakAreas.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.orange.withAlpha(isDark ? 25 : 15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.orange.withAlpha(60)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${_tr(en: 'Weak areas', ms: 'Bidang lemah', zh: '薄弱环节')}: ${weakAreas.map((w) => w[0].toUpperCase() + w.substring(1)).join(', ')}',
                    style: TextStyle(
                      color: Colors.orange[800],
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // AI Recommendations
        if (recommendations.isNotEmpty) ...[
          _buildSectionTitle(
            _tr(en: 'AI Recommendations', ms: 'Cadangan AI', zh: 'AI推荐'),
            Icons.auto_awesome,
            titleColor,
          ),
          const SizedBox(height: 10),
          ...recommendations.map(
            (rec) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: widget.themeColor.withAlpha(isDark ? 25 : 12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: widget.themeColor,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      rec,
                      style: TextStyle(
                        color: bodyColor,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Detailed results
        _buildSectionTitle(
          _tr(en: 'Answer Review', ms: 'Semakan Jawapan', zh: '答案回顾'),
          Icons.fact_check_outlined,
          titleColor,
        ),
        const SizedBox(height: 10),
        ...results.asMap().entries.map((entry) {
          final i = entry.key;
          final r = entry.value;
          final isCorrect = r['is_correct'] as bool;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isCorrect
                    ? Colors.green.withAlpha(100)
                    : Colors.red.withAlpha(100),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isCorrect ? Icons.check_circle : Icons.cancel,
                      color: isCorrect ? Colors.green : Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Q${i + 1}',
                        style: TextStyle(
                          color: isCorrect ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    _buildPhaseChip(r['phase'] as String, isDark),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  r['question'] as String,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                if (!isCorrect) ...[
                  RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: 12, color: bodyColor),
                      children: [
                        TextSpan(
                          text: _tr(
                            en: 'Your answer: ',
                            ms: 'Jawapan anda: ',
                            zh: '你的答案：',
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(
                          text: r['selected'] as String,
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const TextSpan(text: '  '),
                        TextSpan(
                          text: _tr(
                            en: 'Correct: ',
                            ms: 'Betul: ',
                            zh: '正确答案：',
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(
                          text: r['correct'] as String,
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF263226)
                        : const Color(0xFFF1F5F1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 14, color: subtitleColor),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          r['explanation'] as String,
                          style: TextStyle(
                            color: bodyColor,
                            fontSize: 12,
                            height: 1.4,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),

        const SizedBox(height: 20),

        // Action buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _generateQuiz,
                icon: Icon(Icons.refresh, color: widget.themeColor),
                label: Text(
                  _tr(en: 'Retake Quiz', ms: 'Ambil Semula', zh: '重新测验'),
                  style: TextStyle(color: widget.themeColor),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: widget.themeColor),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                label: Text(
                  _tr(en: 'Back to Module', ms: 'Kembali ke Modul', zh: '返回模块'),
                  style: const TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.themeColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSectionTitle(String text, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: widget.themeColor),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
