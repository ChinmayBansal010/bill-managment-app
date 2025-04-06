import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(KhataApp());
}

class KhataApp extends StatelessWidget {
  const KhataApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        scaffoldBackgroundColor: Colors.grey[100],
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  final DatabaseReference dbRef = FirebaseDatabase.instance.ref().child('users');
  final TextEditingController searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: searchController,
          decoration: const InputDecoration(
            hintText: 'Search...',
            prefixIcon: Icon(Icons.search),
            border: InputBorder.none,
          ),
          onChanged: (_) => setState(() {}),
        ),
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: dbRef.onValue,
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
            final value = snapshot.data!.snapshot.value;

            if (value is Map) {
              Map<dynamic, dynamic> users = value;
              List filteredUsers = users.keys
                  .where((key) => key.toLowerCase().contains(searchController.text.toLowerCase()))
                  .toList();

              return ListView.builder(
                padding: EdgeInsets.all(10),
                itemCount: filteredUsers.length,
                itemBuilder: (context, index) {
                  String name = filteredUsers[index];
                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 3,
                    margin: EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      leading: CircleAvatar(child: Text(name[0].toUpperCase())),
                      title: Text(name, style: TextStyle(fontWeight: FontWeight.bold)),
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => UserPage(name: name)));
                      },
                      onLongPress: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text('Delete $name?'),
                            content: Text('Are you sure you want to delete this user?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () {
                                  dbRef.child(name).remove();
                                  Navigator.pop(context);
                                },
                                child: Text('Delete', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                  );
                },

              );
            } else {
              return Center(child: Text('Invalid data format'));
            }
          }
          return const Center(child: Text('No Users'));
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add),
        onPressed: () {
          TextEditingController nameController = TextEditingController();
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: const Text('Add Name'),
              content: TextField(
                controller: nameController,
                decoration: const InputDecoration(hintText: 'Enter Name'),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    if (nameController.text.isNotEmpty) {
                      dbRef.child(nameController.text.toUpperCase()).set({"transactions": {}, "balance": 0});
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Add'),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}

class UserPage extends StatefulWidget {
  final String name;
  const UserPage({super.key, required this.name});

  @override
  UserPageState createState() => UserPageState();
}

class UserPageState extends State<UserPage> {
  late DatabaseReference userRef;
  final TextEditingController noteController = TextEditingController();
  int sno = 0;

  @override
  void initState() {
    super.initState();
    userRef = FirebaseDatabase.instance.ref().child('users').child(widget.name);
  }

  void addTransaction(String type) async {
    if (noteController.text.isNotEmpty) {
      int amount = int.tryParse(noteController.text.split(' ').last) ?? 0;
      if (type == 'credit') amount = -amount;

      DataSnapshot transSnap = await userRef.child('transactions').get();
      Map<String, dynamic> existing = {};

      if (transSnap.value != null) {
        final val = transSnap.value;
        if (val is Map) {
          existing = Map<String, dynamic>.from(val);
        } else if (val is List) {
          for (int i = 0; i < val.length; i++) {
            if (val[i] != null) {
              existing[i.toString()] = Map<String, dynamic>.from(val[i]);
            }
          }
        }
      }

      sno = (existing.keys.map((e) => int.tryParse(e.toString()) ?? 0).fold(0, (a, b) => a > b ? a : b)) + 1;

      await userRef.child('transactions').child(sno.toString()).set({
        "note": noteController.text,
        "amount": amount,
        "time": DateTime.now().toIso8601String(),
      });

      DataSnapshot balanceSnap = await userRef.child('balance').get();
      int balance = balanceSnap.value != null ? int.parse(balanceSnap.value.toString()) : 0;
      await userRef.child('balance').set(balance + amount);

      noteController.clear();
    }
  }


  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: Text(widget.name)),
        body: StreamBuilder<DatabaseEvent>(
          stream: userRef.onValue,
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
              final data = snapshot.data!.snapshot.value as Map;
              final int balance = data['balance'] ?? 0;
              final dynamic transactionsRaw = data['transactions'];

              Map<dynamic, dynamic> transactions = {};

              if (transactionsRaw is Map) {
                transactions = transactionsRaw;
              } else if (transactionsRaw is List) {
                for (int i = 0; i < transactionsRaw.length; i++) {
                  if (transactionsRaw[i] != null) {
                    transactions[i] = transactionsRaw[i];
                  }
                }
              }

              List transList = transactions.entries.toList();
              transList.sort((a, b) => b.key.compareTo(a.key));

              return Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    color: Colors.teal,
                    child: Column(
                      children: [
                        Text('Balance: ₹${balance.abs()}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text(
                          balance >= 0 ? '${widget.name} owes you' : 'You owe ${widget.name}',
                          style: const TextStyle(color: Colors.white70, fontSize: 16),
                        )
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      reverse: true,
                      padding: const EdgeInsets.all(8),
                      children: transList.map<Widget>((entry) {
                        final key = entry.key;
                        final value = entry.value;
                        final isCredit = value['amount'] < 0;
                        final time = DateFormat('dd MMM yyyy hh:mm a').format(DateTime.parse(value['time']));

                        return GestureDetector(
                          onLongPress: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                title: const Text('Delete Transaction'),
                                content: const Text('Are you sure you want to delete this transaction?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      Navigator.pop(context); // close the dialog immediately

                                      // Now safely do async work
                                      await userRef.child('transactions').child(key.toString()).remove();

                                      final balanceSnap = await userRef.child('balance').get();
                                      final balance = balanceSnap.value != null ? int.parse(balanceSnap.value.toString()) : 0;
                                      await userRef.child('balance').set(balance - value['amount']);
                                    },
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: Align(
                            alignment: isCredit ? Alignment.centerLeft : Alignment.centerRight,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isCredit ? Colors.red[100] : Colors.green[100],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(value['note'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text('₹${value['amount'].abs()}  |  $time', style: TextStyle(fontSize: 12, color: Colors.grey[700]))
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        TextField(
                          controller: noteController,
                          decoration: const InputDecoration(hintText: 'Enter note and amount (e.g. Paid 200)'),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => addTransaction('credit'),
                              icon: const Icon(Icons.remove),
                              label: const Text('Credit'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => addTransaction('debit'),
                              icon: const Icon(Icons.add),
                              label: const Text('Debit'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            ),
                          ],
                        )
                      ],
                    ),
                  )
                ],
              );
            }
            return const Center(child: CircularProgressIndicator());
          },
        ),
      ),
    );
  }
}
