import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:okuma_pusulasi_3/screens/word_test_screen.dart';
import 'test_results_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class TeacherTestScreen extends StatefulWidget {
  final String classId;
  final String studentId;
  final String testId;

  const TeacherTestScreen({
    Key? key,
    required this.classId,
    required this.studentId,
    required this.testId,
  }) : super(key: key);

  @override
  _TeacherTestScreenState createState() => _TeacherTestScreenState();
}

class _TeacherTestScreenState extends State<TeacherTestScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isSubmitting = false;
  bool _loading = true;
  String _studentName = '';

  @override
  void initState() {
    super.initState();
    _loadStudentName();
    _listenToTestStatus();
  }

  Future<void> _loadStudentName() async {
    try {
      final studentDoc = await _firestore
          .collection('classes')
          .doc(widget.classId)
          .collection('students')
          .doc(widget.studentId)
          .get();

      if (mounted && studentDoc.exists) {
        setState(() {
          _studentName = studentDoc.data()?['name'] ?? '';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _listenToTestStatus() {
    _firestore
        .collection('classes')
        .doc(widget.classId)
        .collection('students')
        .doc(widget.studentId)
        .collection('tests')
        .doc(widget.testId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists || !mounted) return;

      final testData = snapshot.data()!;
      if (testData['completed'] == true && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => TestResultsScreen(
              classId: widget.classId,
              studentId: widget.studentId,
              testId: widget.testId,
            ),
          ),
        );
      }
    });
  }

  Future<void> _updateLetterStatus(int index, bool isCorrect) async {
    try {
      final docRef = _firestore
          .collection('classes')
          .doc(widget.classId)
          .collection('students')
          .doc(widget.studentId)
          .collection('tests')
          .doc(widget.testId);

      final doc = await docRef.get();
      if (!doc.exists) {
        throw Exception('Test bulunamadı');
      }

      final data = doc.data()!;
      final List<dynamic> status = List<dynamic>.from(data['status'] ?? []);

      // Durumu güncelle
      status[index] = isCorrect;

      // Firestore güncelle
      await docRef.update({
        'status': status,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Bildirim göster
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${index + 1}. harf değerlendirildi: ${isCorrect ? "Doğru" : "Yanlış"}'),
            backgroundColor: isCorrect ? Colors.green : Colors.red,
            duration: const Duration(seconds: 1),
          ),
        );
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

  Future<void> _finishTest() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final testDoc = await _firestore
          .collection('classes')
          .doc(widget.classId)
          .collection('students')
          .doc(widget.studentId)
          .collection('tests')
          .doc(widget.testId)
          .get();

      if (!testDoc.exists) {
        throw Exception('Test bulunamadı');
      }

      final testData = testDoc.data()!;
      final List<dynamic> status = List<dynamic>.from(testData['status'] ?? []);

      // Boş yanıt kontrolü
      if (status.any((s) => s == null)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lütfen tüm harfleri değerlendirin'),
              backgroundColor: Colors.orange,
            ),
          );
          setState(() {
            _isSubmitting = false;
          });
          return;
        }
      }

      // Skorları hesapla
      final correctCount = status.where((s) => s == true).length;
      final totalQuestions = status.length;
      final score = (correctCount / totalQuestions) * 100;

      // Test verilerini güncelle
      await _firestore
          .collection('classes')
          .doc(widget.classId)
          .collection('students')
          .doc(widget.studentId)
          .collection('tests')
          .doc(widget.testId)
          .update({
        'completed': true,
        'completedAt': FieldValue.serverTimestamp(),
        'score': score,
        'correctCount': correctCount,
        'totalQuestions': totalQuestions,
      });

      // Başarı durumuna göre yönlendir
      if (mounted) {
        if (correctCount >= 8) {
          // WordTestScreen'e yönlendir
          await Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => WordTestScreen(
                classId: widget.classId,
                studentId: widget.studentId,
                previousTestId: widget.testId,
                testId: '',
              ),
            ),
          );
        } else {
          // Başarısız durumda bilgilendir ve testi sıfırla
          await _resetTest();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Başarısız. Testi tekrar etmeniz gerekiyor.'),
              backgroundColor: Colors.red,
            ),
          );
        }
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
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _resetTest() async {
    try {
      final testDoc = _firestore
          .collection('classes')
          .doc(widget.classId)
          .collection('students')
          .doc(widget.studentId)
          .collection('tests')
          .doc(widget.testId);

      final snapshot = await testDoc.get();
      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      final String letters = data['letters'] ?? 'ABCÇDEFGĞHIİJKLMNOÖPRSŞTUÜVYZ';

      await testDoc.update({
        'status': List.filled(letters.length, null),
        'completed': false,
        'score': 0,
        'correctCount': 0,
        'resetAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test sıfırlama hatası: ${e.toString()}'),
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
        if (_isSubmitting) return false;
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_loading
              ? 'Test Değerlendirme'
              : '$_studentName - Test Değerlendirme'),
          actions: [
            TextButton.icon(
              onPressed: _isSubmitting ? null : _finishTest,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : const Icon(Icons.check_circle, color: Colors.white),
              label: Text(
                _isSubmitting ? 'İşleniyor...' : 'Testi Bitir',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: _firestore
              .collection('classes')
              .doc(widget.classId)
              .collection('students')
              .doc(widget.studentId)
              .collection('tests')
              .doc(widget.testId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Hata: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: Text('Test bulunamadı'));
            }

            final testData = snapshot.data!.data() as Map<String, dynamic>;
            final String letters =
                testData['letters'] ?? 'ABCÇDEFGĞHIİJKLMNOÖPRSŞTUÜVYZ';
            final List<dynamic> status =
                List<dynamic>.from(testData['status'] ?? []);
            final bool completed = testData['completed'] ?? false;

            if (completed) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.assignment_turned_in,
                        size: 64,
                        color: Colors.green,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Test tamamlandı',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TestResultsScreen(
                                classId: widget.classId,
                                studentId: widget.studentId,
                                testId: widget.testId,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.bar_chart),
                        label: const Text('Sonuçları Görüntüle'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(16),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Test Harfleri:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        letters,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: status.where((s) => s != null).length /
                            letters.length,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.blue.shade300,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${status.where((s) => s != null).length}/${letters.length} harf değerlendirildi',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: letters.length,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemBuilder: (context, index) {
                      final letter = letters[index];
                      final currentStatus = status[index];

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        elevation: 2,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: currentStatus == null
                                ? Colors.grey.shade200
                                : currentStatus
                                    ? Colors.green.shade100
                                    : Colors.red.shade100,
                            child: Text(
                              letter,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: currentStatus == null
                                    ? Colors.grey.shade700
                                    : currentStatus
                                        ? Colors.green.shade700
                                        : Colors.red.shade700,
                              ),
                            ),
                          ),
                          title: Text(
                            'Harf ${index + 1}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: currentStatus == null
                              ? const Text('Değerlendirilmedi')
                              : Text(
                                  currentStatus ? 'Doğru' : 'Yanlış',
                                  style: TextStyle(
                                    color: currentStatus
                                        ? Colors.green
                                        : Colors.red,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.check_circle,
                                  color: currentStatus == true
                                      ? Colors.green
                                      : Colors.grey.shade300,
                                  size: 32,
                                ),
                                onPressed: () =>
                                    _updateLetterStatus(index, true),
                                tooltip: 'Doğru',
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: Icon(
                                  Icons.cancel,
                                  color: currentStatus == false
                                      ? Colors.red
                                      : Colors.grey.shade300,
                                  size: 32,
                                ),
                                onPressed: () =>
                                    _updateLetterStatus(index, false),
                                tooltip: 'Yanlış',
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _resetTest,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.refresh),
                              SizedBox(width: 8),
                              Text('Testi Sıfırla'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _finishTest,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _isSubmitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.check_circle),
                              const SizedBox(width: 8),
                              Text(_isSubmitting
                                  ? 'İşleniyor...'
                                  : 'Testi Bitir'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Temizlik işlemleri burada yapılabilir
    super.dispose();
  }
}
