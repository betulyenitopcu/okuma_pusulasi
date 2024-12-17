import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:random_string/random_string.dart';
import 'teacher_test_screen.dart';

class ClassScreen extends StatelessWidget {
  final String classId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  ClassScreen({Key? key, required this.classId}) : super(key: key);

  // Türkçe harfleri içeren bir liste oluşturuyoruz.
  final List<String> turkishLetters = [
    'A',
    'B',
    'C',
    'Ç',
    'D',
    'E',
    'F',
    'G',
    'Ğ',
    'H',
    'I',
    'İ',
    'J',
    'K',
    'L',
    'M',
    'N',
    'O',
    'Ö',
    'P',
    'R',
    'S',
    'Ş',
    'T',
    'U',
    'Ü',
    'V',
    'Y',
    'Z'
  ];

  // Türkçe harflerle 29 karakterlik random bir string oluşturuyoruz.
  String _generateRandomLetters() {
    return List.generate(29, (_) {
      final randomLetter =
          turkishLetters[Random().nextInt(turkishLetters.length)];
      return randomLetter; // burada harfi küçük veya büyük yapmak yerine direkt harfi alıyoruz
    }).join();
  }

  Future<void> _addStudent(BuildContext context) async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController infoController = TextEditingController();

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Öğrenci Ekle"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Öğrenci Adı',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: infoController,
              decoration: const InputDecoration(
                labelText: 'Ek Bilgi (Opsiyonel)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                try {
                  await _firestore
                      .collection('classes')
                      .doc(classId)
                      .collection('students')
                      .add({
                    'name': nameController.text,
                    'info': infoController.text,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  if (context.mounted) Navigator.pop(context);
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
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Öğrenci adı boş bırakılamaz'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  // Sınav başlatma fonksiyonu
  Future<void> _startExam(
      BuildContext context, String studentId, String studentName) async {
    try {
      final testId = _firestore.collection('tests').doc().id;
      final letters =
          _generateRandomLetters(); // Türkçe harflerle rastgele 29 harf oluşturuluyor

      await _firestore
          .collection('classes')
          .doc(classId)
          .collection('students')
          .doc(studentId)
          .collection('tests')
          .doc(testId)
          .set({
        'letters': letters,
        'status': List.generate(29, (_) => null),
        'timestamp': FieldValue.serverTimestamp(),
        'completed': false,
      });

      if (!context.mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Dialog(
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$studentName için Sınav QR Kodu',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  QrImageView(
                    data: '$classId:$studentId:$testId',
                    version: QrVersions.auto,
                    size: 200.0,
                    backgroundColor: Colors.white,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Öğrencinin QR kodu taramasını bekleyin',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          // Öğretmeni direkt olarak test ekranına yönlendir
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TeacherTestScreen(
                                classId: classId,
                                studentId: studentId,
                                testId: testId,
                              ),
                            ),
                          );
                        },
                        child: const Text('Değerlendirme Ekranına Git'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('İptal'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata oluştu: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<DocumentSnapshot>(
          stream: _firestore.collection('classes').doc(classId).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data!.exists) {
              return Text(snapshot.data!.get('name'));
            }
            return const Text("Sınıf Detayları");
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addStudent(context),
        child: const Icon(Icons.add),
        tooltip: 'Öğrenci Ekle',
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('classes')
            .doc(classId)
            .collection('students')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Hata: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final students = snapshot.data!.docs;

          if (students.isEmpty) {
            return const Center(
              child: Text(
                'Henüz öğrenci bulunmuyor\nSağ alt köşedeki + butonuna tıklayarak öğrenci ekleyebilirsiniz',
                textAlign: TextAlign.center,
              ),
            );
          }

          return ListView.builder(
            itemCount: students.length,
            padding: const EdgeInsets.all(8),
            itemBuilder: (context, index) {
              final studentData =
                  students[index].data() as Map<String, dynamic>;
              final studentId = students[index].id;
              final studentName =
                  studentData['name'] as String? ?? 'İsimsiz Öğrenci';

              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.person),
                  ),
                  title: Text(studentName),
                  subtitle: Text(studentData['info']?.toString() ?? ''),
                  trailing: IconButton(
                    icon: const Icon(Icons.qr_code),
                    onPressed: () =>
                        _startExam(context, studentId, studentName),
                    tooltip: 'Sınav QR Kodu Oluştur',
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
