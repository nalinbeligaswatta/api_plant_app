import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const PlantDoctorApp());
}

const String apiUrl = 'https://plantapi-octp.onrender.com/predict';

class PlantDoctorApp extends StatefulWidget {
  const PlantDoctorApp({super.key});

  @override
  State<PlantDoctorApp> createState() => _PlantDoctorAppState();
}

class _PlantDoctorAppState extends State<PlantDoctorApp> {
  String _language = 'en';
  int _selectedIndex = 0;

  void _toggleLanguage() {
    setState(() {
      _language = _language == 'en' ? 'si' : 'en';
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DiagnosePage(
        language: _language,
        onLanguageChanged: _toggleLanguage,
      ),
      HistoryPage(language: _language),
      LibraryPage(language: _language),
    ];

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Crop Guard',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: IndexedStack(index: _selectedIndex, children: pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) => setState(() => _selectedIndex = index),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.eco_outlined),
              selectedIcon: const Icon(Icons.eco),
              label: _language == 'en' ? 'Diagnose' : 'රෝග නිරීක්ෂණය',
            ),
            NavigationDestination(
              icon: const Icon(Icons.history_outlined),
              selectedIcon: const Icon(Icons.history),
              label: _language == 'en' ? 'History' : 'ඉතිහාසය',
            ),
            NavigationDestination(
              icon: const Icon(Icons.menu_book_outlined),
              selectedIcon: const Icon(Icons.menu_book),
              label: _language == 'en' ? 'Library' : 'පුස්තකාලය',
            ),
          ],
        ),
      ),
    );
  }
}

class DiagnosePage extends StatefulWidget {
  const DiagnosePage({required this.language, required this.onLanguageChanged, super.key});

  final String language;
  final VoidCallback onLanguageChanged;

  @override
  State<DiagnosePage> createState() => _DiagnosePageState();
}

class _DiagnosePageState extends State<DiagnosePage> {
  File? imageFile;
  Uint8List? imageBytes;
  String selectedCrop = 'tomato';
  String? disease;
  double confidence = 0;
  bool loading = false;
  String error = '';
  List<String> treatment = [];

  final List<String> crops = ['corn', 'tomato', 'rice', 'coconut'];

