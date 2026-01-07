import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:timeline_flutter/screens/tasks.dart';

class WorkflowsPage extends StatefulWidget {
  final String uid;

  const WorkflowsPage({super.key, required this.uid});

  @override
  State<WorkflowsPage> createState() => _WorkflowsPageState();
}

class _WorkflowsPageState extends State<WorkflowsPage> {
  @override
  Widget build(BuildContext context) {
    final workflowsQuery = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .collection('workflows')
        .orderBy('created_at', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: workflowsQuery.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          print(snapshot.error);
          return Text('Something went wrong: ${snapshot.error}');
        }
        if (!snapshot.hasData) return const CircularProgressIndicator();

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Text('No workflows created yet');

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            return ListTile(
              title: Text(
                'Unnamed Workflow ${index + 1}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              subtitle: Text(
                data['query'],
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => _pauseWorkflow(data['workflow_id']),
                    icon: const Icon(Icons.pause, color: Colors.white),
                  ),
                  const SizedBox(width: 15),
                  IconButton(
                    onPressed: () => _deleteWorkflow(data['workflow_id']),
                    icon: const Icon(Icons.delete, color: Colors.white),
                  ),
                ],
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      TasksPage(uid: widget.uid, workflowId: docs[index].id),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _pauseWorkflow(String workflowId) async {
    final url = "http://127.0.0.1:8000/workflows/${workflowId}/pause";
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

    try {
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );
      print("Response status: ${response.statusCode}");
      if (response.statusCode >= 200 && response.statusCode < 300) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Paused successfully')));
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

  void _deleteWorkflow(String workflowId) async {
    final url = "http://127.0.0.1:8000/workflows/${workflowId}/delete";
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

    try {
      final response = await http.delete(
        uri,
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );
      print("Response status: ${response.statusCode}");
      if (response.statusCode >= 200 && response.statusCode < 300) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Deleted successfully')));
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
