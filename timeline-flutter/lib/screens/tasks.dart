import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TasksPage extends StatelessWidget {
  final String uid;
  final String workflowId;

  const TasksPage({super.key, required this.uid, required this.workflowId});

  @override
  Widget build(BuildContext context) {
    print(uid);
    final tasksQuery = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('workflows')
        .doc(workflowId)
        .collection('tasks')
        .orderBy('created_at', descending: true);

    return Scaffold(
      appBar: AppBar(title: const Text('Tasks')),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: tasksQuery.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              print(snapshot.error);
              return Text('Something went wrong: ${snapshot.error}');
            }
            if (!snapshot.hasData) return const CircularProgressIndicator();

            final docs = snapshot.data!.docs;
            if (docs.isEmpty) return const Text('No task runs created yet');

            return ListView.builder(
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                return ListTile(
                  title: Text(
                    data['status'] == 'COMPLETED'
                        ? data['result']
                        : 'Task in progress...',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  subtitle: Text(
                    data['status'],
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
