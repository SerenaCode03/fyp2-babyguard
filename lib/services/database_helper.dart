import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDB("babyguard.db");
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,   // <--- TABLES DEFINED HERE
    );
  }

  Future _createDB(Database db, int version) async {
    // USERS TABLE
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT NOT NULL UNIQUE,
        username TEXT NOT NULL,
        passwordHash TEXT NOT NULL,
        securityQuestion TEXT NOT NULL,
        securityAnswerHash TEXT NOT NULL,
        createdAt TEXT NOT NULL
      );
    ''');

    // REPORTS TABLE
    await db.execute('''
      CREATE TABLE reports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER NOT NULL,
        timestamp TEXT NOT NULL,

        riskLevel TEXT NOT NULL,          -- High/Moderate/Low risk alert     

        alertTitle TEXT NOT NULL,
        alertMessage TEXT NOT NULL,

        snapshotPath TEXT,                -- hero image on top                  

        poseLabel TEXT,                   
        poseConfidence REAL,              
        expressionLabel TEXT,             
        expressionConfidence REAL,        
        cryLabel TEXT,                    
        cryConfidence REAL,

        reportLatencyMs INTEGER,               

        FOREIGN KEY (userId) REFERENCES users(id)
      );
    ''');

    await db.execute('''
      CREATE TABLE report_xai_insights (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        reportId INTEGER NOT NULL,   
        imagePath TEXT NOT NULL,
        title TEXT NOT NULL,            -- such as Distressed face
        description TEXT NOT NULL,      -- summary text for the GradCAM
        FOREIGN KEY (reportId) REFERENCES reports(id)
      );
    ''');

    await db.execute('''
      CREATE TABLE notifications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER NOT NULL,            
        timestamp TEXT NOT NULL,               
        category TEXT NOT NULL,           -- modality: pose, cry, posture for icon arrangement
        title TEXT NOT NULL,              -- alert text such as Distressed cry detected                                  
        FOREIGN KEY (userId) REFERENCES users(id)
      );
    ''');
  }
}
