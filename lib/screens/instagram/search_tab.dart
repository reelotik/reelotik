import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SearchTab extends StatefulWidget {
  const SearchTab({super.key});

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  String searchText = '';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: const InputDecoration(
              hintText: "Search users...",
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                searchText = value.toLowerCase();
              });
            },
          ),
        ),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              final users = snapshot.data!.docs.where((doc) {
                final data =
                    doc.data() as Map<String, dynamic>;

                final name =
                    (data['name'] ?? '')
                        .toString()
                        .toLowerCase();

                return name.contains(searchText);
              }).toList();

              return ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final data =
                      users[index].data()
                          as Map<String, dynamic>;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage:
                          data['profileImage'] != null &&
                                  data['profileImage'] != ''
                              ? NetworkImage(
                                  data['profileImage'])
                              : null,
                      child: data['profileImage'] == ''
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    title: Text(data['name'] ?? ''),
                    subtitle: Text(data['bio'] ?? ''),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}