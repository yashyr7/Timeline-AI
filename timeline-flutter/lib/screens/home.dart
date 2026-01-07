import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:timeline_flutter/screens/workflows.dart';
import 'package:timeline_flutter/services/auth_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomepageState();
}

class _HomepageState extends State<HomePage> {
  late TextEditingController _inputController;
  late TextEditingController _datetimeController;
  DateTime? selectedDate;
  Duration? _selectedPeriod;

  int _selectedIndex = 0;

  final List<Map<String, dynamic>> _periodOptions = [
    {'label': '30 min', 'duration': const Duration(minutes: 30)},
    {'label': '1 hour', 'duration': const Duration(hours: 1)},
    {'label': '6 hours', 'duration': const Duration(hours: 6)},
    {'label': '12 hours', 'duration': const Duration(hours: 12)},
    {'label': '1 day', 'duration': const Duration(days: 1)},
    {'label': '1 week', 'duration': const Duration(days: 7)},
    {'label': '2 weeks', 'duration': const Duration(days: 14)},
    {'label': '1 month', 'duration': const Duration(days: 30)},
  ];

  final months = [
    "",
    "January",
    "February",
    "March",
    "April",
    "May",
    "June",
    "July",
    "August",
    "September",
    "October",
    "November",
    "December",
  ];

  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController();
    _datetimeController = TextEditingController();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _datetimeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Timeline")),
      body: SafeArea(
        child: _selectedIndex == 0
            ? _buildHomeScreen()
            : _buildWorkflowsScreen(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.timeline), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.work_outline),
            label: 'Workflows',
          ),
        ],
      ),
    );
  }

  Widget _buildHomeScreen() {
    return SingleChildScrollView(
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Stay Updated on",
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.start,
              ),
              const SizedBox(height: 20),
              _searchField(),
              SizedBox(height: 20),
              Text(
                "starting from",
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              _dateTimeField(),
              SizedBox(height: 20),
              selectedDate != null ? _renderSelcectedDate() : Container(),
              SizedBox(height: 20),
              Text("every", style: Theme.of(context).textTheme.headlineMedium),
              SizedBox(height: 20),
              _periodSelector(),
              SizedBox(height: 20),
              TextButton(
                onPressed: _submitQueryTask,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "Submit",
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  AuthService(FirebaseAuth.instance).logout();
                },
                child: Text("Sign out"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkflowsScreen() {
    return WorkflowsPage(uid: FirebaseAuth.instance.currentUser!.uid);
  }

  Widget _searchField() {
    return TextField(
      maxLines: null,
      controller: _inputController,
      decoration: InputDecoration(
        hintText: "Enter the topic",
        hintStyle: const TextStyle(color: Colors.black54),
        filled: true,
        fillColor: const Color(0xFFD9D9D9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
      ),
      style: Theme.of(context).textTheme.labelLarge,
      cursorColor: Colors.white,
    );
  }

  Widget _dateTimeField() {
    return TextField(
      maxLines: null,
      readOnly: true,
      controller: _datetimeController,
      decoration: InputDecoration(
        hintText: "Enter Date and Time",
        hintStyle: const TextStyle(color: Colors.black54),
        filled: true,
        fillColor: const Color(0xFFD9D9D9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
      ),
      style: Theme.of(context).textTheme.labelLarge,
      onTap: _pickDateTime,
    );
  }

  Widget _renderSelcectedDate() {
    int hour = selectedDate!.hour;
    String period = hour >= 12 ? "PM" : "AM";
    hour = hour % 12 == 0 ? 12 : hour % 12;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "${selectedDate!.day} ${months[selectedDate!.month]}, ${selectedDate!.year}",
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        SizedBox(height: 20),
        Text(
          "at ${hour}:${selectedDate!.minute} $period",
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ],
    );
  }

  // Period selector using ChoiceChips
  Widget _periodSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _periodOptions.map((opt) {
        final label = opt['label'] as String;
        final dur = opt['duration'] as Duration;
        final selected = _selectedPeriod == dur;
        return ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) {
            setState(() {
              _selectedPeriod = dur;
            });
          },
          backgroundColor: const Color(0xFFD9D9D9),
          selectedColor: Colors.orange,
          labelStyle: TextStyle(
            color: selected ? Colors.black87 : Colors.black54,
            fontWeight: FontWeight.w600,
          ),
        );
      }).toList(),
    );
  }

  _pickDateTime() async {
    DateTime? date = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (date != null) {
      TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (time != null) {
        final DateTime dateTime = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
        setState(() {
          selectedDate = dateTime;
        });
        //_datetimeController.text = dateTime.toString();
      }
    }
  }

  _submitQueryTask() async {
    // Function to handle the submission of the query
    const url = "http://127.0.0.1:8000/workflows/add";
    final uri = Uri.parse(url);
    print("Sending request to $url");
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User not authenticated')));
      return;
    }

    final idToken = await user.getIdToken();

    final payload = {
      'owner_id': user.uid,
      'name': '',
      'query': _inputController.text,
      'start_time_utc': selectedDate!.toUtc().toString(),
      'interval_seconds': _selectedPeriod!.inSeconds,
      // 'interval_seconds': '60',
      'active': true,
    };
    print(payload);
    try {
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );
      print("Response status: ${response.statusCode}");
      print("Response body: ${response.body}");
      if (response.statusCode >= 200 && response.statusCode < 300) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Scheduled successfully')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${response.statusCode}')),
        );
      }
    } catch (e) {
      print("Error: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Network error')));
    }
  }
}
