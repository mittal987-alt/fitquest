import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';
import '../models/player_model.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<PlayerModel> _searchResults = [];
  bool _isSearching = false;
  bool _isLoading = false;

  Future<void> _performSearch(String query, FirebaseService firebaseService) async {
    if (query.trim().isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _isSearching = true;
    });

    try {
      final results = await firebaseService.searchPlayers(query.trim());
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("SEARCH ERROR: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final firebaseService = Provider.of<FirebaseService>(context);
    final user = firebaseService.currentUser;

    if (user == null) return const Scaffold(body: Center(child: Text("NOT AUTHENTICATED")));

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0E),
      appBar: AppBar(
        title: const Text("NETWORK", style: TextStyle(fontFamily: 'Orbitron', letterSpacing: 2, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchController.clear();
                  _searchResults = [];
                });
              },
            )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "SEARCH OPERATIVE ID OR NAME...",
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF00F2FF)),
                filled: true,
                fillColor: const Color(0xFF1A1A2E),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
              onSubmitted: (value) => _performSearch(value, firebaseService),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF00F2FF)))
                : _isSearching
                    ? _buildSearchResults(firebaseService, user.uid)
                    : _buildFriendsList(firebaseService, user.uid),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(FirebaseService firebaseService, String currentUid) {
    if (_searchResults.isEmpty) {
      return const Center(
        child: Text("NO OPERATIVES FOUND", style: TextStyle(color: Colors.white38, fontFamily: 'Orbitron')),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final player = _searchResults[index];
        if (player.uid == currentUid) return const SizedBox.shrink();

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.blueGrey,
            backgroundImage: player.avatar.isNotEmpty ? NetworkImage(player.avatar) : null,
            child: player.avatar.isEmpty ? Text(player.name[0]) : null,
          ),
          title: Text(player.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          subtitle: Text("LVL ${player.level}", style: const TextStyle(color: Color(0xFF00F2FF), fontSize: 12)),
          trailing: StreamBuilder<PlayerModel?>(
            stream: firebaseService.getPlayerStream(currentUid),
            builder: (context, snapshot) {
              final isFriend = snapshot.data?.friends.contains(player.uid) ?? false;
              return ElevatedButton(
                onPressed: isFriend
                    ? null
                    : () async {
                        await firebaseService.addFriend(currentUid, player.uid);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("CONNECTION ESTABLISHED")),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isFriend ? Colors.grey : const Color(0xFF00F2FF),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: Text(isFriend ? "CONNECTED" : "CONNECT"),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildFriendsList(FirebaseService firebaseService, String currentUid) {
    return StreamBuilder<PlayerModel?>(
      stream: firebaseService.getPlayerStream(currentUid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final player = snapshot.data!;
        final friends = player.friends;

        if (friends.isEmpty) {
          return const Center(
            child: Text(
              "NO ACTIVE CONNECTIONS FOUND",
              style: TextStyle(color: Colors.white38, fontFamily: 'Orbitron'),
            ),
          );
        }

        return ListView.builder(
          itemCount: friends.length,
          itemBuilder: (context, index) {
            return FutureBuilder<PlayerModel?>(
              future: firebaseService.getPlayer(friends[index]),
              builder: (context, fSnap) {
                if (!fSnap.hasData) return const SizedBox.shrink();
                final friend = fSnap.data!;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.purple,
                    backgroundImage: friend.avatar.isNotEmpty ? NetworkImage(friend.avatar) : null,
                    child: friend.avatar.isEmpty ? Text(friend.name[0]) : null,
                  ),
                  title: Text(friend.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text("LVL ${friend.level} | ${friend.totalSteps} STEPS", style: const TextStyle(color: Color(0xFF00F2FF), fontSize: 12)),
                  trailing: IconButton(
                    icon: const Icon(Icons.person_remove_outlined, color: Colors.white24),
                    onPressed: () => _confirmRemoveFriend(firebaseService, currentUid, friend.uid, friend.name),
                  ),
                  onTap: () {
                    // TODO: View friend profile
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  void _confirmRemoveFriend(FirebaseService firebaseService, String currentUid, String friendId, String friendName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text("TERMINATE CONNECTION?", style: TextStyle(color: Colors.white, fontFamily: 'Orbitron')),
        content: Text("Are you sure you want to remove $friendName from your network?", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await firebaseService.removeFriend(currentUid, friendId);
            },
            child: const Text("TERMINATE", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
