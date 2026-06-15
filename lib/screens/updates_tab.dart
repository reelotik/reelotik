import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';

import '../models/status_model.dart';
import '../services/status_service.dart';

// Helper for formatting times
String _formatTime(Timestamp? timestamp) {
  if (timestamp == null) return "Just now";
  final now = DateTime.now();
  final date = timestamp.toDate();
  final diff = now.difference(date);
  if (diff.inMinutes < 1) return "Just now";
  if (diff.inMinutes < 60) return "${diff.inMinutes} min ago";
  if (diff.inHours < 24) return "${diff.inHours} hours ago";
  return "Yesterday";
}

class UpdatesTab extends StatefulWidget {
  const UpdatesTab({super.key});
  @override
  State<UpdatesTab> createState() => _UpdatesTabState();
}

class _UpdatesTabState extends State<UpdatesTab> {
  final ImagePicker _picker = ImagePicker();
  final String myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

  Future<void> _pickStatus(ImageSource source) async {
    XFile? pickedFile;
    if (source == ImageSource.camera) {
      pickedFile = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    } else {
      pickedFile = await _picker.pickMedia(imageQuality: 80);
    }

    if (pickedFile == null) return;

    // NEW: Open Caption & Privacy Screen before uploading
    Navigator.push(context, MaterialPageRoute(builder: (_) => CaptionAndPrivacyScreen(
      file: File(pickedFile!.path),
      mediaType: pickedFile.path.toLowerCase().endsWith(".mp4") ? "video" : "image",
    )));
  }

