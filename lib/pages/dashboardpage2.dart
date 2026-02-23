// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'Chats.dart';
// import 'CustomerOnboardingPage.dart';
// import 'Leads.dart';
// import 'Reports.dart';
// import 'Settings.dart';
// import 'Vault.dart';

// class DashboardPage2 extends StatefulWidget {
//   const DashboardPage2({super.key});

//   @override
//   _DashboardPageState createState() => _DashboardPageState();
// }

// class _DashboardPageState extends State<DashboardPage2> {
//   bool showBalance = false;
//   bool showCommission = false;
//   bool showTransport = false;

//   final List<String> _images = [
//     'assets/images/back1.png',
//     'assets/images/back2.jpg',
//     'assets/images/back3.png',
//   ];

//   int _currentImageIndex = 0;
//   Timer? _timer;

//   @override
//   void initState() {
//     super.initState();
//     // Change image every 10 seconds
//     _timer = Timer.periodic(const Duration(seconds: 10), (Timer t) {
//       setState(() {
//         _currentImageIndex = (_currentImageIndex + 1) % _images.length;
//       });
//     });
//   }

//   @override
//   void dispose() {
//     _timer?.cancel();
//     super.dispose();
//   }

//   Future<bool> _verifyPassword() async {
//     final controller = TextEditingController();
//     bool verified = false;

//     await showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Enter Password'),
//         content: TextField(
//           controller: controller,
//           obscureText: true,
//           decoration: const InputDecoration(hintText: 'Enter password'),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Cancel'),
//           ),
//           TextButton(
//             onPressed: () {
//               if (controller.text.trim() == '123456') {
//                 verified = true;
//                 Navigator.pop(context);
//               } else {
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(content: Text('Incorrect password')),
//                 );
//               }
//             },
//             child: const Text('Submit'),
//           ),
//         ],
//       ),
//     );

//     return verified;
//   }

//   @override
//   Widget build(BuildContext context) {
//     const orange = Color(0xFFFF6600);

//     return Scaffold(
//       backgroundColor: Colors.white,
//       body: SingleChildScrollView(
//         child: Column(
//           children: [
//             // ================= Header =================
//             Stack(
//               children: [
//                 // Background image
//                 Image.asset(
//                   _images[_currentImageIndex],
//                   fit: BoxFit.cover,
//                   width: double.infinity,
//                   height: 250,
//                 ),

//                 // Gradient overlay
//                 Container(
//                   height: 250,
//                   decoration: const BoxDecoration(
//                     gradient: LinearGradient(
//                       colors: [Color(0xCF000000), Color(0x24000000)],
//                       begin: Alignment.bottomCenter,
//                       end: Alignment.topCenter,
//                     ),
//                   ),
//                 ),

