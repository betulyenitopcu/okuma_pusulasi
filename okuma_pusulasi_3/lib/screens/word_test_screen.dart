import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'package:google_fonts/google_fonts.dart';

class WordTestScreen extends StatefulWidget {
  final String classId;
  final String studentId;
  final String? previousTestId;

  const WordTestScreen({
    Key? key,
    required this.classId,
    required this.studentId,
    this.previousTestId,
    required String testId,
  }) : super(key: key);

  @override
  _WordTestScreenState createState() => _WordTestScreenState();
}

class _WordTestScreenState extends State<WordTestScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<String> words = [];
  List<String> selectedWords = [];
  Map<String, bool?> results = {};
  bool isLoading = true;
  String? currentTestId;

  Future<void> loadWords() async {
    try {
      final String wordData = await rootBundle.loadString('assets/word.txt');
      final List<String> wordsList = wordData
          .split('\n')
          .where((word) => word.trim().isNotEmpty)
          .map((word) => word.trim())
          .toList();

      final newTestRef = await _firestore
          .collection('classes')
          .doc(widget.classId)
          .collection('students')
          .doc(widget.studentId)
          .collection('word_tests')
          .add({
        'createdAt': FieldValue.serverTimestamp(),
        'completed': false,
        'previousTestId': widget.previousTestId,
        'type': 'word_test',
      });

      final selectedWordsList = _getRandomWords(wordsList, 10);

      setState(() {
        words = wordsList;
        currentTestId = newTestRef.id;
        selectedWords = selectedWordsList;
        results = {for (var word in selectedWordsList) word: null};
        isLoading = false;
      });

      await newTestRef.update({
        'words': selectedWords,
        'totalWords': selectedWords.length,
        'correctWords': 0,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata oluştu: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() {
        isLoading = false;
      });
    }
  }

  List<String> _getRandomWords(List<String> allWords, int count) {
    final random = Random();
    final List<String> randomWords = [];
    final List<String> availableWords = List.from(allWords);

    while (randomWords.length < count && availableWords.isNotEmpty) {
      final int randomIndex = random.nextInt(availableWords.length);
      final String selectedWord = availableWords[randomIndex];
      randomWords.add(selectedWord);
      availableWords.removeAt(randomIndex);
    }

    return randomWords;
  }

  Future<void> _finishTest() async {
    if (currentTestId == null) return;

    try {
      final correctWords =
          results.values.where((result) => result == true).length;

      await _firestore
          .collection('classes')
          .doc(widget.classId)
          .collection('students')
          .doc(widget.studentId)
          .collection('word_tests')
          .doc(currentTestId)
          .update({
        'completed': true,
        'completedAt': FieldValue.serverTimestamp(),
        'correctWords': correctWords,
        'results': results,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test başarıyla tamamlandı'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata oluştu: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    loadWords();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelime Testi'),
        actions: [
          if (!isLoading && selectedWords.isNotEmpty)
            TextButton.icon(
              onPressed: _finishTest,
              icon: const Icon(Icons.check_circle, color: Colors.white),
              label: const Text(
                'Testi Bitir',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kelime Testi Sonuçları:',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      fontFamily: GoogleFonts.getFont('Kalam').fontFamily,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: selectedWords.length,
                      itemBuilder: (context, index) {
                        final word = selectedWords[index];
                        final result = results[word];

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          elevation: 2,
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text((index + 1).toString()),
                            ),
                            title: Text(
                              word,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                fontFamily:
                                    GoogleFonts.getFont('Kalam').fontFamily,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    Icons.check_circle,
                                    color: result == true
                                        ? Colors.green
                                        : Colors.grey,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      results[word] = true;
                                    });
                                  },
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.cancel,
                                    color: result == false
                                        ? Colors.red
                                        : Colors.grey,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      results[word] = false;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _finishTest,
                      icon: const Icon(Icons.check_circle),
                      label: const Text(
                        'Testi Tamamla',
                        style: TextStyle(fontSize: 18),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