  void _viewStatus(List<StatusModel> statuses) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => StatusViewerScreen(statuses: statuses)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0D1117),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
        children: [
          _buildMyStatusSection(),
          const SizedBox(height: 10),
          _buildOthersStatusesSection(),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "edit_status",
            mini: true,
            backgroundColor: const Color(0xff1f2937),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TextStatusScreen())), 
            child: const Icon(Icons.edit, color: Colors.white70),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: "camera_status",
            backgroundColor: const Color(0xff25D366),
            onPressed: () => _pickStatus(ImageSource.camera),
            child: const Icon(Icons.camera_alt, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildMyStatusSection() {
    return StreamBuilder<List<StatusModel>>(
      stream: StatusService.getMyStatuses(),
      builder: (context, snapshot) {
        final myStatuses = snapshot.data ?? [];
        final hasStatus = myStatuses.isNotEmpty;
        final latestStatus = hasStatus ? myStatuses.first : null;

        return ListTile(
          leading: Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: hasStatus ? const Color(0xff25D366) : Colors.transparent, width: 2.5)),
                child: CircleAvatar(
                  radius: 25, backgroundColor: Colors.grey.shade800,
                  child: hasStatus 
                      ? (latestStatus!.mediaType == "text" 
                          ? Container(decoration: BoxDecoration(shape: BoxShape.circle, color: Color(int.parse(latestStatus.mediaUrl))), alignment: Alignment.center, child: Text(latestStatus.caption.isNotEmpty ? latestStatus.caption[0] : "T", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))
                          : ClipOval(child: CachedNetworkImage(imageUrl: latestStatus.mediaUrl, width: 50, height: 50, fit: BoxFit.cover, errorWidget: (_, __, ___) => const Icon(Icons.person, color: Colors.white))))
                      : const Icon(Icons.person, color: Colors.white, size: 30),
                ),
              ),
              Positioned(bottom: 0, right: 0, child: GestureDetector(onTap: () => _pickStatus(ImageSource.gallery), child: Container(decoration: const BoxDecoration(color: Color(0xff25D366), shape: BoxShape.circle), child: const Icon(Icons.add, size: 20, color: Colors.white)))),
            ],
          ),
          title: const Text("My Status", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          subtitle: Text(hasStatus ? _formatTime(latestStatus!.timestamp) : "Tap to add status update", style: const TextStyle(color: Colors.white54)),
          onTap: () {
            if (hasStatus) {
              _viewStatus(myStatuses.reversed.toList());
            } else {
              _pickStatus(ImageSource.gallery);
            }
          },
        );
      },
    );
  }

  Widget _buildOthersStatusesSection() {
    return StreamBuilder<List<StatusModel>>(
      stream: StatusService.getStatuses(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Color(0xff25D366))));
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const Padding(padding: EdgeInsets.only(left: 15, top: 10), child: Text("No recent updates", style: TextStyle(color: Colors.white54)));

        final groupedStatuses = StatusService.groupStatusesByUser(snapshot.data!);
        List<Widget> recentTiles = [];
        List<Widget> viewedTiles = [];

        groupedStatuses.forEach((uid, userStatuses) {
          if (uid == myUid) return; 
          bool isAllViewed = userStatuses.every((s) => s.viewers.contains(myUid));
          final tile = _buildRealStatusTile(userStatuses, isAllViewed);
          if (isAllViewed) {
            viewedTiles.add(tile);
          } else {
            recentTiles.add(tile);
          }
        });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (recentTiles.isNotEmpty) ...[const Padding(padding: EdgeInsets.only(left: 15, top: 10, bottom: 5), child: Text("Recent updates", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13))), ...recentTiles],
            if (viewedTiles.isNotEmpty) ...[const Padding(padding: EdgeInsets.only(left: 15, top: 20, bottom: 5), child: Text("Viewed updates", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13))), ...viewedTiles],
          ],
        );
      },
    );
  }

  Widget _buildRealStatusTile(List<StatusModel> userStatuses, bool isAllViewed) {
    final status = userStatuses.last; 
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: isAllViewed ? Colors.grey : const Color(0xff25D366), width: 2.5)),
        child: CircleAvatar(
          radius: 22, backgroundColor: Colors.grey.shade700,
          child: status.mediaType == "text" 
             ? Container(decoration: BoxDecoration(shape: BoxShape.circle, color: Color(int.parse(status.mediaUrl))), alignment: Alignment.center, child: Text(status.caption.isNotEmpty ? status.caption[0] : "T", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))
             : (status.photoUrl != null && status.photoUrl!.isNotEmpty
                  ? ClipOval(child: CachedNetworkImage(imageUrl: status.photoUrl!, width: 44, height: 44, fit: BoxFit.cover, errorWidget: (_, __, ___) => const Icon(Icons.person, color: Colors.white)))
                  : Text(status.name.isNotEmpty ? status.name[0].toUpperCase() : "U", style: const TextStyle(color: Colors.white))),
        ),
      ),
      title: Text(status.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      subtitle: Text(_formatTime(status.timestamp), style: const TextStyle(color: Colors.white54)),
      onTap: () => _viewStatus(userStatuses), 
    );
  }
}

// ==========================================
// NEW: Caption & Privacy Screen for Media
// ==========================================
class CaptionAndPrivacyScreen extends StatefulWidget {
  final File file;
  final String mediaType;
  const CaptionAndPrivacyScreen({super.key, required this.file, required this.mediaType});

  @override
  State<CaptionAndPrivacyScreen> createState() => _CaptionAndPrivacyScreenState();
}

