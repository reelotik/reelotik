import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class GroupMediaScreen extends StatefulWidget {
  final String groupId;

  const GroupMediaScreen({
    super.key,
    required this.groupId,
  });

  @override
  State<GroupMediaScreen> createState() =>
      _GroupMediaScreenState();
}

class _GroupMediaScreenState
    extends State<GroupMediaScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
      length: 4,
      vsync: this,
    );
  }

  Future<void> openFile(String url) async {
    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    }
  }

  Widget buildMediaList(String type) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("groups")
          .doc(widget.groupId)
          .collection("messages")
          .where("type", isEqualTo: type)
          .orderBy(
            "timestamp",
            descending: true,
          )
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return const Center(
            child: Text(
              "No Media Found",
              style: TextStyle(
                color: Colors.white54,
              ),
            ),
          );
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data =
                docs[index].data()
                    as Map<String, dynamic>;

            final url =
                data["fileUrl"] ?? "";

            final name =
                data["fileName"] ??
                "Unknown File";

            final sender =
                data["senderName"] ??
                "User";

            final Timestamp? ts =
                data["timestamp"];

            String time = "";

            if (ts != null) {
              time = DateFormat(
                "dd MMM yyyy",
              ).format(
                ts.toDate(),
              );
            }

            if (type == "image") {
              return Card(
                color:
                    const Color(0xff1f2937),
                margin:
                    const EdgeInsets.all(8),
                child: Column(
                  children: [
                    Image.network(
                      url,
                      height: 220,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                    ListTile(
                      title: Text(
                        sender,
                        style:
                            const TextStyle(
                          color:
                              Colors.white,
                        ),
                      ),
                      subtitle: Text(
                        time,
                        style:
                            const TextStyle(
                          color:
                              Colors.white54,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            IconData icon = Icons.insert_drive_file;

            if (type == "video") {
              icon = Icons.videocam;
            }

            if (type == "audio") {
              icon = Icons.mic;
            }

            if (type == "document") {
              icon = Icons.description;
            }

            return Card(
              color: const Color(0xff1f2937),
              margin:
                  const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              child: ListTile(
                leading: Icon(
                  icon,
                  color:
                      const Color(0xff25D366),
                ),
                title: Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                  ),
                ),
                subtitle: Text(
                  "$sender • $time",
                  style: const TextStyle(
                    color: Colors.white54,
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(
                    Icons.open_in_new,
                    color: Colors.white,
                  ),
                  onPressed: () =>
                      openFile(url),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xff0D1117),

      appBar: AppBar(
        backgroundColor:
            const Color(0xff111827),
        title:
            const Text("Group Media"),

        bottom: TabBar(
          controller: _tabController,
          indicatorColor:
              const Color(0xff25D366),
          labelColor:
              const Color(0xff25D366),
          unselectedLabelColor:
              Colors.white54,
          tabs: const [
            Tab(text: "Photos"),
            Tab(text: "Videos"),
            Tab(text: "Docs"),
            Tab(text: "Audio"),
          ],
        ),
      ),

      body: TabBarView(
        controller: _tabController,
        children: [
          buildMediaList("image"),
          buildMediaList("video"),
          buildMediaList("document"),
          buildMediaList("audio"),
        ],
      ),
    );
  }
}