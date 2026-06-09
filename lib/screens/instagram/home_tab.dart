import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
            ),
          );
        }

        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final posts = snapshot.data?.docs ?? [];

        // Debug
        print("Posts Count: ${posts.length}");

        for (var post in posts) {
          print(post.data());
        }

        if (posts.isEmpty) {
          return const Center(
            child: Text("No Posts Yet"),
          );
        }

        return ListView.builder(
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final data =
                posts[index].data()
                    as Map<String, dynamic>;

            return Card(
              margin: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  ListTile(
                    leading: CircleAvatar(
                      backgroundImage:
                          data['profileImage'] != null &&
                                  data['profileImage']
                                      .toString()
                                      .isNotEmpty
                              ? NetworkImage(
                                  data['profileImage'],
                                )
                              : null,
                      child:
                          data['profileImage'] == null ||
                                  data['profileImage']
                                      .toString()
                                      .isEmpty
                              ? const Icon(Icons.person)
                              : null,
                    ),
                    title: Text(
                      data['userName'] ?? 'User',
                    ),
                  ),

                  if (data['imageUrl'] != null)
                    Image.network(
                      data['imageUrl'],
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),

                  const Padding(
                    padding: EdgeInsets.all(10),
                    child: Row(
                      children: [
                        Icon(Icons.favorite_border),
                        SizedBox(width: 15),
                        Icon(Icons.comment_outlined),
                        SizedBox(width: 15),
                        Icon(Icons.share),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}