class _CaptionAndPrivacyScreenState extends State<CaptionAndPrivacyScreen> {
  final TextEditingController _captionController = TextEditingController();
  String _selectedPrivacy = "everyone";
  bool isUploading = false;
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    if (widget.mediaType == "video") {
      _videoController = VideoPlayerController.file(widget.file)..initialize().then((_) => setState(() {}))..setLooping(true)..play();
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _upload() async {
    setState(() => isUploading = true);
    try {
      await StatusService.uploadStatus(
        file: widget.file,
        mediaType: widget.mediaType,
        caption: _captionController.text.trim(),
        privacy: _selectedPrivacy,
      );
      if (mounted) {
        Navigator.pop(context); // Close Screen
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Status Uploaded"), backgroundColor: Color(0xff25D366)));
      }
    } catch (e) {
      setState(() => isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload Failed: $e"), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("Edit Status"),
        actions: [
          // Privacy Dropdown
          DropdownButton<String>(
            dropdownColor: Colors.grey.shade900,
            value: _selectedPrivacy,
            style: const TextStyle(color: Colors.white),
            underline: const SizedBox(),
            icon: const Icon(Icons.lock, color: Colors.white70, size: 20),
            items: const [
              DropdownMenuItem(value: "everyone", child: Text("Everyone")),
              DropdownMenuItem(value: "contacts", child: Text("My Contacts")),
              DropdownMenuItem(value: "nobody", child: Text("Nobody")),
            ],
            onChanged: (val) => setState(() => _selectedPrivacy = val!),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Stack(
        children: [
          Center(
            child: widget.mediaType == "video"
                ? (_videoController != null && _videoController!.value.isInitialized
                    ? AspectRatio(aspectRatio: _videoController!.value.aspectRatio, child: VideoPlayer(_videoController!))
                    : const CircularProgressIndicator())
                : Image.file(widget.file, fit: BoxFit.contain),
          ),
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              color: Colors.black54,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _captionController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(hintText: "Add a caption...", hintStyle: const TextStyle(color: Colors.white54), border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none), filled: true, fillColor: Colors.grey.shade800, contentPadding: const EdgeInsets.symmetric(horizontal: 20)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FloatingActionButton(
                    mini: true,
                    backgroundColor: const Color(0xff25D366),
                    onPressed: isUploading ? null : _upload,
                    child: isUploading ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.send, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// Text Status Screen (Updated with Privacy)
// ==========================================
class TextStatusScreen extends StatefulWidget {
  const TextStatusScreen({super.key});
  @override
  State<TextStatusScreen> createState() => _TextStatusScreenState();
}

class _TextStatusScreenState extends State<TextStatusScreen> {
  final TextEditingController _textController = TextEditingController();
  List<Color> bgColors = [Colors.deepPurple, Colors.teal, Colors.brown, Colors.blueGrey, Colors.indigo, Colors.orange.shade800];
  int colorIndex = 0;
  bool isUploading = false;
  String _selectedPrivacy = "everyone";

  void _changeBackground() => setState(() => colorIndex = (colorIndex + 1) % bgColors.length);

  Future<void> _uploadText() async {
    if (_textController.text.trim().isEmpty) return;
    setState(() => isUploading = true);
    try {
      await StatusService.uploadTextStatus(text: _textController.text.trim(), colorValueString: bgColors[colorIndex].toARGB32().toString(), privacy: _selectedPrivacy);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Status Uploaded"), backgroundColor: Color(0xff25D366)));
      }
    } catch (e) {
      setState(() => isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed: $e"), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColors[colorIndex],
      body: SafeArea(
        child: Stack(
          children: [
            Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 30), child: TextField(controller: _textController, textAlign: TextAlign.center, maxLines: null, style: const TextStyle(color: Colors.white, fontSize: 35, fontWeight: FontWeight.bold), decoration: const InputDecoration(border: InputBorder.none, hintText: "Type a status", hintStyle: TextStyle(color: Colors.white54, fontSize: 35))))),
            Positioned(top: 10, right: 10, child: IconButton(icon: const Icon(Icons.color_lens, color: Colors.white, size: 30), onPressed: _changeBackground)),
            Positioned(top: 10, left: 10, child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 30), onPressed: () => Navigator.pop(context))),
            
            // Privacy Selector
            Positioned(
              top: 10, left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10), decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(20)),
                  child: DropdownButton<String>(
                    dropdownColor: Colors.grey.shade900, value: _selectedPrivacy, style: const TextStyle(color: Colors.white), underline: const SizedBox(), icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                    items: const [DropdownMenuItem(value: "everyone", child: Text("Everyone")), DropdownMenuItem(value: "contacts", child: Text("My Contacts")), DropdownMenuItem(value: "nobody", child: Text("Nobody"))],
                    onChanged: (val) => setState(() => _selectedPrivacy = val!),
                  ),
                ),
              ),
            ),
            if (isUploading) const Center(child: CircularProgressIndicator(color: Colors.white))
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(backgroundColor: const Color(0xff25D366), onPressed: isUploading ? null : _uploadText, child: const Icon(Icons.send, color: Colors.white)),
    );
  }
}

// ==========================================
// Status Viewer Screen (With Reply UI & Viewer Details)
// ==========================================
class StatusViewerScreen extends StatefulWidget {
  final List<StatusModel> statuses;
  const StatusViewerScreen({super.key, required this.statuses});

  @override
  State<StatusViewerScreen> createState() => _StatusViewerScreenState();
}

class _StatusViewerScreenState extends State<StatusViewerScreen> {
  int currentIndex = 0;
  double progress = 0;
  Timer? timer;
  VideoPlayerController? _videoController;

  bool isPaused = false;
  bool _isLongPress = false; 
  
  // Reply Logic
  final FocusNode _replyFocusNode = FocusNode();
  final TextEditingController _replyController = TextEditingController();

  late List<StatusModel> myStatuses;

  @override
  void initState() {
    super.initState();
    myStatuses = List.from(widget.statuses);
    
    // Auto Pause when keyboard opens for replying
    _replyFocusNode.addListener(() {
      setState(() => isPaused = _replyFocusNode.hasFocus);
      if (_replyFocusNode.hasFocus) { if (isVideo) _videoController?.pause(); } 
      else { if (isVideo) _videoController?.play(); }
    });

    _loadStatus(currentIndex);
  }

  bool get isVideo => myStatuses[currentIndex].mediaType == "video";
  bool get isText => myStatuses[currentIndex].mediaType == "text";

  void _loadStatus(int index) {
    timer?.cancel();
    _videoController?.dispose();
    progress = 0;

    final status = myStatuses[index];
    StatusService.markViewed(status.id, status.uid);

    if (isVideo) { _initializeVideo(status.mediaUrl); } else { _startImageTimer(); }
  }

  Future<void> _initializeVideo(String url) async {
    _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
    await _videoController!.initialize();
    _videoController!.play();
    _videoController!.addListener(_videoListener);
    setState(() {});
  }

  void _videoListener() {
    if (!mounted || isPaused) return;
    final duration = _videoController!.value.duration.inMilliseconds;
    final position = _videoController!.value.position.inMilliseconds;
    if (duration > 0) setState(() => progress = position / duration);
    if (position >= duration && duration > 0 && progress >= 0.99) {
      _videoController!.removeListener(_videoListener);
      _nextStatus();
    }
  }

  void _startImageTimer() {
    timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted || isPaused) return;
      setState(() => progress += 0.01); 
      if (progress >= 1) { timer.cancel(); _nextStatus(); }
    });
  }

  void _nextStatus() {
    if (currentIndex < myStatuses.length - 1) { setState(() => currentIndex++); _loadStatus(currentIndex); } 
    else { Navigator.pop(context); }
  }

  void _prevStatus() {
    if (currentIndex > 0) { setState(() => currentIndex--); _loadStatus(currentIndex); } 
    else { setState(() => progress = 0); _loadStatus(currentIndex); }
  }

  Future<void> _sendReply(String message) async {
    if (message.trim().isEmpty) return;
    final status = myStatuses[currentIndex];
    
    _replyController.clear();
    _replyFocusNode.unfocus(); // Resumes playing
    
    await StatusService.replyToStatus(
      statusId: status.id,
      receiverUid: status.uid,
      replyMessage: message,
      mediaUrl: status.mediaUrl,
    );
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reply sent"), duration: Duration(seconds: 1)));
  }

  void _showDeleteConfirmation(StatusModel statusToDelete) {
    setState(() => isPaused = true);
    if (isVideo) _videoController?.pause();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text("Delete Status?", style: TextStyle(color: Colors.white)),
        content: const Text("Are you sure you want to delete this status update?", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () { Navigator.pop(context); setState(() => isPaused = false); if (isVideo) _videoController?.play(); }, child: const Text("Cancel", style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () async { Navigator.pop(context); await _deleteStatus(statusToDelete); }, child: const Text("Delete", style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
  }

  Future<void> _deleteStatus(StatusModel status) async {
    await StatusService.deleteStatus(status.id, status.mediaUrl);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Status Deleted"), backgroundColor: Colors.redAccent));
      myStatuses.remove(status);
      if (myStatuses.isEmpty) { Navigator.pop(context); } 
      else { if (currentIndex >= myStatuses.length) currentIndex = myStatuses.length - 1; _loadStatus(currentIndex); }
    }
  }

  void _showViewersBottomSheet(StatusModel status) {
    setState(() => isPaused = true);
    if (isVideo) _videoController?.pause();

    showModalBottomSheet(
      context: context, backgroundColor: Colors.grey.shade900, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: Column(
              children: [
                Container(margin: const EdgeInsets.only(top: 10, bottom: 10), height: 4, width: 40, decoration: BoxDecoration(color: Colors.grey.shade600, borderRadius: BorderRadius.circular(2))),
                Padding(padding: const EdgeInsets.all(15.0), child: Text("Viewed by ${status.viewers.length}", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
                const Divider(color: Colors.white24, height: 1),
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: StatusService.getViewerDetails(status.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xff25D366)));
                      if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text("No views yet", style: TextStyle(color: Colors.white54, fontSize: 16)));
                      
                      final viewers = snapshot.data!;
                      return ListView.builder(
                        itemCount: viewers.length,
                        itemBuilder: (context, index) {
                          final viewer = viewers[index];
                          return ListTile(
                            leading: CircleAvatar(backgroundColor: Colors.grey.shade700, child: viewer["photoUrl"].isNotEmpty ? ClipOval(child: CachedNetworkImage(imageUrl: viewer["photoUrl"], width: 40, height: 40, fit: BoxFit.cover)) : Text(viewer["name"][0].toUpperCase(), style: const TextStyle(color: Colors.white))),
                            title: Text(viewer["name"], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            // NEW: Show formatted View Time 
                            trailing: Text(_formatTime(viewer["time"]), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(() { setState(() => isPaused = false); if (isVideo) _videoController?.play(); });
  }

  @override
  void dispose() {
    timer?.cancel();
    _videoController?.dispose();
    _replyController.dispose();
    _replyFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (myStatuses.isEmpty) return const Scaffold(backgroundColor: Colors.black);

    final status = myStatuses[currentIndex];
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final isMyStatus = status.uid == myUid;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true, // Keyboad push up karega
      body: SafeArea(
        child: GestureDetector(
          onTapDown: (_) { setState(() => isPaused = true); if (isVideo) _videoController?.pause(); },
          onLongPress: () { setState(() => _isLongPress = true); },
          onLongPressEnd: (_) { setState(() { _isLongPress = false; isPaused = false; }); if (isVideo) _videoController?.play(); },
          onTapUp: (details) {
            if (_isLongPress || _replyFocusNode.hasFocus) return; 
            setState(() => isPaused = false);
            if (isVideo) _videoController?.play();
            
            final dx = details.globalPosition.dx;
            final dy = details.globalPosition.dy;
            
            if (dy > MediaQuery.of(context).size.height * 0.8) return; // Prevent next status if tapping bottom bar

            if (dx < MediaQuery.of(context).size.width / 3) { _prevStatus(); } else { _nextStatus(); }
          },
          onTapCancel: () { setState(() => isPaused = false); if (isVideo) _videoController?.play(); },
          child: Stack(
            children: [
              Positioned.fill(
                child: isText 
                    ? Container(color: Color(int.parse(status.mediaUrl)), alignment: Alignment.center, padding: const EdgeInsets.all(20), child: Text(status.caption, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)))
                    : isVideo
                        ? (_videoController != null && _videoController!.value.isInitialized)
                            ? FittedBox(fit: BoxFit.cover, child: SizedBox(width: _videoController!.value.size.width, height: _videoController!.value.size.height, child: VideoPlayer(_videoController!)))
                            : const Center(child: CircularProgressIndicator(color: Colors.white))
                        : CachedNetworkImage(imageUrl: status.mediaUrl, fit: BoxFit.cover, placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: Colors.white)), errorWidget: (context, url, error) => const Center(child: Icon(Icons.error, color: Colors.white, size: 50))),
              ),
              
              AnimatedOpacity(
                opacity: _isLongPress ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Stack(
                  children: [
                    Positioned(
                      top: 10, left: 10, right: 10,
                      child: Row(
                        children: myStatuses.asMap().entries.map((entry) {
                          double value = 0.0;
                          if (entry.key < currentIndex) {
                            value = 1.0;
                          } else if (entry.key == currentIndex) value = progress;
                          return Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2.0), child: LinearProgressIndicator(value: value, minHeight: 3, color: Colors.white, backgroundColor: Colors.white30, borderRadius: BorderRadius.circular(2))));
                        }).toList(),
                      ),
                    ),
                    
                    Positioned(
                      top: 25, left: 15, right: 15,
                      child: Row(
                        children: [
                          CircleAvatar(radius: 20, backgroundColor: Colors.grey.shade700, child: status.photoUrl != null && status.photoUrl!.isNotEmpty ? ClipOval(child: CachedNetworkImage(imageUrl: status.photoUrl!, width: 40, height: 40, fit: BoxFit.cover)) : Text(status.name.isNotEmpty ? status.name[0].toUpperCase() : "U", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                          const SizedBox(width: 10),
                          Expanded(child: Text(status.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black54, blurRadius: 4)]))),
                          if (isMyStatus) IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: () => _showDeleteConfirmation(status)),
                        ],
                      ),
                    ),

                    if (status.caption.isNotEmpty && !isText)
                      Positioned(
                        bottom: 90, left: 20, right: 20,
                        child: Container(padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15), decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(12)), child: Text(status.caption, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16))),
                      ),

                    // Bottom Bar (Viewers / Reply UI)
                    Positioned(
                      bottom: 10, left: 10, right: 10,
                      child: isMyStatus
                          // Apna Status: Show View Count
                          ? Center(
                              child: GestureDetector(
                                onTap: () => _showViewersBottomSheet(status),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                                  decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(20)),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.keyboard_arrow_up, color: Colors.white, size: 20),
                                      const SizedBox(width: 5),
                                      const Icon(Icons.remove_red_eye, color: Colors.white, size: 18),
                                      const SizedBox(width: 5),
                                      Text("${status.viewers.length}", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          // Dusre Ka Status: Show Reply UI
                          : Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    focusNode: _replyFocusNode,
                                    controller: _replyController,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      hintText: "Reply...",
                                      hintStyle: const TextStyle(color: Colors.white54),
                                      filled: true,
                                      fillColor: Colors.black45,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                                      // Right side send arrow
                                      suffixIcon: IconButton(
                                        icon: const Icon(Icons.send, color: Colors.white),
                                        onPressed: () => _sendReply(_replyController.text),
                                      ),
                                    ),
                                    onSubmitted: _sendReply,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                // Quick Reaction Heart Emoji
                                GestureDetector(
                                  onTap: () => _sendReply("❤️"),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black45),
                                    child: const Text("❤️", style: TextStyle(fontSize: 22)),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}