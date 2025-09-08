import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';

class DiseaseAnalysisRecord {
  final String id;
  final String imageHash;
  final String detectedDisease;
  final double confidence;
  final Map<String, dynamic> visualFeatures;
  final Map<String, dynamic> diseaseIndicators;
  final DateTime timestamp;
  final String userId;
  final bool isSuccessful;

  DiseaseAnalysisRecord({
    required this.id,
    required this.imageHash,
    required this.detectedDisease,
    required this.confidence,
    required this.visualFeatures,
    required this.diseaseIndicators,
    required this.timestamp,
    required this.userId,
    required this.isSuccessful,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'imageHash': imageHash,
      'detectedDisease': detectedDisease,
      'confidence': confidence,
      'visualFeatures': visualFeatures,
      'diseaseIndicators': diseaseIndicators,
      'timestamp': timestamp.toIso8601String(),
      'userId': userId,
      'isSuccessful': isSuccessful,
    };
  }

  factory DiseaseAnalysisRecord.fromJson(Map<String, dynamic> json) {
    return DiseaseAnalysisRecord(
      id: json['id'],
      imageHash: json['imageHash'],
      detectedDisease: json['detectedDisease'],
      confidence: json['confidence'].toDouble(),
      visualFeatures: Map<String, dynamic>.from(json['visualFeatures']),
      diseaseIndicators: Map<String, dynamic>.from(json['diseaseIndicators']),
      timestamp: DateTime.parse(json['timestamp']),
      userId: json['userId'],
      isSuccessful: json['isSuccessful'],
    );
  }
}

class UserSession {
  final String sessionId;
  final String userId;
  final DateTime startTime;
  final List<String> analysisIds;
  final int totalAnalyses;
  final int successfulDetections;

  UserSession({
    required this.sessionId,
    required this.userId,
    required this.startTime,
    required this.analysisIds,
    required this.totalAnalyses,
    required this.successfulDetections,
  });

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'userId': userId,
      'startTime': startTime.toIso8601String(),
      'analysisIds': analysisIds,
      'totalAnalyses': totalAnalyses,
      'successfulDetections': successfulDetections,
    };
  }

  factory UserSession.fromJson(Map<String, dynamic> json) {
    return UserSession(
      sessionId: json['sessionId'],
      userId: json['userId'],
      startTime: DateTime.parse(json['startTime']),
      analysisIds: List<String>.from(json['analysisIds']),
      totalAnalyses: json['totalAnalyses'],
      successfulDetections: json['successfulDetections'],
    );
  }
}

class DiseaseService {
  static const String _databasePath = 'backend/disease_database.json';
  Map<String, dynamic> _database = {};
  
  // Singleton pattern
  static final DiseaseService _instance = DiseaseService._internal();
  factory DiseaseService() => _instance;
  DiseaseService._internal();

  Future<void> initialize() async {
    await _loadDatabase();
  }

  Future<void> _loadDatabase() async {
    try {
      final file = File(_databasePath);
      if (await file.exists()) {
        final content = await file.readAsString();
        _database = json.decode(content);
      } else {
        // Create default database structure
        _database = {
          "diseases": {},
          "analysis_records": [],
          "user_sessions": [],
          "system_stats": {
            "total_analyses": 0,
            "successful_detections": 0,
            "average_confidence": 0.0,
            "most_common_disease": null,
            "last_updated": null
          }
        };
        await _saveDatabase();
      }
    } catch (e) {
      debugPrint('Error loading database: $e');
      _database = {
        "diseases": {},
        "analysis_records": [],
        "user_sessions": [],
        "system_stats": {
          "total_analyses": 0,
          "successful_detections": 0,
          "average_confidence": 0.0,
          "most_common_disease": null,
          "last_updated": null
        }
      };
    }
  }

  Future<void> _saveDatabase() async {
    try {
      final file = File(_databasePath);
      await file.writeAsString(json.encode(_database));
    } catch (e) {
      debugPrint('Error saving database: $e');
    }
  }

