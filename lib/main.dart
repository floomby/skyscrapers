import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    HomePage homePage = const HomePage();

    return MaterialApp(
      title: 'Skyscrapers',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: homePage,
    );
  }
}

void saveCompletionStatus(int puzzleIndex, bool status) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('completed_$puzzleIndex', status);
}

Future<bool> loadCompletionStatus(int puzzleIndex) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('completed_$puzzleIndex') ?? false;
}

class Puzzle {
  final List<int> top;
  final List<int> bottom;
  final List<int> left;
  final List<int> right;

  Puzzle({
    required this.top,
    required this.bottom,
    required this.left,
    required this.right,
  });

  factory Puzzle.fromJson(Map<String, dynamic> json) {
    return Puzzle(
      top: List<int>.from(json['top']),
      bottom: List<int>.from(json['bottom']),
      left: List<int>.from(json['left']),
      right: List<int>.from(json['right']),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<Puzzle>> puzzlesFuture;
  final Set<int> _completedPuzzles = {};

  @override
  void initState() {
    super.initState();
    puzzlesFuture = fetchPuzzles();
  }

  Future<List<Puzzle>> fetchPuzzles() async {
    String puzzlesJson = await rootBundle.loadString('assets/puzzles.json');
    List<dynamic> puzzlesList = jsonDecode(puzzlesJson);

    List<Puzzle> ret =
        puzzlesList.map((puzzleMap) => Puzzle.fromJson(puzzleMap)).toList();

    for (int i = 0; i < ret.length; i++) {
      if (await loadCompletionStatus(i)) _completedPuzzles.add(i);
    }

    return ret;
  }

  void markPuzzleAsComplete(int index) {
    setState(() {
      _completedPuzzles.add(index);
    });
    saveCompletionStatus(index, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select a Puzzle'),
      ),
      body: FutureBuilder<List<Puzzle>>(
        future: fetchPuzzles(),
        builder: (BuildContext context, AsyncSnapshot<List<Puzzle>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Text('Error: ${snapshot.error}');
          } else {
            return Column(
              children: [
                ElevatedButton(
                  onPressed: () {
                    // find the first unsolved puzzle
                    int firstUnsolvedPuzzleIndex = -1;
                    for (int i = 0; i < snapshot.data!.length; i++) {
                      if (!_completedPuzzles.contains(i)) {
                        firstUnsolvedPuzzleIndex = i;
                        break;
                      }
                    }

                    if (firstUnsolvedPuzzleIndex != -1) {
                      // if there is an unsolved puzzle
                      final puzzle = snapshot.data![firstUnsolvedPuzzleIndex];

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => GamePage(
                            puzzle: puzzle,
                            puzzleIndex: firstUnsolvedPuzzleIndex,
                            onComplete: () {
                              markPuzzleAsComplete(firstUnsolvedPuzzleIndex);
                            },
                          ),
                        ),
                      );
                    } else {
                      // if all puzzles are solved
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('All puzzles solved!'),
                          content: const Text(
                              'You have solved all the puzzles. Congratulations!'),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                  child: const Text('Play First Unsolved'),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      final puzzle = snapshot.data![index];
                      return ListTile(
                        title: Text(
                            'Puzzle ${index + 1}${_completedPuzzles.contains(index) ? ' (Completed)' : ''}'),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => GamePage(
                                puzzle: puzzle,
                                puzzleIndex: index,
                                onComplete: () {
                                  markPuzzleAsComplete(index);
                                },
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          }
        },
      ),
    );
  }
}

class GamePage extends StatefulWidget {
  final Puzzle puzzle;
  final int puzzleIndex;
  final VoidCallback onComplete;

  const GamePage(
      {Key? key,
      required this.puzzle,
      required this.puzzleIndex,
      required this.onComplete})
      : super(key: key);

  String get title => 'Puzzle ${puzzleIndex + 1}';

  @override
  State<GamePage> createState() => _GamePageState();
}

enum ValidationState {
  valid,
  invalid,
  unchecked,
}

class _GamePageState extends State<GamePage> {
  @override
  void initState() {
    super.initState();
  }

  int _selectedNumber = 0;
  final List<List<int>> _grid =
      List.generate(4, (i) => List.generate(4, (j) => 0));

  final List<bool> _rowsValid = List.generate(4, (i) => true);
  final List<bool> _columnsValid = List.generate(4, (i) => true);

  bool _completed = false;

  void _selectNumber(int number) {
    setState(() {
      _selectedNumber = number;
    });
  }

  // update the validity of the rows and columns (duplicate numbers render them
  // invalid)
  void _validate() {
    for (int i = 0; i < 4; i++) {
      final Set<int> rowSet = {};
      final Set<int> columnSet = {};
      final List<int> row = _grid[i];
      final List<int> column = List.generate(4, (j) => _grid[j][i]);
      bool rowValid = true;
      bool columnValid = true;
      for (int i = 0; i < 4; i++) {
        if (row[i] != 0) {
          if (rowSet.contains(row[i])) {
            rowValid = false;
            break;
          } else {
            rowSet.add(row[i]);
          }
        }
      }
      for (int i = 0; i < 4; i++) {
        if (column[i] != 0) {
          if (columnSet.contains(column[i])) {
            columnValid = false;
            break;
          } else {
            columnSet.add(column[i]);
          }
        }
      }
      setState(() {
        _rowsValid[i] = rowValid;
        _columnsValid[i] = columnValid;
      });
    }

    // if everything is non-zero and valid, then the game is completed
    setState(() {
      _completed = _grid.every((row) => row.every((cell) => cell != 0)) &&
          _rowsValid.every((valid) => valid) &&
          _columnsValid.every((valid) => valid);

      if (_completed) {
        Future.delayed(Duration.zero, () {
          // mark the puzzle as completed
          widget.onComplete();
          showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: const Text('Congratulations!'),
                content: const Text('You have completed the puzzle.'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    child: const Text('Return to Selection Page'),
                  ),
                ],
              );
            },
          );
        });
      }
    });
  }

  int _getClue(int index) {
    if (index > 0 && index < 5) {
      return widget.puzzle.top[index - 1];
    } else if (index > 30 && index < 35) {
      return widget.puzzle.bottom[index - 31];
    } else if (index % 6 == 0 && index > 5 && index < 30) {
      return widget.puzzle.left[index ~/ 6 - 1];
    } else if (index % 6 == 5 && index > 5 && index < 30) {
      return widget.puzzle.right[index ~/ 6 - 1];
    } else {
      return 0;
    }
  }

  bool _validateVisibility(List<int> data, int count) {
    int currentHeight = 0;
    int visibleCount = 0;
    for (int i = 0; i < 4; i++) {
      if (data[i] > currentHeight) {
        currentHeight = data[i];
        visibleCount++;
      }
    }
    return visibleCount == count;
  }

  bool _validateVisibilityTop(int index) {
    return _validateVisibility(
        List.generate(4, (i) => _grid[i][index]), widget.puzzle.top[index]);
  }

  bool _validateVisibilityBottom(int index) {
    return _validateVisibility(List.generate(4, (i) => _grid[3 - i][index]),
        widget.puzzle.bottom[index]);
  }

  bool _validateVisibilityLeft(int index) {
    return _validateVisibility(_grid[index], widget.puzzle.left[index]);
  }

  bool _validateVisibilityRight(int index) {
    return _validateVisibility(List.generate(4, (i) => _grid[index][3 - i]),
        widget.puzzle.right[index]);
  }

  ValidationState _validateVisibilityFromIndex(int index) {
    if (index > 0 && index < 5) {
      return _validateVisibilityTop(index - 1)
          ? ValidationState.valid
          : ValidationState.invalid;
    } else if (index > 30 && index < 35) {
      return _validateVisibilityBottom(index - 31)
          ? ValidationState.valid
          : ValidationState.invalid;
    } else if (index % 6 == 0 && index > 5 && index < 30) {
      return _validateVisibilityLeft(index ~/ 6 - 1)
          ? ValidationState.valid
          : ValidationState.invalid;
    } else if (index % 6 == 5 && index > 5 && index < 30) {
      return _validateVisibilityRight(index ~/ 6 - 1)
          ? ValidationState.valid
          : ValidationState.invalid;
    } else {
      return ValidationState.unchecked;
    }
  }

  @override
  Widget build(BuildContext context) {
    _validate();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(
        children: <Widget>[
          GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
            ),
            itemCount: 36,
            itemBuilder: (BuildContext context, int index) {
              return GestureDetector(
                onTap: () {
                  // check if the index puts us on the border of the 6x6 grid
                  if (index % 6 == 0 ||
                      index % 6 == 5 ||
                      index < 6 ||
                      index > 29) {
                    return;
                  }
                  setState(() {
                    _grid[index ~/ 6 - 1][index % 6 - 1] = _selectedNumber;
                  });
                  _validate();
                },
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blueAccent),
                    color: _completed
                        ? Colors.green
                        : ((index % 6 != 0 &&
                                    index % 6 != 5 &&
                                    index >= 6 &&
                                    index <= 29) &&
                                (!_rowsValid[index ~/ 6 - 1] ||
                                    !_columnsValid[index % 6 - 1]))
                            ? Colors.red
                            : _validateVisibilityFromIndex(index) ==
                                    ValidationState.invalid
                                ? Colors.red
                                : _validateVisibilityFromIndex(index) ==
                                        ValidationState.valid
                                    ? Colors.green
                                    : Colors.white,
                  ),
                  child: Center(
                    child: Text(
                      (index % 6 == 0 ||
                              index % 6 == 5 ||
                              index < 6 ||
                              index > 29)
                          ? _getClue(index) == 0
                              ? ''
                              : _getClue(index).toString()
                          : _grid[index ~/ 6 - 1][index % 6 - 1] == 0
                              ? ''
                              : _grid[index ~/ 6 - 1][index % 6 - 1].toString(),
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
              );
            },
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                for (int i = 0; i <= 4; i++)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      // set the background color if the button is selected
                      backgroundColor:
                          _selectedNumber == i ? Colors.blue : null,
                      shape: i == 0
                          ? const RoundedRectangleBorder(
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(16),
                                bottomLeft: Radius.circular(16),
                                topRight: Radius.zero,
                                bottomRight: Radius.zero,
                              ),
                            )
                          : i == 4
                              ? const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.only(
                                    topRight: Radius.circular(16),
                                    bottomRight: Radius.circular(16),
                                    topLeft: Radius.zero,
                                    bottomLeft: Radius.zero,
                                  ),
                                )
                              : const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.zero,
                                ),
                    ),
                    onPressed: () => _selectNumber(i),
                    child: Text(
                      i == 0 ? '✖' : i.toString(),
                      style: const TextStyle(fontSize: 26),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
