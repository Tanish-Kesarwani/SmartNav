import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'room_graph.dart';

const List<String> floors= <String>['Ground Floor','1st Floor','2nd Floor','3rd Floor'];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final roomGraph = RoomGraph();
  await roomGraph.initDatabaseAndInsertData();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Flutter Demo',
      home: MyHomePage(),
    );
  }
}

class DropdownButtonApp extends StatelessWidget {
  const DropdownButtonApp({super.key});

  @override
  Widget build(BuildContext context){
    return const DropdownButtonX();
  }

}

class DropdownButtonX extends StatefulWidget{
  const DropdownButtonX({super.key});

  @override
  State<DropdownButtonX> createState()=> DropdownButtonXState();
}

class DropdownButtonXState extends State<DropdownButtonX>{
  String dropdownValue = floors.first;

  @override
  Widget build(BuildContext context){
    return DropdownButton (
      value: dropdownValue,
      icon: const Icon(Icons.arrow_downward),
      elevation:16,
      style: const TextStyle(color: Colors.deepPurple),
      underline: Container(
        height: 2,
        color: Colors.deepPurpleAccent,
      ),
      onChanged: (String? value){
        setState(() {
          dropdownValue = value!;
        });
      },
      items: floors.map<DropdownMenuItem<String>>((String value){
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  String _lastWords = '';
  bool _listening = false;
  bool _searchButtonEnabled = false;

  final RoomGraph roomGraph = RoomGraph();
  final TextEditingController startController = TextEditingController();
  final TextEditingController endController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    if (_speechEnabled) {
      _startListening();
    }
  }

  void _startListening() async {
    setState(() {
      _listening = true;
    });

    while (_listening) {
      await _speechToText.listen(
        onResult: _onSpeechResult,
      );

      if (!_listening) {
        break;
      }
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      _lastWords = result.recognizedWords;
      _updateTextFields(result.recognizedWords);

      if (_lastWords.toLowerCase().contains('search')) {
        _stopListening();
        _enableSearchButton();
        _performSearch();
      }
    });
  }

  void _updateTextFields(String recognizedWords) {
    final RegExp regExp = RegExp(r'\d+');
    final List<String> numbers =
    regExp.allMatches(recognizedWords).map((match) => match.group(0)!).toList();

    if (numbers.isNotEmpty) {
      final int parsedNumber = int.parse(numbers.first);

      if (parsedNumber >= 1 && parsedNumber <= 5) {
        if (startController.text.isEmpty) {
          startController.text = parsedNumber.toString();
        } else {
          endController.text = parsedNumber.toString();
        }
      }
    }
  }

  void _enableSearchButton() {
    setState(() {
      _searchButtonEnabled = true;
    });
  }

  void _stopListening() {
    setState(() {
      _listening = false;
    });
    _speechToText.stop();
  }

  void _performSearch() async {
    if (startController.text.isEmpty || endController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both start and end room numbers.'),
        ),
      );
      return;
    }

    final startRoom = int.parse(startController.text);
    final endRoom = int.parse(endController.text);

    final rooms = await roomGraph.gAR();
    final graph = Graph(rooms);
    graph.addEdge(1, 2);
    graph.addEdge(2, 3);
    graph.addEdge(3, 5);
    graph.addEdge(3, 4);
    graph.addEdge(4, 5);

    final shortestRoute = graph.shortestRoute(startRoom, endRoom);
    final shortestDistances = graph.shortestDistancesFrom(startRoom);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Results'),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Shortest route from Room $startRoom to Room $endRoom: $shortestRoute'),
              Text('Shortest distances from Room $startRoom: $shortestDistances'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Close', style: TextStyle(color: Colors.blue)),
            ),
          ],
        );
      },
    );
  }

  void _performSearchOrShowResult() async {
    if (_searchButtonEnabled=true ) {
      _stopListening();
      _enableSearchButton();
      _performSearch();

    }
    else if(_lastWords.toLowerCase().contains('search')) {
      _stopListening();
      _enableSearchButton();
      _performSearch();
    }
    else{
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please use the voice command "search" or enable the button.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SmartNav'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Recognized words: $_lastWords',
                style: const TextStyle(fontSize: 20.0),
              ),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _listening ? 'Listening...' : 'Not Listening',
                ),
              ),
            ),
            const DropdownButtonApp(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: ListTile(
                      title: TextField(
                        controller: startController,
                        decoration: const InputDecoration(
                          labelText: 'Start room number',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.location_on, color: Colors.blue),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: ListTile(
                      title: TextField(
                        controller: endController,
                        decoration: const InputDecoration(
                          labelText: 'End room number',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.location_on, color: Colors.blue),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ),
                  const SizedBox(height: 270),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.search),
                    label: const Text('Search'),
                    onPressed: _performSearchOrShowResult,
                  ),
                  ElevatedButton(onPressed: (){
                    Navigator.push(
                      context ,
                      MaterialPageRoute(builder: (context)=> LoginPage()),
                    );
                  }, child: const Text('Register Map'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LoginPage extends StatelessWidget {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login Page'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            TextFormField(
              controller: usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
              ),
            ),
            TextFormField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
              ),
              obscureText: true,
            ),
            ElevatedButton(
              onPressed: () {
                // Handle login logic here
              },
              child: const Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}
