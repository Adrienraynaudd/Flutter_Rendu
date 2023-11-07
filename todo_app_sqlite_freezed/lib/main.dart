import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:math' as math;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App ToDoList',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  final DatabaseHelper dbHelper = DatabaseHelper.instance;
  List<TaskItem> tasks = [];

  @override
  void initState() {
    super.initState();
    dbHelper.getAllTodos().then((todos) {
      setState(() {
        tasks = todos
            .map((todo) => TaskItem(
                id: todo.id, task: todo.task, isCompleted: todo.isCompleted))
            .toList();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('App ToDoList'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Tâches :',
              style: TextStyle(
                fontSize: 24.0,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  return Card(
                    elevation: 4,
                    margin: EdgeInsets.all(8.0),
                    child: CheckboxListTile(
                      value: tasks[index].isCompleted,
                      title: Text(
                        tasks[index].task,
                        style: TextStyle(
                          fontSize: 18.0,
                          color: tasks[index].isCompleted
                              ? Colors.grey
                              : Colors.black,
                          fontWeight: tasks[index].isCompleted
                              ? FontWeight.normal
                              : FontWeight.bold,
                        ),
                      ),
                      onChanged: (bool? value) {
                        setState(() {
                          tasks[index].isCompleted = value ?? false;
                          dbHelper.update(Todo(
                            id: tasks[index].id,
                            task: tasks[index].task,
                            isCompleted: tasks[index].isCompleted,
                          ));
                        });
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(left: 20.0),
            child: FloatingActionButton(
              onPressed: () async {
                final completedTasks =
                    tasks.where((task) => task.isCompleted).toList();
                for (final task in completedTasks) {
                  await dbHelper.delete(task.id!);
                }
                setState(() {
                  tasks.removeWhere((task) => task.isCompleted);
                });
              },
              tooltip: 'Supprimer les tâches terminées',
              child: Icon(Icons.delete),
              backgroundColor: Colors.deepPurple,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 20.0),
            child: FloatingActionButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    final TextEditingController taskController =
                        TextEditingController();
                    final AnimationController animationController =
                        AnimationController(
                      vsync: this,
                      duration: const Duration(seconds: 1),
                    );

                    final CurvedAnimation curve = CurvedAnimation(
                      parent: animationController,
                      curve: Curves.easeInOut,
                    );

                    animationController.forward();

                    return AnimatedBuilder(
                      animation: curve,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0.0, 400 * (1 - curve.value)),
                          child: Transform.rotate(
                            angle: math.pi * (1 - curve.value),
                            alignment: Alignment.center,
                            child: child,
                          ),
                        );
                      },
                      child: Dialog(
                        child: Container(
                          height: 200,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Text('Ajouter une Tâche'),
                              TextField(
                                controller: taskController,
                                decoration: InputDecoration(
                                    labelText: 'Nom de la Tâche'),
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: <Widget>[
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    child: Text('Annuler'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () async {
                                      final newTask = taskController.text;
                                      if (newTask.isNotEmpty) {
                                        final taskItem = TaskItem(
                                            task: newTask, isCompleted: false);
                                        final id = await dbHelper.insert(Todo(
                                          task: taskItem.task,
                                          isCompleted: taskItem.isCompleted,
                                        ));
                                        taskItem.id = id;
                                        setState(() {
                                          tasks.add(taskItem);
                                        });
                                        taskController.clear();
                                      }
                                      Navigator.of(context).pop();
                                    },
                                    child: Text('Ajouter'),
                                    style: ElevatedButton.styleFrom(
                                      primary: Colors.deepPurple,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              tooltip: 'Add a Task',
              child: Icon(Icons.add),
              backgroundColor: Colors.deepPurple,
            ),
          ),
        ],
      ),
    );
  }
}

class TaskItem {
  int? id;
  final String task;
  bool isCompleted;

  TaskItem({this.id, required this.task, required this.isCompleted});
}

class DatabaseHelper {
  final _dbName = 'todoApp.db';
  final _dbVersion = 1;
  final _tableName = 'todos';

  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  _initDatabase() async {
    String path = join(await getDatabasesPath(), _dbName);
    return await openDatabase(path, version: _dbVersion, onCreate: _onCreate);
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
    CREATE TABLE $_tableName (
      id INTEGER PRIMARY KEY,
      task TEXT NOT NULL,
      isCompleted INTEGER NOT NULL
    )
  ''');
  }

  // Insert a new task
  Future<int> insert(Todo todo) async {
    Database db = await instance.database;
    return await db.insert(_tableName, todo.toJson());
  }

  // Get all tasks
  Future<List<Todo>> getAllTodos() async {
    Database db = await instance.database;
    var todos = await db.query(_tableName);
    return todos.map((e) => Todo.fromJson(e)).toList();
  }

  // Update a task
  Future<int> update(Todo todo) async {
    Database db = await instance.database;
    return await db.update(_tableName, todo.toJson(),
        where: 'id = ?', whereArgs: [todo.id]);
  }

  // Delete a task
  Future<int> delete(int id) async {
    Database db = await instance.database;
    return await db.delete(_tableName, where: 'id = ?', whereArgs: [id]);
  }
}

class Todo {
  int? id;
  final String task;
  bool isCompleted;

  Todo({this.id, required this.task, required this.isCompleted});

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'task': task,
      'isCompleted': isCompleted ? 1 : 0,
    };
  }

  factory Todo.fromJson(Map<String, dynamic> json) {
    return Todo(
      id: json['id'],
      task: json['task'],
      isCompleted: json['isCompleted'] == 1,
    );
  }
}