  // Save disease analysis record
  Future<void> saveAnalysisRecord(DiseaseAnalysisRecord record) async {
    _database['analysis_records'].add(record.toJson());
    
    // Update disease statistics
    if (_database['diseases'][record.detectedDisease] != null) {
      _database['diseases'][record.detectedDisease]['total_detections']++;
      if (record.isSuccessful) {
        _database['diseases'][record.detectedDisease]['successful_detections']++;
      }
    }
    
    // Update system statistics
    _database['system_stats']['total_analyses']++;
    if (record.isSuccessful) {
      _database['system_stats']['successful_detections']++;
    }
    
    // Calculate average confidence
    final records = _database['analysis_records'] as List;
    if (records.isNotEmpty) {
      double totalConfidence = 0.0;
      for (var record in records) {
        totalConfidence += record['confidence'];
      }
      _database['system_stats']['average_confidence'] = totalConfidence / records.length;
    }
    
    // Find most common disease
    Map<String, int> diseaseCounts = {};
    for (var record in records) {
      final disease = record['detectedDisease'];
      diseaseCounts[disease] = (diseaseCounts[disease] ?? 0) + 1;
    }
    
    if (diseaseCounts.isNotEmpty) {
      String mostCommon = diseaseCounts.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
      _database['system_stats']['most_common_disease'] = mostCommon;
    }
    
    _database['system_stats']['last_updated'] = DateTime.now().toIso8601String();
    
    await _saveDatabase();
  }

  // Save user session
  Future<void> saveUserSession(UserSession session) async {
    _database['user_sessions'].add(session.toJson());
    await _saveDatabase();
  }

  // Get analysis history for a user
  Future<List<DiseaseAnalysisRecord>> getUserAnalysisHistory(String userId) async {
    final records = _database['analysis_records'] as List;
    return records
        .where((record) => record['userId'] == userId)
        .map((record) => DiseaseAnalysisRecord.fromJson(record))
        .toList();
  }

  // Get system statistics
  Future<Map<String, dynamic>> getSystemStats() async {
    return Map<String, dynamic>.from(_database['system_stats']);
  }

  // Get disease statistics
  Future<Map<String, dynamic>> getDiseaseStats(String diseaseKey) async {
    return Map<String, dynamic>.from(_database['diseases'][diseaseKey] ?? {});
  }

  // Get all diseases
  Future<Map<String, dynamic>> getAllDiseases() async {
    return Map<String, dynamic>.from(_database['diseases']);
  }

  // Add new disease to database
  Future<void> addDisease(String diseaseKey, Map<String, dynamic> diseaseData) async {
    _database['diseases'][diseaseKey] = diseaseData;
    await _saveDatabase();
  }

  // Update disease information
  Future<void> updateDisease(String diseaseKey, Map<String, dynamic> diseaseData) async {
    if (_database['diseases'][diseaseKey] != null) {
      _database['diseases'][diseaseKey].addAll(diseaseData);
      await _saveDatabase();
    }
  }

  // Get recent analyses
  Future<List<DiseaseAnalysisRecord>> getRecentAnalyses({int limit = 10}) async {
    final records = _database['analysis_records'] as List;
    return records
        .take(limit)
        .map((record) => DiseaseAnalysisRecord.fromJson(record))
        .toList();
  }

  // Search analyses by disease
  Future<List<DiseaseAnalysisRecord>> searchAnalysesByDisease(String diseaseName) async {
    final records = _database['analysis_records'] as List;
    return records
        .where((record) => record['detectedDisease'] == diseaseName)
        .map((record) => DiseaseAnalysisRecord.fromJson(record))
        .toList();
  }

  // Get analysis by ID
  Future<DiseaseAnalysisRecord?> getAnalysisById(String id) async {
    final records = _database['analysis_records'] as List;
    final record = records.firstWhere(
      (record) => record['id'] == id,
      orElse: () => null,
    );
    
    if (record != null) {
      return DiseaseAnalysisRecord.fromJson(record);
    }
    return null;
  }

  // Export database to JSON
  Future<String> exportDatabase() async {
    return json.encode(_database);
  }

  // Import database from JSON
  Future<void> importDatabase(String jsonData) async {
    _database = json.decode(jsonData);
    await _saveDatabase();
  }

  // Clear all data
  Future<void> clearAllData() async {
    _database = {
      "diseases": {},
      "analysis_records": [],
      "user_sessions": [],
      "system_stats": {
        "total_analyses": 0,
        "successful_detections": 0,
        "average_confidence": 0.0,
        "most_common_disease": null,
        "last_updated": null
      }
    };
    await _saveDatabase();
  }
} 