  final Map<String, Map<String, List<String>>> treatments = {
    'corn_blight': {
      'en': ['Remove infected leaves', 'Use resistant corn varieties', 'Apply recommended fungicide', 'Maintain proper plant spacing'],
      'si': ['ලෙඩී වූ පත්‍ර ඉවත් කරන්න', 'ප්‍රතිරෝධී මඛුල වර්ග භාවිතා කරන්න', 'නිර්දේශිත කෘමිනෝධකයක් යොදන්න', 'සහනවත් පැල පරතරයක් පවත්වා ගන්න'],
    },
    'corn_common_rust': {
      'en': ['Use rust resistant varieties', 'Apply fungicide when needed', 'Remove infected plant debris'],
      'si': ['කළු කුරුලු ප්‍රතිරෝධී වර්ග භාවිතා කරන්න', 'අවශ්‍ය විට කෘමිනෝධකයක් යොදන්න', 'ලෙඩී පැල නරක් කිරීම ඉවත් කරන්න'],
    },
    'corn_gray_leaf_spot': {
      'en': ['Practice crop rotation', 'Improve field ventilation', 'Apply suitable fungicide'],
      'si': ['වගාව භ්‍රමණය කරන්න', 'ක්ෂේත්‍රයේ වායු සම්ප්‍රේෂණය වැඩි කරන්න', 'ගැලපෙන කෘමිනෝධකයක් යොදන්න'],
    },
    'corn_healthy': {
      'en': ['Plant is healthy', 'Continue normal farming practices'],
      'si': ['පැල සෞඛ්යවත්', 'සාමාන්‍ය ගොවිතැන ඉදිරියටම කරගෙන යන්න'],
    },
    'tomato_bacterial_spot': {
      'en': ['Remove infected leaves', 'Disinfect farming tools', 'Avoid overhead irrigation', 'Apply copper based bactericide'],
      'si': ['ලෙඩී වූ පත්‍ර ඉවත් කරන්න', 'ගොවිතැනේ මෙවලම් ශුද්ධ කරන්න', 'ඉහළින් පිරිනැමෙන ජල සපයුමෙන් වළක්වන්න', 'තඹ මත පදනම් වූ බැක්ටීරියාහරණයක් යොදන්න'],
    },
    'tomato_early_blight': {
      'en': ['Remove infected leaves', 'Apply fungicide', 'Use crop rotation', 'Avoid leaf wetness'],
      'si': ['ලෙඩී වූ පත්‍ර ඉවත් කරන්න', 'කෘමිනෝධකයක් යොදන්න', 'වගාව භ්‍රමණය කරන්න', 'පත්‍ර ගිල්වීම වළක්වන්න'],
    },
    'tomato_late_blight': {
      'en': ['Remove infected plants', 'Apply copper fungicide', 'Reduce humidity', 'Improve air circulation'],
      'si': ['ලෙඩී වූ පැළ ඉවත් කරන්න', 'තඹ කෘමිනෝධකයක් යොදන්න', 'උෂ්ණත්වය අඩු කරන්න', 'වායු ප්‍රවාහය වැඩි කරන්න'],
    },
    'tomato_leaf_mold': {
      'en': ['Reduce humidity', 'Improve ventilation', 'Remove infected leaves', 'Apply fungicide'],
      'si': ['උෂ්ණත්වය අඩු කරන්න', 'වායු සංසරණය වැඩි කරන්න', 'ලෙඩී වූ පත්‍ර ඉවත් කරන්න', 'කෘමිනෝධකයක් යොදන්න'],
    },
    'tomato_septoria_leaf_spot': {
      'en': ['Remove infected leaves', 'Use crop rotation', 'Apply suitable fungicide'],
      'si': ['ලෙඩී වූ පත්‍ර ඉවත් කරන්න', 'වගාව භ්‍රමණය කරන්න', 'ගැලපෙන කෘමිනෝධකයක් යොදන්න'],
    },
    'tomato_spider_mites': {
      'en': ['Spray water to remove mites', 'Use insecticidal soap', 'Maintain plant health'],
      'si': ['මයිටා පරම්පරාව ඉවත් කිරීමට ජල ස්ප්‍රේ කරයි', 'කීටෝනಾಶක සබන් භාවිතා කරන්න', 'පැල සෞඛ්‍යය පවත්වා ගන්න'],
    },
    'tomato_target_spot': {
      'en': ['Remove infected leaves', 'Improve air circulation', 'Apply fungicide'],
      'si': ['ලෙඩී වූ පත්‍ර ඉවත් කරන්න', 'වායු ප්‍රවාහය වැඩි කරන්න', 'කෘමිනෝධකයක් යොදන්න'],
    },
    'tomato_yellow_leaf_curl_virus': {
      'en': ['Control whiteflies', 'Remove infected plants', 'Use resistant varieties'],
      'si': ['සුදු පියාපත් පාලනය කරන්න', 'ලෙඩී වූ පැළ ඉවත් කරන්න', 'ප්‍රතිරෝධී වර්ග භාවිතා කරන්න'],
    },
    'tomato_mosaic_virus': {
      'en': ['Remove infected plants', 'Disinfect tools', 'Control insect vectors'],
      'si': ['ලෙඩී වූ පැළ ඉවත් කරන්න', 'මෙවලම් ශුද්ධ කරන්න', 'කීටෝ පරම්පරා පාලනය කරන්න'],
    },
    'tomato_healthy': {
      'en': ['Plant is healthy', 'Continue normal farming'],
      'si': ['පැල සෞඛ්යවත්', 'සාමාන්‍ය ගොවිතැන දිගටම කරගෙන යන්න'],
    },
    'tomato_powdery_mildew': {
      'en': ['Improve air circulation', 'Remove infected leaves', 'Apply sulfur fungicide'],
      'si': ['වායු සංසරණය වැඩි කරන්න', 'ලෙඩී වූ පත්‍ර ඉවත් කරන්න', 'සල්ෆර් කෘමිනෝධකයක් යොදන්න'],
    },
    'rice_bacterial_leaf_blight': {
      'en': ['Use resistant rice varieties', 'Avoid excess nitrogen fertilizer', 'Maintain proper water management'],
      'si': ['ප්‍රතිරෝධී වියලි වර්ග භාවිතා කරන්න', 'අතිරේක නයිට්‍රජන් පොහොර වැළැක්වන්න', 'නිසි ජල කළමනාකරණය පවත්වා ගන්න'],
    },
    'rice_brown_spot': {
      'en': ['Use healthy seeds', 'Improve soil nutrition', 'Apply suitable fungicide'],
      'si': ['සෞඛ්‍යවත් බීජ භාවිතා කරන්න', 'පසෙහි පොෂණය වැඩි කරන්න', 'ගැලපෙන කෘමිනෝධකයක් යොදන්න'],
    },
    'rice_healthy': {
      'en': ['Rice plant is healthy', 'Continue normal cultivation'],
      'si': ['බත් පත සෞඛ්යවත්', 'සාමාන්‍ය වගා ක්‍රියාවලිය දිගටම කරගෙන යන්න'],
    },
    'rice_leaf_blast': {
      'en': ['Use resistant varieties', 'Avoid excess nitrogen', 'Apply recommended fungicide'],
      'si': ['ප්‍රතිරෝධී වර්ග භාවිතා කරන්න', 'අතිරේක නයිට්‍රජන් වළක්වන්න', 'නිර්දේශිත කෘමිනෝධකයක් යොදන්න'],
    },
    'rice_leaf_scald': {
      'en': ['Maintain proper field drainage', 'Remove infected residues', 'Use balanced fertilizer'],
      'si': ['නිසි කෙත ජල අපාදනය පවත්වා ගන්න', 'ලෙඩී වූ ඉතිරි ද්‍රව්‍ය ඉවත් කරන්න', 'සමාන්තර පොහොර භාවිතා කරන්න'],
    },
    'rice_sheath_blight': {
      'en': ['Reduce plant density', 'Control field humidity', 'Apply fungicide'],
      'si': ['පැල ඝනත්වය අඩු කරන්න', 'කෙතේ වෘද්ධිය පාලනය කරන්න', 'කෘමිනෝධකයක් යොදන්න'],
    },
    'coconut_healthy': {
      'en': ['Palm is healthy', 'Continue regular maintenance'],
      'si': ['තැඹිලි පඳුරු සෞඛ්‍යවත්', 'නිත්‍ය නඩත්තු දිගටම කරගෙන යන්න'],
    },
    'coconut_pest_damage': {
      'en': ['Remove damaged parts', 'Control pests', 'Apply recommended pesticides'],
      'si': ['හානි වූ කොටස් ඉවත් කරන්න', 'පළිබෝධ පාලනය කරන්න', 'නිර්දේශිත කෘමිනාශක යොදන්න'],
    },
    'coconut_yellowing': {
      'en': ['Check soil nutrients', 'Apply balanced fertilizer', 'Improve drainage'],
      'si': ['පසෙහි පෝෂක මට්ටම පරීක්ෂා කරන්න', 'සමාන්තර පොහොර යොදන්න', 'ජල පිසීම වැඩි කරන්න'],
    },
    'coconut_leaf_spot': {
      'en': ['Remove infected leaves', 'Apply fungicide', 'Maintain nutrients'],
      'si': ['ලෙඩී වූ පත්‍ර ඉවත් කරන්න', 'කෘමිනෝධකයක් යොදන්න', 'පෝෂක පවත්වා ගන්න'],
    },
  };

  final Map<String, Map<String, String>> diseaseNames = {
    'corn_blight': {'en': 'Corn Blight', 'si': 'මඛුල කුලීන් ඇනීම'},
    'corn_common_rust': {'en': 'Common Rust', 'si': 'සාමාන්‍ය කහ පැල්ලම්'},
    'corn_gray_leaf_spot': {'en': 'Gray Leaf Spot', 'si': 'අළු පත්‍ර කුණුවීම'},
    'corn_healthy': {'en': 'Healthy Corn', 'si': 'සෞඛ්‍යවත් මඛුල'},
    'tomato_bacterial_spot': {'en': 'Bacterial Spot', 'si': 'බැක්ටීරියා ව්‍යාධිය'},
    'tomato_early_blight': {'en': 'Early Blight', 'si': 'මුල් කුලීන් ඇනීම'},
    'tomato_late_blight': {'en': 'Late Blight', 'si': 'පසු කුලීන් ඇනීම'},
    'tomato_leaf_mold': {'en': 'Leaf Mold', 'si': 'පත්‍ර අඳුරු බිඳ'},
    'tomato_septoria_leaf_spot': {'en': 'Septoria Leaf Spot', 'si': 'සෙප්ටෝරියා පත්‍ර වරූකිරීම'},
    'tomato_spider_mites': {'en': 'Spider Mites', 'si': 'මදුරුවන් මයිටා'},
    'tomato_target_spot': {'en': 'Target Spot', 'si': 'ලක්ෂ්‍ය වරූකිරීම'},
    'tomato_yellow_leaf_curl_virus': {'en': 'Yellow Leaf Curl Virus', 'si': 'කහ පත්‍ර කුමන් ව්‍යාධිය'},
    'tomato_mosaic_virus': {'en': 'Mosaic Virus', 'si': 'මොසැයික් වෛරසය'},
    'tomato_healthy': {'en': 'Healthy Tomato', 'si': 'සෞඛ්‍යවත් තක්කාලි'},
    'tomato_powdery_mildew': {'en': 'Powdery Mildew', 'si': 'පවුඩර් මයිල්ඩුව'},
    'rice_bacterial_leaf_blight': {'en': 'Bacterial Leaf Blight', 'si': 'බැක්ටීරියා පත්‍ර කුලීන් ඇනීම'},
    'rice_brown_spot': {'en': 'Brown Spot', 'si': 'දුඹුරු වරූකිරීම'},
    'rice_healthy': {'en': 'Healthy Rice', 'si': 'සෞඛ්‍යවත් වියලි'},
    'rice_leaf_blast': {'en': 'Leaf Blast', 'si': 'පත්‍ර පැතීම'},
    'rice_leaf_scald': {'en': 'Leaf Scald', 'si': 'පත්‍ර රිදිම'},
    'rice_sheath_blight': {'en': 'Sheath Blight', 'si': 'මලාවීන් කුලීන් ඇනීම'},
    'coconut_healthy': {'en': 'Healthy Coconut', 'si': 'සෞඛ්‍යවත් පොල්'},
    'coconut_pest_damage': {'en': 'Pest Damage', 'si': 'පළිබෝධ හානි'},
    'coconut_yellowing': {'en': 'Yellowing', 'si': 'කහවීම'},
    'coconut_leaf_spot': {'en': 'Leaf Spot', 'si': 'පත්‍ර වරූකිරීම'},
  };

