import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:okuma_pusulasi_3/screens/word_test_screen.dart';

class TestResultsScreen extends StatelessWidget {
  final String classId;
  final String studentId;
  final String testId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  TestResultsScreen({
    Key? key,
    required this.classId,
    required this.studentId,
    required this.testId,
  }) : super(key: key);

  void _navigateToWordTest(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => WordTestScreen(
          classId: classId,
          studentId: studentId,
          previousTestId: testId,
          testId: '',
        ),
      ),
    );
  }

  Future<void> _restartTest(BuildContext context) async {
    try {
      await _firestore
          .collection('classes')
          .doc(classId)
          .collection('students')
          .doc(studentId)
          .collection('tests')
          .doc(testId)
          .update({
        'completed': false,
        'status': List.filled(29, null), // 29 harf için null statüsü
        'score': 0,
        'correctCount': 0,
        'resetAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
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
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Geri tuşuna basıldığında ana sayfaya dön
        Navigator.of(context).popUntil((route) => route.isFirst);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Test Sonuçları'),
          automaticallyImplyLeading: false, // Otomatik geri butonunu kaldır
          leading: IconButton(
            icon: const Icon(Icons.home),
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: _firestore
              .collection('classes')
              .doc(classId)
              .collection('students')
              .doc(studentId)
              .collection('tests')
              .doc(testId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Hata: ${snapshot.error}'));
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final testData = snapshot.data!.data() as Map<String, dynamic>;
            final score = testData['score'] ?? 0.0;
            final correctCount = testData['correctCount'] ?? 0;
            final totalQuestions = testData['totalQuestions'] ?? 0;
            final letters = testData['letters'] as String? ?? '';
            final List<dynamic> status =
                List<dynamic>.from(testData['status'] ?? []);
            final bool completed = testData['completed'] ?? false;

            if (!completed) {
              return const Center(
                child: Text('Test henüz tamamlanmadı'),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Toplam Puan:',
                                style: TextStyle(fontSize: 18),
                              ),
                              Text(
                                '${score.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: score >= 80
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: score / 100,
                            minHeight: 10,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              score >= 80 ? Colors.green : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          _buildStatRow(
                              'Toplam Soru', totalQuestions.toString()),
                          _buildStatRow('Doğru Cevap', correctCount.toString()),
                          _buildStatRow(
                            'Yanlış Cevap',
                            (totalQuestions - correctCount).toString(),
                          ),
                          _buildStatRow(
                            'Başarı Durumu',
                            correctCount >= 8 ? 'Başarılı' : 'Başarısız',
                            textColor:
                                correctCount >= 8 ? Colors.green : Colors.red,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Detaylı Sonuçlar',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: letters.length,
                    itemBuilder: (context, index) {
                      final isCorrect = status[index] == true;
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                isCorrect ? Colors.green : Colors.red,
                            child: Icon(
                              isCorrect ? Icons.check : Icons.close,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(
                            'Harf ${index + 1}: ${letters[index]}',
                            style: const TextStyle(fontSize: 18),
                          ),
                          trailing: Text(
                            isCorrect ? 'Doğru' : 'Yanlış',
                            style: TextStyle(
                              color: isCorrect ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  // Sonuç butonları
                  if (correctCount >= 8)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _navigateToWordTest(context),
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text(
                          'Kelime Testine Geç',
                          style: TextStyle(fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _restartTest(context),
                        icon: const Icon(Icons.refresh),
                        label: const Text(
                          'Testi Tekrarla',
                          style: TextStyle(fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, {Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