//                 // Add Client + Settings row
//                 Positioned(
//                   top: 200,
//                   left: 20,
//                   right: 15,
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       GestureDetector(
//                         onTap: () {
//                           Navigator.push(
//                               context,
//                               MaterialPageRoute(
//                                   builder: (context) =>
//                                       CustomerOnboardingPage()));
//                         },
//                         child: Container(
//                           height: 40,
//                           width: 150,
//                           decoration: BoxDecoration(
//                             color: Colors.white,
//                             borderRadius: BorderRadius.circular(14),
//                             boxShadow: const [
//                               BoxShadow(
//                                 color: Colors.black12,
//                                 blurRadius: 4,
//                                 offset: Offset(0, 2),
//                               )
//                             ],
//                           ),
//                           child: const Center(
//                             child: Text(
//                               "Add Client",
//                               style: TextStyle(
//                                   color: Colors.black,
//                                   fontWeight: FontWeight.bold),
//                             ),
//                           ),
//                         ),
//                       ),
//                       GestureDetector(
//                         onTap: () {
//                           Navigator.push(
//                               context,
//                               MaterialPageRoute(
//                                   builder: (context) => SettingsPage()));
//                         },
//                         child: Container(
//                           decoration: BoxDecoration(
//                             color: Colors.white.withOpacity(0.9),
//                             shape: BoxShape.circle,
//                             boxShadow: const [
//                               BoxShadow(
//                                   color: Colors.black26,
//                                   blurRadius: 4,
//                                   offset: Offset(0, 2))
//                             ],
//                           ),
//                           padding: const EdgeInsets.all(8),
//                           child: const Icon(Icons.settings,
//                               color: Colors.black87, size: 26),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),

//                 // User info row
//                 Positioned(
//                   top: 50,
//                   left: 16,
//                   right: 16,
//                   child: Row(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       CircleAvatar(
//                         backgroundColor: orange,
//                         child:
//                         const Text('FB', style: TextStyle(color: Colors.white)),
//                       ),
//                       const SizedBox(width: 8),
//                       Expanded(
//                         child: Container(
//                           height: 140,
//                           padding: const EdgeInsets.all(12),
//                           decoration: BoxDecoration(
//                             color: Colors.white,
//                             borderRadius: BorderRadius.circular(14),
//                             boxShadow: const [
//                               BoxShadow(
//                                   color: Colors.black26,
//                                   blurRadius: 6,
//                                   offset: Offset(0, 3))
//                             ],
//                           ),
//                           child: Column(
//                             mainAxisAlignment: MainAxisAlignment.center,
//                             children: [
//                               const Text(
//                                 "Frank Botoman",
//                                 style: TextStyle(
//                                   fontSize: 14,
//                                   fontWeight: FontWeight.bold,
//                                   color: Colors.black87,
//                                 ),
//                               ),
//                               const SizedBox(height: 4),
//                               const Text(
//                                 "Agent ID: Pinnacle123",
//                                 style: TextStyle(
//                                     fontSize: 12, color: Colors.black54),
//                               ),
//                               const Text(
//                                 "License Number: 93289283",
//                                 style: TextStyle(
//                                     fontSize: 12, color: Colors.black54),
//                               ),
//                               const SizedBox(height: 10),
//                               const Text(
//                                 "Monthly Sales Target",
//                                 style: TextStyle(
//                                     fontSize: 12,
//                                     fontWeight: FontWeight.w600,
//                                     color: Colors.black87),
//                                 textAlign: TextAlign.center,
//                               ),
//                               const SizedBox(height: 6),
//                               Stack(
//                                 alignment: Alignment.centerLeft,
//                                 children: [
//                                   Container(
//                                     height: 18,
//                                     decoration: BoxDecoration(
//                                       color: Colors.grey[300],
//                                       borderRadius: BorderRadius.circular(10),
//                                     ),
//                                   ),
//                                   LayoutBuilder(
//                                     builder: (context, constraints) {
//                                       final width = constraints.maxWidth * 0.72;
//                                       return Stack(
//                                         children: [
//                                           Container(
//                                             height: 18,
//                                             width: width,


//                                             decoration: BoxDecoration(
//                                               color: const Color.fromARGB(215, 8, 129, 8),
//                                               borderRadius: BorderRadius.circular(10),
//                                             ),
//                                           ),
//                                           const Positioned.fill(
//                                             child: Center(
//                                               child: Text(
//                                                 "72%",
//                                                 style: TextStyle(
//                                                     color: Colors.white,
//                                                     fontSize: 12,
//                                                     fontWeight: FontWeight.bold),
//                                               ),
//                                             ),
//                                           ),
//                                         ],
//                                       );
//                                     },
//                                   )
//                                 ],
//                               )
//                             ],
//                           ),
//                         ),
//                       ),
//                       const SizedBox(width: 8),
//                       Stack(
//                         children: [
//                           const Icon(Icons.notifications,
//                               color: Colors.white, size: 42),
//                           Positioned(
//                             right: 0,
//                             child: Container(
//                               padding: const EdgeInsets.all(2),
//                               decoration: const BoxDecoration(
//                                 color: Colors.red,
//                                 shape: BoxShape.circle,
//                               ),
//                               constraints: const BoxConstraints(
//                                   minWidth: 22, minHeight: 22),
//                               child: const Text(
//                                 '7',
//                                 style: TextStyle(
//                                     color: Colors.white, fontSize: 16),
//                                 textAlign: TextAlign.center,
//                               ),
//                             ),
//                           )
//                         ],
//                       )
//                     ],
//                   ),
//                 ),
//               ],
//             ),

//             const SizedBox(height: 16),

//             // ================= Main Content =================
//             Padding(
//               padding: const EdgeInsets.all(4),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   // Transport Incentive
//                   Align(
//                     alignment: Alignment.center,
//                     child: Container(
//                       width: MediaQuery.of(context).size.width * 0.92,
//                       padding: const EdgeInsets.all(16),
//                       decoration: BoxDecoration(
//                           color: orange,
//                           borderRadius: BorderRadius.circular(12)),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           const Text(
//                             'Transport Incentive',
//                             style: TextStyle(
//                                 color: Colors.white,
//                                 fontSize: 18,
//                                 fontWeight: FontWeight.bold),
//                           ),
//                           const SizedBox(height: 4),
//                           Row(
//                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                             children: [
//                               Text(
//                                 showTransport ? 'K757,800.00' : 'KX,XXX.xx',
//                                 style: const TextStyle(
//                                     color: Colors.white,
//                                     fontSize: 24,
//                                     fontWeight: FontWeight.bold),
//                               ),
//                               ElevatedButton.icon(
//                                 style: ElevatedButton.styleFrom(
//                                   backgroundColor: Colors.white,
//                                   foregroundColor: Colors.black,
//                                   padding: const EdgeInsets.symmetric(
//                                       horizontal: 14, vertical: 8),
//                                   shape: RoundedRectangleBorder(
//                                     borderRadius: BorderRadius.circular(20),
//                                   ),
//                                 ),
//                                 onPressed: () async {
//                                   if (!showTransport) {
//                                     final verified = await _verifyPassword();
//                                     if (verified) {
//                                       setState(() => showTransport = true);
//                                     }
//                                   } else {
//                                     setState(() => showTransport = false);
//                                   }
//                                 },
//                                 icon: Icon(
//                                   showTransport
//                                       ? Icons.visibility_off
//                                       : Icons.visibility,
//                                   size: 18,
//                                 ),
//                                 label: Text(
//                                   showTransport ? 'Hide Amount' : 'Show Amount',
//                                   style: const TextStyle(
//                                       fontSize: 13, fontWeight: FontWeight.w500),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),

//                   const SizedBox(height: 24),

//                   // Commission Card
//                   Align(
//                     alignment: Alignment.center,
//                     child: Container(
//                       width: MediaQuery.of(context).size.width * 0.92,
//                       padding: const EdgeInsets.all(16),
//                       decoration: BoxDecoration(
//                           color: orange,
//                           borderRadius: BorderRadius.circular(12)),
//                       child: Row(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Expanded(
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 const Text(
//                                   'Commission Earned',
//                                   style: TextStyle(
//                                       color: Colors.white,
//                                       fontSize: 18,
//                                       fontWeight: FontWeight.bold),
//                                 ),
//                                 const SizedBox(height: 4),
//                                 Row(
//                                   children: const [
//                                     Icon(Icons.wallet,
//                                         color: Colors.white, size: 16),
//                                     SizedBox(width: 4),
//                                     Text(
//                                       'Main wallet',
//                                       style: TextStyle(
//                                           color: Colors.white, fontSize: 14),
//                                     ),
//                                   ],
//                                 ),
//                                 const SizedBox(height: 12),
//                                 Text(
//                                   showCommission
//                                       ? 'K1,257,500.00'
//                                       : 'KX,XXX.xx',
//                                   style: const TextStyle(
//                                       color: Colors.white,
//                                       fontSize: 24,
//                                       fontWeight: FontWeight.bold),
//                                 ),
//                                 ElevatedButton.icon(
//                                   style: ElevatedButton.styleFrom(
//                                     backgroundColor: Colors.white,
//                                     foregroundColor: Colors.black,
//                                     shape: RoundedRectangleBorder(
//                                       borderRadius: BorderRadius.circular(20),
//                                     ),
//                                   ),
//                                   onPressed: () async {
//                                     if (!showCommission) {
//                                       final verified = await _verifyPassword();
//                                       if (verified) {
//                                         setState(() => showCommission = true);
//                                       }
//                                     } else {
//                                       setState(() => showCommission = false);
//                                     }
//                                   },
//                                   icon: Icon(showCommission
//                                       ? Icons.visibility_off
//                                       : Icons.visibility),
//                                   label: Text(showCommission
//                                       ? 'Hide Balance'
//                                       : 'Show Balance'),
//                                 )
//                               ],
//                             ),
//                           ),
//                           SizedBox(
//                             width: 125,
//                             height: 180,
//                             child: Image.asset(
//                               'assets/images/2pins malawi transparent.png',
//                               fit: BoxFit.contain,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),



//                   const SizedBox(height: 24),
//                   const Text(
//                     'Quick Actions',
//                     style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                   ),
//                   const SizedBox(height: 8),
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                     children: [
//                       _actionButton('New Customer', Icons.person_add, orange, onTap: () {
//                         Navigator.push(context,
//                             MaterialPageRoute(builder: (context) => CustomerOnboardingPage()));
//                       }),
//                       _actionButton('Upload Doc', Icons.upload_file, orange),
//                       _actionButton('View Tasks', Icons.task, orange),
//                     ],
//                   ),
//                   const SizedBox(height: 20),
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                     children: [
//                       _actionButton('Chats', Icons.chat, orange, onTap: () {
//                         Navigator.push(context, MaterialPageRoute(builder: (context) => Chats()));
//                       }),
//                       _actionButton('Leads', Icons.read_more, orange, onTap: () {
//                         Navigator.push(context,
//                             MaterialPageRoute(builder: (context) => LeadsTasksPage()));
//                       }),
//                       _actionButton('Reports', Icons.report, orange, onTap: () {
//                         Navigator.push(context,
//                             MaterialPageRoute(builder: (context) => ReportsPage()));
//                       }),
//                     ],
//                   ),
//                   const SizedBox(height: 20),
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                     children: [
//                       _actionButton('Settings', Icons.settings, orange, onTap: () {
//                         Navigator.push(
//                             context, MaterialPageRoute(builder: (context) => SettingsPage()));
//                       }),
//                       _actionButton('Vault', Icons.edit_document, orange, onTap: () {
//                         Navigator.push(context,
//                             MaterialPageRoute(builder: (context) => DocumentVaultPage()));
//                       }),
//                       _actionButton('More', Icons.more, orange),
//                     ],
//                   ),
//                   const SizedBox(height: 24),

//                   const Text('Notifications',
//                       style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//                   const SizedBox(height: 8),
//                   ListView(
//                     shrinkWrap: true,
//                     physics: const NeverScrollableScrollPhysics(),
//                     children: [
//                       _notificationTile('Lead approved: Yohane Banda'),
//                       _notificationTile('Document rejected: ID Scan'),
//                       _notificationTile('New message from supervisor'),
//                     ],
//                   ),
//                   const SizedBox(height: 16),
//                   const Text('Summary',
//                       style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//                   const SizedBox(height: 8),
//                   const AutoScrollingSummary(color: orange),
//                   const SizedBox(height: 24),
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       _statusIndicator('Geo-presence: Active', Icons.location_on, Colors.green),
//                       _statusIndicator('Sync: Online', Icons.sync, Colors.blue),
//                     ],
//                   ),
//                   const SizedBox(height: 24),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   // ================= Helper Widgets =================
//   Widget _actionButton(String label, IconData icon, Color color,
//       {VoidCallback? onTap}) {
//     return Column(
//       children: [
//         ElevatedButton(
//           style: ElevatedButton.styleFrom(
//             backgroundColor: color,
//             foregroundColor: Colors.white,
//             shape: const CircleBorder(),
//             padding: const EdgeInsets.all(16),
//           ),
//           onPressed: onTap,
//           child: Icon(icon),
//         ),
//         const SizedBox(height: 4),
//         Text(label, style: const TextStyle(fontSize: 12)),
//       ],
//     );
//   }

//   Widget _notificationTile(String message) {
//     return ListTile(
//       leading: const Icon(Icons.notifications, color: Colors.orange),
//       title: Text(message),
//     );
//   }

//   Widget _statusIndicator(String label, IconData icon, Color color) {
//     return Row(
//       children: [
//         Icon(icon, color: color),
//         const SizedBox(width: 4),
//         Text(label),
//       ],
//     );
//   }
// }

// // ================= AutoScrollingSummary =================
// class AutoScrollingSummary extends StatefulWidget {
//   final Color color;
//   const AutoScrollingSummary({required this.color});

//   @override
//   State<AutoScrollingSummary> createState() => _AutoScrollingSummaryState();
// }

// class _AutoScrollingSummaryState extends State<AutoScrollingSummary> {
//   final ScrollController _scrollController = ScrollController();
//   final List<Map<String, String>> _cards = [
//     {'title': 'Active Leads', 'count': '12'},
//     {'title': 'Tasks Today', 'count': '5'},
//     {'title': 'Pending Verifications', 'count': '3'},
//   ];

//   late Timer _scrollTimer;

//   @override
//   void initState() {
//     super.initState();
//     _startAutoScroll();
//   }

//   void _startAutoScroll() {
//     const scrollStep = 1.0;
//     const scrollInterval = Duration(milliseconds: 50);

//     _scrollTimer = Timer.periodic(scrollInterval, (_) {
//       if (_scrollController.hasClients) {
//         final maxScroll = _scrollController.position.maxScrollExtent;
//         final currentScroll = _scrollController.offset;

//         if (currentScroll >= maxScroll) {
//           _scrollController.jumpTo(0);
//         } else {
//           _scrollController.jumpTo(currentScroll + scrollStep);
//         }
//       }
//     });
//   }

//   @override
//   void dispose() {
//     _scrollTimer.cancel();
//     _scrollController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return SizedBox(
//       height: 110,
//       child: ListView.builder(
//         controller: _scrollController,
//         scrollDirection: Axis.horizontal,
//         itemCount: _cards.length * 1000,
//         itemBuilder: (context, index) {
//           final card = _cards[index % _cards.length];
//           return Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 8),
//             child: _summaryCard(card['title']!, card['count']!, widget.color),
//           );
//         },
//       ),
//     );
//   }

//   Widget _summaryCard(String title, String count, Color color) {
//     return Card(
//       elevation: 2,
//       child: Container(
//         height: 100,
//         width: 160,
//         padding: const EdgeInsets.all(12),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Text(count,
//                 style: TextStyle(
//                     fontSize: 24, fontWeight: FontWeight.bold, color: color)),
//             const SizedBox(height: 4),
//             Text(title, textAlign: TextAlign.center),
//           ],
//         ),
//       ),
//     );
//   }
// }