  String _cropLabel(String crop) {
    final names = {
      'corn': {'en': 'Corn', 'si': 'මඛුල'},
      'tomato': {'en': 'Tomato', 'si': 'තක්කාලි'},
      'rice': {'en': 'Rice', 'si': 'වියලි'},
      'coconut': {'en': 'Coconut', 'si': 'පොල්'},
    };
    return names[crop]?[widget.language] ?? crop;
  }

  String _diseaseLabel(String? diseaseName) {
    if (diseaseName == null || diseaseName.isEmpty) {
      return widget.language == 'en' ? 'Unknown disease' : 'නොදන්නා රෝගය';
    }
    return diseaseNames[diseaseName]?[widget.language] ?? _formatName(diseaseName);
  }

  List<String> _treatmentSteps(String? diseaseName) {
    if (diseaseName == null || diseaseName.isEmpty) {
      return widget.language == 'en'
          ? ['Please consult an agriculture expert for guidance.']
          : ['නිවැරදි උපදෙස් සඳහා ගොවිතැන් நிபுணවරයෙකුගෙන් සම්මුඛ වන්න.'];
    }
    final steps = treatments[diseaseName]?[widget.language];
    if (steps == null || steps.isEmpty) {
      return widget.language == 'en'
          ? ['Consult an agriculture expert']
          : ['ගොවිතැන් විශාරදවරයෙකුගෙන් උපදෙස් ලබා ගන්න'];
    }
    return steps;
  }

