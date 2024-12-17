import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:just_audio/just_audio.dart';
import 'package:google_fonts/google_fonts.dart';

class StudentTestScreen extends StatefulWidget {
  final String classId;
  final String studentId;
  final String testId;

  const StudentTestScreen({
    Key? key,
    required this.classId,
    required this.studentId,
    required this.testId,
  }) : super(key: key);

  @override
  _StudentTestScreenState createState() => _StudentTestScreenState();
}

class _StudentTestScreenState extends State<StudentTestScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _playLocalAudio();
    _checkAndGetWordTest();
  }

  Future<void> _playLocalAudio() async {
    try {
      await _audioPlayer.setAsset('assets/dene.mp3');
      await _audioPlayer.play();
    } catch (e) {
      print("Ses çalma hatası: $e");
    }
  }

  Future<void> _checkAndGetWordTest() async {
    try {
      final letterTestDoc = await _firestore
          .collection('classes')
          .doc(widget.classId)
          .collection('students')
          .doc(widget.studentId)
          .collection('tests')
          .doc(widget.testId)
          .get();

      if (letterTestDoc.exists && letterTestDoc.data()?['completed'] == true) {
        final wordTestsQuery = await _firestore
            .collection('classes')
            .doc(widget.classId)
            .collection('students')
            .doc(widget.studentId)
            .collection('word_tests')
            .where('previousTestId', isEqualTo: widget.testId)
            .limit(1)
            .get();

        if (wordTestsQuery.docs.isNotEmpty) {
          if (mounted) {
            setState(() {});
          }
        }
      }
    } catch (e) {
      print("Kelime testi kontrolü hatası: $e");
    }
  }

  Widget _buildWordTestView(Map<String, dynamic> testData) {
    final List<dynamic> words = testData['words'] ?? [];

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16.0),
          color: Colors.blue.shade50,
          child: Text(
            'Kelime Testi',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: GoogleFonts.getFont('Kalam').fontFamily,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: words.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final word = words[index];
              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text('${index + 1}'),
                  ),
                  title: Text(
                    word,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      fontFamily: GoogleFonts.getFont('Kalam').fontFamily,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore
            .collection('classes')
            .doc(widget.classId)
            .collection('students')
            .doc(widget.studentId)
            .collection('tests')
            .doc(widget.testId)
            .snapshots(),
        builder: (context, letterTestSnapshot) {
          if (letterTestSnapshot.hasError) {
            return Center(child: Text('Hata: ${letterTestSnapshot.error}'));
          }

          if (letterTestSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!letterTestSnapshot.hasData || !letterTestSnapshot.data!.exists) {
            return const Center(child: Text('Test bulunamadı'));
          }

          final letterTestData =
              letterTestSnapshot.data!.data() as Map<String, dynamic>;
          final bool letterTestCompleted = letterTestData['completed'] ?? false;

          if (letterTestCompleted) {
            return StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('classes')
                  .doc(widget.classId)
                  .collection('students')
                  .doc(widget.studentId)
                  .collection('word_tests')
                  .where('previousTestId', isEqualTo: widget.testId)
                  .limit(1)
                  .snapshots(),
              builder: (context, wordTestSnapshot) {
                if (wordTestSnapshot.hasError) {
                  return Center(child: Text('Hata: ${wordTestSnapshot.error}'));
                }

                if (wordTestSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!wordTestSnapshot.hasData ||
                    wordTestSnapshot.data!.docs.isEmpty) {
                  return const Center(
                      child: Text('Kelime testi henüz başlamadı'));
                }

                final wordTestData = wordTestSnapshot.data!.docs.first.data()
                    as Map<String, dynamic>;
                return _buildWordTestView(wordTestData);
              },
            );
          }

          final String letters =
              letterTestData['letters'] ?? 'ABCÇDEFGĞHIİJKLMNOÖPRSŞTUÜVYZ';

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (int i = 0; i < letters.length; i += 3)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              for (int j = i;
                                  j < i + 3 && j < letters.length;
                                  j++)
                                Expanded(
                                  child: Card(
                                    elevation: 3,
                                    child: Center(
                                      child: Text(
                                        letters[j],
                                        style: TextStyle(
                                          fontSize: 48,
                                          fontWeight: FontWeight.normal,
                                          fontFamily:
                                              GoogleFonts.getFont('Kalam')
                                                  .fontFamily,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