  Future<void> pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 85);

    if (picked == null) return;

    final bytes = await picked.readAsBytes();

    setState(() {
      imageBytes = bytes;
      if (!kIsWeb) {
        imageFile = File(picked.path);
      }
      disease = null;
      confidence = 0;
      treatment = [];
      error = '';
      loading = true;
    });

    await predict(bytes);
  }

  Future<void> predict(Uint8List bytes) async {
    try {
      final base64Image = base64Encode(bytes);
      final response = await http
          .post(
            Uri.parse(apiUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'image': base64Image, 'crop': selectedCrop}),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final diagnosis = data['disease']?.toString();
        final uploadedConfidence = double.parse(data['confidence'].toString());

        setState(() {
          disease = diagnosis;
          confidence = uploadedConfidence;
          treatment = _treatmentSteps(diagnosis);
          loading = false;
        });

        await _saveHistory(diagnosis, uploadedConfidence);
      } else {
        setState(() {
          error = widget.language == 'en' ? 'Server error ${response.statusCode}' : 'සේවාදායක දෝෂය ${response.statusCode}';
          loading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = widget.language == 'en' ? 'Connection error: $e' : 'සම්බන්ධතා දෝෂය: $e';
        loading = false;
      });
    }
  }

  Future<void> _saveHistory(String? diagnosis, double uploadedConfidence) async {
    final prefs = await SharedPreferences.getInstance();
    final historyItems = prefs.getStringList('history') ?? [];
    final entry = {
      'crop': selectedCrop,
      'disease': diagnosis,
      'confidence': uploadedConfidence,
      'timestamp': DateTime.now().toIso8601String(),
      'image': imageBytes != null ? base64Encode(imageBytes!) : null,
    };

    historyItems.insert(0, jsonEncode(entry));
    if (historyItems.length > 20) {
      historyItems.removeRange(20, historyItems.length);
    }
    await prefs.setStringList('history', historyItems);
  }

  void _openTreatmentPage(String? diagnosis, double uploadedConfidence) {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TreatmentPage(
          language: widget.language,
          disease: diagnosis,
          confidence: uploadedConfidence,
          crop: selectedCrop,
          imageBytes: imageBytes,
        ),
      ),
    );
  }

  void _showPickerSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.language == 'en' ? 'Add a leaf photo' : 'පත්‍ර ඡායාරූපයක් එක් කරන්න',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      pickImage(ImageSource.camera);
                    },
                    icon: const Icon(Icons.camera_alt),
                    label: Text(widget.language == 'en' ? 'Camera' : 'කැමරා'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      pickImage(ImageSource.gallery);
                    },
                    icon: const Icon(Icons.photo_library),
                    label: Text(widget.language == 'en' ? 'Gallery' : 'ඝටක ගබඩාව'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatName(String text) {
    return text
        .replaceAll('_', ' ')
        .split(' ')
        .where((segment) => segment.isNotEmpty)
        .map((segment) => segment[0].toUpperCase() + segment.substring(1))
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final isSi = widget.language == 'si';
    return Scaffold(
      appBar: AppBar(
        title: Text(isSi ? '🌿 Crop Guard' : '🌿 Crop Guard'),
        centerTitle: true,
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: widget.onLanguageChanged,
            icon: const Icon(Icons.translate),
            tooltip: isSi ? 'English' : 'සිංහල',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xffE8F5E9), Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 12)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSi ? 'ඔබේ පැල රෝගය පරීක්ෂා කරන්න' : 'Check your plant health',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isSi ? 'පින්තූරයක් උඩුගත කර විශේෂිත AI නිර්ණයක් ලබා ගන්න.' : 'Upload a leaf photo and receive an AI-powered diagnosis.',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCrop,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        labelText: isSi ? 'වගාව' : 'Crop',
                      ),
                      items: crops.map((crop) {
                        return DropdownMenuItem(
                          value: crop,
                          child: Text(_cropLabel(crop)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => selectedCrop = value);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _showPickerSheet,
                child: Container(
                  height: 280,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [BoxShadow(color: Colors.green.withValues(alpha: 0.17), blurRadius: 16)],
                  ),
                  child: imageBytes == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_a_photo, size: 72, color: Colors.green),
                            const SizedBox(height: 10),
                            Text(
                              isSi ? 'පත්‍රය උඩුගත කරන්න' : 'Upload leaf image',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isSi ? 'කැමරා හෝ ගැලරිය භාවිතා කරන්න' : 'Choose camera or gallery',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: Image.memory(imageBytes!, fit: BoxFit.cover),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _showPickerSheet,
                  icon: const Icon(Icons.upload_file),
                  label: Text(isSi ? 'පින්තූරයක් තෝරන්න' : 'Choose image'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (loading)
                Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    Text(isSi ? 'AI නිර්ණය කරමින්...' : 'AI is analysing the leaf...'),
                  ],
                )
              else if (error.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(error, style: TextStyle(color: Colors.red.shade700)),
                )
              else if (disease != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(
                            isSi ? 'නිර්ණය සම්පූර්ණයි' : 'Diagnosis complete',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('${isSi ? 'වගාව' : 'Crop'}: ${_cropLabel(selectedCrop)}'),
                      Text('${isSi ? 'රෝගය' : 'Disease'}: ${_diseaseLabel(disease)}'),
                      Text('${isSi ? 'විශ්වාසනීයත්වය' : 'Confidence'}: ${confidence.toStringAsFixed(1)}%'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _openTreatmentPage(disease, confidence),
                            icon: const Icon(Icons.medical_services_outlined),
                            label: Text(isSi ? 'ප්‍රතිකාර බලන්න' : 'View treatment'),
                          ),
                          if (confidence < 70)
                            OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (context) => ExpertsPage(language: widget.language)),
                                );
                              },
                              icon: const Icon(Icons.contact_phone),
                              label: Text(isSi ? 'කෘෂි විශාරදයින්ට සම්බන්ධ වන්න' : 'Contact experts'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TreatmentPage extends StatelessWidget {
  const TreatmentPage({required this.language, required this.disease, required this.confidence, required this.crop, required this.imageBytes, super.key});

  final String language;
  final String? disease;
  final double confidence;
  final String crop;
  final Uint8List? imageBytes;

  String _cropLabel(String cropName) {
    final names = {
      'corn': {'en': 'Corn', 'si': 'මඛුල'},
      'tomato': {'en': 'Tomato', 'si': 'තක්කාලි'},
      'rice': {'en': 'Rice', 'si': 'වියලි'},
      'coconut': {'en': 'Coconut', 'si': 'පොල්'},
    };
    return names[cropName]?[language] ?? cropName;
  }

  String _diseaseLabel(String? diseaseName) {
    final diseaseNames = {
      'corn_blight': {'en': 'Corn Blight', 'si': 'මඛුල කුලීන් ඇනීම'},
      'corn_common_rust': {'en': 'Common Rust', 'si': 'සාමාන්‍ය කහ පැල්ලම්'},
      'corn_gray_leaf_spot': {'en': 'Gray Leaf Spot', 'si': 'අළු පත්‍ර කුණුවීම'},
      'corn_healthy': {'en': 'Healthy Corn', 'si': 'සෞඛ්‍යවත් මඛුල'},
      'tomato_bacterial_spot': {'en': 'Bacterial Spot', 'si': 'බැක්ටීරියා ව්‍යාධිය'},
      'tomato_early_blight': {'en': 'Early Blight', 'si': 'මුල් කුලීන් ඇනීම'},
      'tomato_late_blight': {'en': 'Late Blight', 'si': 'පසු කුලීන් ඇනීම'},
      'tomato_leaf_mold': {'en': 'Leaf Mold', 'si': 'පත්‍ර අඳුරු බිඳ'},
      'tomato_septoria_leaf_spot': {'en': 'Septoria Leaf Spot', 'si': 'සෙප්ටෝරියා පත්‍ර වරූකිරීම'},
      'tomato_spider_mites': {'en': 'Spider Mites', 'si': 'මදුරුවන් මයිටා'},
      'tomato_target_spot': {'en': 'Target Spot', 'si': 'ලක්ෂ්‍ය වරූකිරීම'},
      'tomato_yellow_leaf_curl_virus': {'en': 'Yellow Leaf Curl Virus', 'si': 'කහ පත්‍ර කුමන් ව්‍යාධිය'},
      'tomato_mosaic_virus': {'en': 'Mosaic Virus', 'si': 'මොසැයික් වෛරසය'},
      'tomato_healthy': {'en': 'Healthy Tomato', 'si': 'සෞඛ්‍යවත් තක්කාලි'},
      'tomato_powdery_mildew': {'en': 'Powdery Mildew', 'si': 'පවුඩර් මයිල්ඩුව'},
      'rice_bacterial_leaf_blight': {'en': 'Bacterial Leaf Blight', 'si': 'බැක්ටීරියා පත්‍ර කුලීන් ඇනීම'},
      'rice_brown_spot': {'en': 'Brown Spot', 'si': 'දුඹුරු වරූකිරීම'},
      'rice_healthy': {'en': 'Healthy Rice', 'si': 'සෞඛ්‍යවත් වියලි'},
      'rice_leaf_blast': {'en': 'Leaf Blast', 'si': 'පත්‍ර පැතීම'},
      'rice_leaf_scald': {'en': 'Leaf Scald', 'si': 'පත්‍ර රිදිම'},
      'rice_sheath_blight': {'en': 'Sheath Blight', 'si': 'මලාවීන් කුලීන් ඇනීම'},
      'coconut_healthy': {'en': 'Healthy Coconut', 'si': 'සෞඛ්‍යවත් පොල්'},
      'coconut_pest_damage': {'en': 'Pest Damage', 'si': 'පළිබෝධ හානි'},
      'coconut_yellowing': {'en': 'Yellowing', 'si': 'කහවීම'},
      'coconut_leaf_spot': {'en': 'Leaf Spot', 'si': 'පත්‍ර වරූකිරීම'},
    };
    if (diseaseName == null || diseaseName.isEmpty) {
      return language == 'en' ? 'Unknown disease' : 'නොදන්නා රෝගය';
    }
    return diseaseNames[diseaseName]?[language] ?? diseaseName.replaceAll('_', ' ');
  }

  List<String> _treatmentSteps(String? diseaseName) {
    final treatments = {
      'corn_blight': {'en': ['Remove infected leaves', 'Use resistant corn varieties', 'Apply recommended fungicide', 'Maintain proper plant spacing'], 'si': ['ලෙඩී වූ පත්‍ර ඉවත් කරන්න', 'ප්‍රතිරෝධී මඛුල වර්ග භාවිතා කරන්න', 'නිර්දේශිත කෘමිනෝධකයක් යොදන්න', 'සහනවත් පැල පරතරයක් පවත්වා ගන්න']},
      'corn_common_rust': {'en': ['Use rust resistant varieties', 'Apply fungicide when needed', 'Remove infected plant debris'], 'si': ['කළු කුරුලු ප්‍රතිරෝධී වර්ග භාවිතා කරන්න', 'අවශ්‍ය විට කෘමිනෝධකයක් යොදන්න', 'ලෙඩී පැල නරක් කිරීම ඉවත් කරන්න']},
      'corn_gray_leaf_spot': {'en': ['Practice crop rotation', 'Improve field ventilation', 'Apply suitable fungicide'], 'si': ['වගාව භ්‍රමණය කරන්න', 'ක්ෂේත්‍රයේ වායු සම්ප්‍රේෂණය වැඩි කරන්න', 'ගැලපෙන කෘමිනෝධකයක් යොදන්න']},
      'corn_healthy': {'en': ['Plant is healthy', 'Continue normal farming practices'], 'si': ['පැල සෞඛ්යවත්', 'සාමාන්‍ය ගොවිතැන ඉදිරියටම කරගෙන යන්න']},
      'tomato_bacterial_spot': {'en': ['Remove infected leaves', 'Disinfect farming tools', 'Avoid overhead irrigation', 'Apply copper based bactericide'], 'si': ['ලෙඩී වූ පත්‍ර ඉවත් කරන්න', 'ගොවිතැනේ මෙවලම් ශුද්ධ කරන්න', 'ඉහළින් පිරිනැමෙන ජල සපයුමෙන් වළක්වන්න', 'තඹ මත පදනම් වූ බැක්ටීරියාහරණයක් යොදන්න']},
      'tomato_early_blight': {'en': ['Remove infected leaves', 'Apply fungicide', 'Use crop rotation', 'Avoid leaf wetness'], 'si': ['ලෙඩී වූ පත්‍ර ඉවත් කරන්න', 'කෘමිනෝධකයක් යොදන්න', 'වගාව භ්‍රමණය කරන්න', 'පත්‍ර ගිල්වීම වළක්වන්න']},
      'tomato_late_blight': {'en': ['Remove infected plants', 'Apply copper fungicide', 'Reduce humidity', 'Improve air circulation'], 'si': ['ලෙඩී වූ පැළ ඉවත් කරන්න', 'තඹ කෘමිනෝධකයක් යොදන්න', 'උෂ්ණත්වය අඩු කරන්න', 'වායු ප්‍රවාහය වැඩි කරන්න']},
      'tomato_leaf_mold': {'en': ['Reduce humidity', 'Improve ventilation', 'Remove infected leaves', 'Apply fungicide'], 'si': ['උෂ්ණත්වය අඩු කරන්න', 'වායු සංසරණය වැඩි කරන්න', 'ලෙඩී වූ පත්‍ර ඉවත් කරන්න', 'කෘමිනෝධකයක් යොදන්න']},
      'tomato_septoria_leaf_spot': {'en': ['Remove infected leaves', 'Use crop rotation', 'Apply suitable fungicide'], 'si': ['ලෙඩී වූ පත්‍ර ඉවත් කරන්න', 'වගාව භ්‍රමණය කරන්න', 'ගැලපෙන කෘමිනෝධකයක් යොදන්න']},
      'tomato_spider_mites': {'en': ['Spray water to remove mites', 'Use insecticidal soap', 'Maintain plant health'], 'si': ['මයිටා පරම්පරාව ඉවත් කිරීමට ජල ස්ප්‍රේ කරයි', 'කීටෝනಾಶක සබන් භාවිතා කරන්න', 'පැල සෞඛ්‍යය පවත්වා ගන්න']},
      'tomato_target_spot': {'en': ['Remove infected leaves', 'Improve air circulation', 'Apply fungicide'], 'si': ['ලෙඩී වූ පත්‍ර ඉවත් කරන්න', 'වායු ප්‍රවාහය වැඩි කරන්න', 'කෘමිනෝධකයක් යොදන්න']},
      'tomato_yellow_leaf_curl_virus': {'en': ['Control whiteflies', 'Remove infected plants', 'Use resistant varieties'], 'si': ['සුදු පියාපත් පාලනය කරන්න', 'ලෙඩී වූ පැළ ඉවත් කරන්න', 'ප්‍රතිරෝධී වර්ග භාවිතා කරන්න']},
      'tomato_mosaic_virus': {'en': ['Remove infected plants', 'Disinfect tools', 'Control insect vectors'], 'si': ['ලෙඩී වූ පැළ ඉවත් කරන්න', 'මෙවලම් ශුද්ධ කරන්න', 'කීටෝ පරම්පරා පාලනය කරන්න']},
      'tomato_healthy': {'en': ['Plant is healthy', 'Continue normal farming'], 'si': ['පැල සෞඛ්යවත්', 'සාමාන්‍ය ගොවිතැන දිගටම කරගෙන යන්න']},
      'tomato_powdery_mildew': {'en': ['Improve air circulation', 'Remove infected leaves', 'Apply sulfur fungicide'], 'si': ['වායු සංසරණය වැඩි කරන්න', 'ලෙඩී වූ පත්‍ර ඉවත් කරන්න', 'සල්ෆර් කෘමිනෝධකයක් යොදන්න']},
      'rice_bacterial_leaf_blight': {'en': ['Use resistant rice varieties', 'Avoid excess nitrogen fertilizer', 'Maintain proper water management'], 'si': ['ප්‍රතිරෝධී වියලි වර්ග භාවිතා කරන්න', 'අතිරේක නයිට්‍රජන් පොහොර වැළැක්වන්න', 'නිසි ජල කළමනාකරණය පවත්වා ගන්න']},
      'rice_brown_spot': {'en': ['Use healthy seeds', 'Improve soil nutrition', 'Apply suitable fungicide'], 'si': ['සෞඛ්‍යවත් බීජ භාවිතා කරන්න', 'පසෙහි පොෂණය වැඩි කරන්න', 'ගැලපෙන කෘමිනෝධකයක් යොදන්න']},
      'rice_healthy': {'en': ['Rice plant is healthy', 'Continue normal cultivation'], 'si': ['බත් පත සෞඛ්යවත්', 'සාමාන්‍ය වගා ක්‍රියාවලිය දිගටම කරගෙන යන්න']},
      'rice_leaf_blast': {'en': ['Use resistant varieties', 'Avoid excess nitrogen', 'Apply recommended fungicide'], 'si': ['ප්‍රතිරෝධී වර්ග භාවිතා කරන්න', 'අතිරේක නයිට්‍රජන් වළක්වන්න', 'නිර්දේශිත කෘමිනෝධකයක් යොදන්න']},
      'rice_leaf_scald': {'en': ['Maintain proper field drainage', 'Remove infected residues', 'Use balanced fertilizer'], 'si': ['නිසි කෙත ජල අපාදනය පවත්වා ගන්න', 'ලෙඩී වූ ඉතිරි ද්‍රව්‍ය ඉවත් කරන්න', 'සමාන්තර පොහොර භාවිතා කරන්න']},
      'rice_sheath_blight': {'en': ['Reduce plant density', 'Control field humidity', 'Apply fungicide'], 'si': ['පැල ඝනත්වය අඩු කරන්න', 'කෙතේ වෘද්ධිය පාලනය කරන්න', 'කෘමිනෝධකයක් යොදන්න']},
      'coconut_healthy': {'en': ['Palm is healthy', 'Continue regular maintenance'], 'si': ['තැඹිලි පඳුරු සෞඛ්‍යවත්', 'නිත්‍ය නඩත්තු දිගටම කරගෙන යන්න']},
      'coconut_pest_damage': {'en': ['Remove damaged parts', 'Control pests', 'Apply recommended pesticides'], 'si': ['හානි වූ කොටස් ඉවත් කරන්න', 'පළිබෝධ පාලනය කරන්න', 'නිර්දේශිත කෘමිනාශක යොදන්න']},
      'coconut_yellowing': {'en': ['Check soil nutrients', 'Apply balanced fertilizer', 'Improve drainage'], 'si': ['පසෙහි පෝෂක මට්ටම පරීක්ෂා කරන්න', 'සමාන්තර පොහොර යොදන්න', 'ජල පිසීම වැඩි කරන්න']},
      'coconut_leaf_spot': {'en': ['Remove infected leaves', 'Apply fungicide', 'Maintain nutrients'], 'si': ['ලෙඩී වූ පත්‍ර ඉවත් කරන්න', 'කෘමිනෝධකයක් යොදන්න', 'පෝෂක පවත්වා ගන්න']},
    };
    if (diseaseName == null || diseaseName.isEmpty) {
      return language == 'en' ? ['Consult an agriculture expert'] : ['ගොවිතැන් විශාරදවරයෙකුගෙන් උපදෙස් ලබා ගන්න'];
    }
    return treatments[diseaseName]?[language] ?? [language == 'en' ? 'Consult an agriculture expert' : 'ගොවිතැන් විශාරදවරයෙකුගෙන් උපදෙස් ලබා ගන්න'];
  }

  @override
  Widget build(BuildContext context) {
    final isSi = language == 'si';
    return Scaffold(
      appBar: AppBar(
        title: Text(isSi ? 'ප්‍රතිකාර පිළිවෙල' : 'Treatment guide'),
        centerTitle: true,
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xffE8F5E9), Colors.white], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imageBytes != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.memory(imageBytes!, height: 220, width: double.infinity, fit: BoxFit.cover),
                ),
              const SizedBox(height: 16),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isSi ? 'නිර්ණාකාරී සාරාංශය' : 'Diagnosis summary',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text('${isSi ? 'වගාව' : 'Crop'}: ${_cropLabel(crop)}'),
                      Text('${isSi ? 'රෝගය' : 'Disease'}: ${_diseaseLabel(disease)}'),
                      Text('${isSi ? 'විශ්වාසනීයත්වය' : 'Confidence'}: ${confidence.toStringAsFixed(1)}%'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isSi ? 'දියුණු කළ හැකි පියවර' : 'Recommended actions',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ..._treatmentSteps(disease).map(
                (step) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(step)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (confidence < 70)
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (context) => ExpertsPage(language: language)));
                  },
                  icon: const Icon(Icons.contact_support),
                  label: Text(isSi ? 'කෘෂි විශාරදවරයෙකු සම්බන්ධ කරගන්න' : 'Connect with an agriculture expert'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ExpertsPage extends StatelessWidget {
  const ExpertsPage({required this.language, super.key});

  final String language;

  @override
  Widget build(BuildContext context) {
    final isSi = language == 'si';
    final experts = [
      {
        'name': isSi ? 'ගොවිතැන් කාර්යාලය - 1920' : 'Department of Agriculture Hotline',
        'role': isSi ? 'ස්ත්‍රීකරණය කළ හැකි රෙජිවනල් උපකාර' : 'Verified national support line',
        'phone': '1920',
        'location': isSi ? 'ශ්‍රී ලංකාව පුරා' : 'Across Sri Lanka',
        'note': isSi ? 'නිල මාර්ගය. ඔබට කෙටි කේතය භාවිතා කරත් හා සම්බන්ධ විය හැක.' : 'Official public helpline available through the national service line.',
      },
      {
        'name': isSi ? 'ප්‍රාදේශීය වගා විශාරද' : 'Local Extension Officer',
        'role': isSi ? 'දේශීය උපදෙස්' : 'Regional field guidance',
        'phone': isSi ? 'ඔබේ දුරකතන අංකය එක් කරන්න' : 'Add your local phone',
        'location': isSi ? 'ඔබේ ප්‍රාදේශීය කාර්යාලය' : 'Your district office',
        'note': isSi ? 'මිලියම් ආකාරයෙන් ඔබේ ප්‍රාදේශීය විශේෂඥයින් සටහන් කරන්න.' : 'Replace with your own local officer details.',
      },
      {
        'name': isSi ? 'පොහොර/පළිබෝධ උපදෙස්' : 'Crop clinic contact',
        'role': isSi ? 'දෙවන මට්ටමේ උපදෙස්' : 'Follow-up support',
        'phone': isSi ? 'ඔබේ දුරකතන අංකය එක් කරන්න' : 'Add your farm clinic number',
        'location': isSi ? 'ඔබේ දිස්ත්‍රික්කය' : 'Your district',
        'note': isSi ? 'අවසන් මට්ටමේදී ඉක්මනින් සම්බන්ධ වන්න.' : 'Useful when a diagnosis needs a second opinion.',
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(isSi ? 'කෘෂි විශාරදයින්' : 'Agriculture experts'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xffE8F5E9), Colors.white], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: experts.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final expert = experts[index];
            return Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: ListTile(
                leading: CircleAvatar(backgroundColor: Colors.green.shade100, child: const Icon(Icons.support_agent, color: Colors.green)),
                title: Text(expert['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(expert['role'] as String),
                    Text('${isSi ? 'දුරකථන අංකය' : 'Phone'}: ${expert['phone']}'),
                    Text('${isSi ? 'ස්ථානය' : 'Location'}: ${expert['location']}'),
                    Text(expert['note'] as String, style: TextStyle(color: Colors.grey.shade700)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class HistoryPage extends StatefulWidget {
  const HistoryPage({required this.language, super.key});

  final String language;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<Map<String, dynamic>> items = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('history') ?? [];
    final parsed = raw.map((entry) => jsonDecode(entry) as Map<String, dynamic>).toList();
    setState(() {
      items = parsed;
      loading = false;
    });
  }

  String _cropLabel(String cropName) {
    final names = {
      'corn': {'en': 'Corn', 'si': 'මඛුල'},
      'tomato': {'en': 'Tomato', 'si': 'තක්කාලි'},
      'rice': {'en': 'Rice', 'si': 'වියලි'},
      'coconut': {'en': 'Coconut', 'si': 'පොල්'},
    };
    return names[cropName]?[widget.language] ?? cropName;
  }

  String _diseaseLabel(String? diseaseName) {
    final diseaseNames = {
      'corn_blight': {'en': 'Corn Blight', 'si': 'මඛුල කුලීන් ඇනීම'},
      'corn_common_rust': {'en': 'Common Rust', 'si': 'සාමාන්‍ය කහ පැල්ලම්'},
      'corn_gray_leaf_spot': {'en': 'Gray Leaf Spot', 'si': 'අළු පත්‍ර කුණුවීම'},
      'corn_healthy': {'en': 'Healthy Corn', 'si': 'සෞඛ්‍යවත් මඛුල'},
      'tomato_bacterial_spot': {'en': 'Bacterial Spot', 'si': 'බැක්ටීරියා ව්‍යාධිය'},
      'tomato_early_blight': {'en': 'Early Blight', 'si': 'මුල් කුලීන් ඇනීම'},
      'tomato_late_blight': {'en': 'Late Blight', 'si': 'පසු කුලීන් ඇනීම'},
      'tomato_leaf_mold': {'en': 'Leaf Mold', 'si': 'පත්‍ර අඳුරු බිඳ'},
      'tomato_septoria_leaf_spot': {'en': 'Septoria Leaf Spot', 'si': 'සෙප්ටෝරියා පත්‍ර වරූකිරීම'},
      'tomato_spider_mites': {'en': 'Spider Mites', 'si': 'මදුරුවන් මයිටා'},
      'tomato_target_spot': {'en': 'Target Spot', 'si': 'ලක්ෂ්‍ය වරූකිරීම'},
      'tomato_yellow_leaf_curl_virus': {'en': 'Yellow Leaf Curl Virus', 'si': 'කහ පත්‍ර කුමන් ව්‍යාධිය'},
      'tomato_mosaic_virus': {'en': 'Mosaic Virus', 'si': 'මොසැයික් වෛරසය'},
      'tomato_healthy': {'en': 'Healthy Tomato', 'si': 'සෞඛ්‍යවත් තක්කාලි'},
      'tomato_powdery_mildew': {'en': 'Powdery Mildew', 'si': 'පවුඩර් මයිල්ඩුව'},
      'rice_bacterial_leaf_blight': {'en': 'Bacterial Leaf Blight', 'si': 'බැක්ටීරියා පත්‍ර කුලීන් ඇනීම'},
      'rice_brown_spot': {'en': 'Brown Spot', 'si': 'දුඹුරු වරූකිරීම'},
      'rice_healthy': {'en': 'Healthy Rice', 'si': 'සෞඛ්‍යවත් වියලි'},
      'rice_leaf_blast': {'en': 'Leaf Blast', 'si': 'පත්‍ර පැතීම'},
      'rice_leaf_scald': {'en': 'Leaf Scald', 'si': 'පත්‍ර රිදිම'},
      'rice_sheath_blight': {'en': 'Sheath Blight', 'si': 'මලාවීන් කුලීන් ඇනීම'},
      'coconut_healthy': {'en': 'Healthy Coconut', 'si': 'සෞඛ්‍යවත් පොල්'},
      'coconut_pest_damage': {'en': 'Pest Damage', 'si': 'පළිබෝධ හානි'},
      'coconut_yellowing': {'en': 'Yellowing', 'si': 'කහවීම'},
      'coconut_leaf_spot': {'en': 'Leaf Spot', 'si': 'පත්‍ර වරූකිරීම'},
    };
    if (diseaseName == null || diseaseName.isEmpty) {
      return widget.language == 'en' ? 'Unknown disease' : 'නොදන්නා රෝගය';
    }
    return diseaseNames[diseaseName]?[widget.language] ?? diseaseName.replaceAll('_', ' ');
  }

  @override
  Widget build(BuildContext context) {
    final isSi = widget.language == 'si';
    return Scaffold(
      appBar: AppBar(
        title: Text(isSi ? 'වගා ඉතිහාසය' : 'Past diagnoses'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xffE8F5E9), Colors.white], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        isSi ? 'තවම පරීක්ෂණ ඉතිහාසයක් නැත. ප්‍රථම වරට රෝගයක් නිර්ණය කරන්න.' : 'No scan history yet. Diagnose a leaf to start saving results.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final imageData = item['image']?.toString();
                      return Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (imageData != null && imageData.isNotEmpty)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.memory(
                                    base64Decode(imageData),
                                    width: 90,
                                    height: 90,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              else
                                Container(
                                  width: 90,
                                  height: 90,
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(Icons.image, color: Colors.green),
                                ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${_cropLabel(item['crop']?.toString() ?? '')} • ${_diseaseLabel(item['disease']?.toString())}',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    Text('${isSi ? 'විශ්වාසනීයත්වය' : 'Confidence'}: ${(item['confidence'] as double?)?.toStringAsFixed(1) ?? '0'}%'),
                                    Text('${isSi ? 'දිනය' : 'Date'}: ${DateTime.parse(item['timestamp'].toString()).toLocal().toString().split('.')[0]}'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

class LibraryPage extends StatefulWidget {
  const LibraryPage({required this.language, super.key});

  final String language;

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  String selectedCrop = 'tomato';

  final List<String> crops = ['corn', 'tomato', 'rice', 'coconut'];

  String _cropLabel(String cropName) {
    final names = {
      'corn': {'en': 'Corn', 'si': 'මඛුල'},
      'tomato': {'en': 'Tomato', 'si': 'තක්කාලි'},
      'rice': {'en': 'Rice', 'si': 'වියලි'},
      'coconut': {'en': 'Coconut', 'si': 'පොල්'},
    };
    return names[cropName]?[widget.language] ?? cropName;
  }

  List<Map<String, dynamic>> _diseaseEntries() {
    final data = <String, List<Map<String, dynamic>>>{
      'corn': [
        {
          'disease': 'corn_blight',
          'en': 'Corn Blight',
          'si': 'මඛුල කුලීන් ඇනීම',
          'steps': {
            'en': <String>['Remove infected leaves', 'Use resistant varieties', 'Apply fungicide'],
            'si': <String>['ලෙඩී වූ පත්‍ර ඉවත් කරන්න', 'ප්‍රතිරෝධී වර්ග භාවිතා කරන්න', 'කෘමිනෝධකයක් යොදන්න'],
          },
        },
        {
          'disease': 'corn_common_rust',
          'en': 'Common Rust',
          'si': 'සාමාන්‍ය කහ පැල්ලම්',
          'steps': {
            'en': <String>['Use rust resistant varieties', 'Apply fungicide when needed', 'Remove debris'],
            'si': <String>['කළු කුරුලු ප්‍රතිරෝධී වර්ග භාවිතා කරන්න', 'අවශ්‍ය විට කෘමිනෝධකයක් යොදන්න', 'ඉතිරි ද්‍රව්‍ය ඉවත් කරන්න'],
          },
        },
        {
          'disease': 'corn_gray_leaf_spot',
          'en': 'Gray Leaf Spot',
          'si': 'අළු පත්‍ර කුණුවීම',
          'steps': {
            'en': <String>['Practice crop rotation', 'Improve ventilation', 'Apply fungicide'],
            'si': <String>['වගාව භ්‍රමණය කරන්න', 'වායු සංසරණය වැඩි කරන්න', 'කෘමිනෝධකයක් යොදන්න'],
          },
        },
        {
          'disease': 'corn_healthy',
          'en': 'Healthy Corn',
          'si': 'සෞඛ්‍යවත් මඛුල',
          'steps': {
            'en': <String>['Plant is healthy', 'Continue regular maintenance'],
            'si': <String>['පැල සෞඛ්යවත්', 'නිත්‍ය නඩත්තු දිගටම කරගෙන යන්න'],
          },
        },
      ],
      'tomato': [
        {
          'disease': 'tomato_early_blight',
          'en': 'Early Blight',
          'si': 'මුල් කුලීන් ඇනීම',
          'steps': {
            'en': <String>['Remove infected leaves', 'Apply fungicide', 'Avoid wet leaves'],
            'si': <String>['ලෙඩී වූ පත්‍ර ඉවත් කරන්න', 'කෘමිනෝධකයක් යොදන්න', 'තෙත තත්වය වළක්වන්න'],
          },
        },
        {
          'disease': 'tomato_late_blight',
          'en': 'Late Blight',
          'si': 'පසු කුලීන් ඇනීම',
          'steps': {
            'en': <String>['Remove infected plants', 'Apply copper fungicide', 'Improve airflow'],
            'si': <String>['ලෙඩී වූ පැළ ඉවත් කරන්න', 'තඹ කෘමිනෝධකයක් යොදන්න', 'වායු ප්‍රවාහය වැඩි කරන්න'],
          },
        },
        {
          'disease': 'tomato_bacterial_spot',
          'en': 'Bacterial Spot',
          'si': 'බැක්ටීරියා ව්‍යාධිය',
          'steps': {
            'en': <String>['Remove infected leaves', 'Disinfect tools', 'Avoid overhead irrigation'],
            'si': <String>['ලෙඩී වූ පත්‍ර ඉවත් කරන්න', 'මෙවලම් ශුද්ධ කරන්න', 'ඉහළින් පිරිනැමෙන ජල සපයුමෙන් වළක්වන්න'],
          },
        },
        {
          'disease': 'tomato_healthy',
          'en': 'Healthy Tomato',
          'si': 'සෞඛ්‍යවත් තක්කාලි',
          'steps': {
            'en': <String>['Plant is healthy', 'Continue regular maintenance'],
            'si': <String>['පැල සෞඛ්යවත්', 'නිත්‍ය නඩත්තු දිගටම කරගෙන යන්න'],
          },
        },
      ],
      'rice': [
        {
          'disease': 'rice_bacterial_leaf_blight',
          'en': 'Bacterial Leaf Blight',
          'si': 'බැක්ටීරියා පත්‍ර කුලීන් ඇනීම',
          'steps': {
            'en': <String>['Use resistant varieties', 'Avoid excess nitrogen', 'Manage water carefully'],
            'si': <String>['ප්‍රතිරෝධී වර්ග භාවිතා කරන්න', 'අතිරේක නයිට්‍රජන් වළක්වන්න', 'ජලය අවධානයෙන් කළමනාකරණය කරන්න'],
          },
        },
        {
          'disease': 'rice_leaf_blast',
          'en': 'Leaf Blast',
          'si': 'පත්‍ර පැතීම',
          'steps': {
            'en': <String>['Use resistant varieties', 'Reduce nitrogen', 'Use fungicide'],
            'si': <String>['ප්‍රතිරෝධී වර්ග භාවිතා කරන්න', 'නයිට්‍රජන් අඩු කරන්න', 'කෘමිනෝධකයක් යොදන්න'],
          },
        },
        {
          'disease': 'rice_healthy',
          'en': 'Healthy Rice',
          'si': 'සෞඛ්‍යවත් වියලි',
          'steps': {
            'en': <String>['Rice plant is healthy', 'Continue normal cultivation'],
            'si': <String>['බත් පත සෞඛ්යවත්', 'සාමාන්‍ය වගා ක්‍රියාවලිය දිගටම කරගෙන යන්න'],
          },
        },
      ],
      'coconut': [
        {
          'disease': 'coconut_yellowing',
          'en': 'Yellowing',
          'si': 'කහවීම',
          'steps': {
            'en': <String>['Check soil nutrition', 'Apply balanced fertilizer', 'Improve drainage'],
            'si': <String>['පසෙහි පෝෂණය පරීක්ෂා කරන්න', 'සමාන්තර පොහොර යොදන්න', 'ජල පිසීම වැඩි කරන්න'],
          },
        },
        {
          'disease': 'coconut_pest_damage',
          'en': 'Pest Damage',
          'si': 'පළිබෝධ හානි',
          'steps': {
            'en': <String>['Remove damaged parts', 'Control pests', 'Apply pesticides'],
            'si': <String>['හානි වූ කොටස් ඉවත් කරන්න', 'පළිබෝධ පාලනය කරන්න', 'කෘමිනාශක යොදන්න'],
          },
        },
        {
          'disease': 'coconut_healthy',
          'en': 'Healthy Coconut',
          'si': 'සෞඛ්‍යවත් පොල්',
          'steps': {
            'en': <String>['Palm is healthy', 'Continue regular maintenance'],
            'si': <String>['තැඹිලි පඳුරු සෞඛ්‍යවත්', 'නිත්‍ය නඩත්තු දිගටම කරගෙන යන්න'],
          },
        },
      ],
    };
    return data[selectedCrop] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final isSi = widget.language == 'si';
    return Scaffold(
      appBar: AppBar(
        title: Text(isSi ? 'රෝග පුස්තකාලය' : 'Disease library'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xffE8F5E9), Colors.white], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 8,
                children: crops.map((crop) {
                  final active = crop == selectedCrop;
                  return ChoiceChip(
                    label: Text(_cropLabel(crop)),
                    selected: active,
                    onSelected: (_) => setState(() => selectedCrop = crop),
                  );
                }).toList(),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: _diseaseEntries().length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final entry = _diseaseEntries()[index];
                  final steps = entry['steps'][widget.language] as List<dynamic>? ?? [];
                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entry[widget.language] as String, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ...steps.map((step) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.brightness_1, size: 8, color: Colors.green),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(step.toString())),
                                  ],
                                ),
                              )),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}