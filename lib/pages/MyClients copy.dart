// import 'dart:async';
// import 'dart:convert';

// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:http/http.dart' as http;

// import 'package:pfs_agent/pages/AnalogSignUp.dart';
// import 'package:pfs_agent/pages/DigitalSignUp.dart';

// import '../config/api_config.dart';
// import '../layouts/Colors.dart';

// import 'database/digital_registration_db.dart';
// import 'database_helper.dart';

// import 'ClentPreview.dart';
// import 'DigitalClientPreview.dart';

// class MyClients extends StatefulWidget {
//   const MyClients({super.key});

//   @override
//   MyClientsState createState() => MyClientsState();
// }

// class MyClientsState extends State<MyClients> with WidgetsBindingObserver {
//   bool listAvailable = false;
//   List<Map<String, dynamic>> _clients = [];

//   // filter
//   String _selectedFilter = 'all';

//   // header image
//   final String _headerImage = 'assets/images/back1.png';

//   // polling
//   Timer? _pollTimer;
//   bool _pollingInProgress = false;

//   // ✅ LIVE INDICATOR: true = ok, false = offline/error
//   bool _isLive = false;

//   final String _statusUrl = "${ApiConfig.baseUrl}/registrations/status";

//   // server cache (id -> status/reason)
//   final Map<String, String> _statusByServerId = {};
//   final Map<String, String> _statusReasonByServerId = {};

//   // local lookup maps (serverId -> local row id)
//   final Map<String, int> _analogIdToRow = {};
//   final Map<String, int> _digitalIdToRow = {};

//   // debug
//   String? _lastRawResponse;

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addObserver(this);

//     // Load once, then start polling on the SAME page (no navigation needed)
//     _bootstrap();
//   }

//   Future<void> _bootstrap() async {
//     await _loadClients(); // local data
//     await _rebuildIdMaps(); // maps used for DB updates
//     _startPolling(); // every 2 seconds on this page
//   }

//   @override
//   void dispose() {
//     _stopPolling();
//     WidgetsBinding.instance.removeObserver(this);
//     super.dispose();
//   }

//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     // pause polling when app is backgrounded to avoid wasted network
//     if (state == AppLifecycleState.resumed) {
//       _startPolling(immediate: true);
//     } else if (state == AppLifecycleState.paused ||
//         state == AppLifecycleState.inactive ||
//         state == AppLifecycleState.detached) {
//       _stopPolling();
//     }
//   }

//   // ========================= POLLING =========================

//   void _startPolling({bool immediate = true}) {
//     _stopPolling();

//     if (immediate) {
//       // fire immediately so the user sees updates without waiting
//       // ignore: discarded_futures
//       _pollAndSyncStatuses();
//     }

//     _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
//       // ignore: discarded_futures
//       _pollAndSyncStatuses();
//     });
//   }

//   void _stopPolling() {
//     _pollTimer?.cancel();
//     _pollTimer = null;
//   }

//   Future<String?> _getToken() async {
//     final prefs = await SharedPreferences.getInstance();
//     return prefs.getString('token');
//   }

//   String _normalizeStatus(String? raw) {
//     final s = (raw ?? '').toString().toLowerCase().trim();
//     if (s == 'bounce') return 'bounced';
//     return s;
//   }

//   /// Extract the SAME "server id" you used when sending to /registrations/status.
//   /// (From your code: you collect id_number for analog and id_number/id for digital)
//   String? _extractServerIdFromClient(Map<String, dynamic> client) {
//     final source = client['source']?.toString() ?? 'analog';

//     if (source == 'digital') {
//       final dataRaw = client['data'];
//       if (dataRaw == null) return null;

//       try {
//         final decoded = jsonDecode(dataRaw.toString());
//         if (decoded is Map<String, dynamic>) {
//           final id = decoded['id_number'] ?? decoded['id'];
//           final s = id?.toString().trim();
//           if (s != null && s.isNotEmpty) return s;
//         }
//       } catch (_) {}
//     } else {
//       final formDataRaw = client['form_data'];
//       if (formDataRaw == null) return null;

//       try {
//         final decoded = jsonDecode(formDataRaw.toString());
//         if (decoded is Map<String, dynamic>) {
//           final id = decoded['id_number'];
//           final s = id?.toString().trim();
//           if (s != null && s.isNotEmpty) return s;
//         }
//       } catch (_) {}
//     }

//     return null;
//   }

//   String _getEffectiveStatus(Map<String, dynamic> client) {
//     final localStatus = _normalizeStatus(client['status']?.toString());
//     if (localStatus == 'draft') return localStatus;

//     final serverId = _extractServerIdFromClient(client);
//     if (serverId != null) {
//       final serverStatus = _statusByServerId[serverId];
//       if (serverStatus != null && serverStatus.trim().isNotEmpty) {
//         return serverStatus;
//       }
//     }
//     return localStatus;
//   }

//   String? _getReasonForClient(Map<String, dynamic> client) {
//     final status = _normalizeStatus(_getEffectiveStatus(client));
//     if (status != 'rejected' && status != 'bounced' && status != 'denied') {
//       return null;
//     }

//     final serverId = _extractServerIdFromClient(client);
//     if (serverId != null) {
//       final cached = _statusReasonByServerId[serverId];
//       if (cached != null && cached.trim().isNotEmpty) return cached;
//     }

//     final localReason = client['reason'];
//     if (localReason != null && localReason.toString().trim().isNotEmpty) {
//       return localReason.toString().trim();
//     }
//     return null;
//   }

//   Future<void> _rebuildIdMaps() async {
//     _analogIdToRow.clear();
//     _digitalIdToRow.clear();

//     // analog
//     final analogRows = await DatabaseHelper.instance.getData();
//     for (final r in analogRows) {
//       final formDataRaw = r['form_data'];
//       if (formDataRaw == null) continue;

//       try {
//         final parsed = jsonDecode(formDataRaw.toString());
//         if (parsed is Map<String, dynamic>) {
//           final createdId = parsed['id_number']?.toString().trim();
//           if (createdId == null || createdId.isEmpty) continue;

//           final rowIdRaw = r['id'];
//           final rowId =
//               rowIdRaw is int ? rowIdRaw : int.tryParse(rowIdRaw.toString());
//           if (rowId != null) _analogIdToRow[createdId] = rowId;
//         }
//       } catch (_) {}
//     }

//     // digital
//     final digitalRegs = await DigitalRegistrationDb.instance.getAll();
//     for (final reg in digitalRegs) {
//       try {
//         dynamic parsed;
//         if (reg.data is String) {
//           parsed = jsonDecode(reg.data as String);
//         } else {
//           parsed = reg.data;
//         }

//         if (parsed is Map<String, dynamic>) {
//           final createdId =
//               (parsed['id_number'] ?? parsed['id'])?.toString().trim();
//           if (createdId == null || createdId.isEmpty) continue;

//           if (reg.id != null) _digitalIdToRow[createdId] = reg.id!;
//         }
//       } catch (_) {}
//     }
//   }

//   Future<List<String>> _collectServerIds() async {
//     // ✅ IMPORTANT:
//     // Don’t re-read DB every 2 seconds (slow).
//     // Use the already-loaded _clients list.
//     final ids = <String>{};

//     for (final c in _clients) {
//       final id = _extractServerIdFromClient(c);
//       if (id != null && id.isNotEmpty) ids.add(id);
//     }

//     return ids.toList();
//   }

//   Future<void> _pollAndSyncStatuses() async {
//     if (_pollingInProgress) return;
//     if (!mounted) return;

//     _pollingInProgress = true;

//     try {
//       // No clients? Nothing to poll.
//       if (_clients.isEmpty) {
//         if (mounted) {
//           setState(() => _isLive = true); // page is OK; nothing to poll
//         }
//         return;
//       }

//       final ids = await _collectServerIds();
//       if (ids.isEmpty) {
//         if (mounted) {
//           setState(() => _isLive = true);
//         }
//         return;
//       }

//       final token = await _getToken();
//       final headers = <String, String>{
//         'Accept': 'application/json',
//         'Content-Type': 'application/json',
//         if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
//       };

//       final body = jsonEncode({'registration_ids': ids});

//       final response = await http
//           .post(Uri.parse(_statusUrl), headers: headers, body: body)
//           .timeout(const Duration(seconds: 6));

//       _lastRawResponse = response.body;

//       if (response.statusCode < 200 || response.statusCode >= 300) {
//         if (mounted) {
//           setState(() => _isLive = false);
//         }
//         return;
//       }

//       dynamic decoded;
//       try {
//         decoded = jsonDecode(response.body);
//       } catch (_) {
//         if (mounted) {
//           setState(() => _isLive = false);
//         }
//         return;
//       }

//       if (decoded is! Map<String, dynamic>) {
//         if (mounted) {
//           setState(() => _isLive = false);
//         }
//         return;
//       }

//       final dataRaw = decoded['data'];
//       if (dataRaw is! List) {
//         if (mounted) {
//           setState(() => _isLive = false);
//         }
//         return;
//       }

//       // ✅ if we got here: polling worked
//       if (mounted) {
//         setState(() => _isLive = true);
//       }

//       bool anyUiChange = false;
//       bool anyDbChange = false;

//       // For faster in-place UI updates, we update:
//       // 1) server caches (_statusByServerId/_statusReasonByServerId)
//       // 2) local DB statuses (so other screens also show correct status)
//       // 3) in-memory _clients list status values (so you see change instantly, no navigation)
//       for (final item in dataRaw) {
//         if (item is! Map) continue;

//         final serverId = item['id']?.toString().trim();
//         final serverStatusRaw = item['status']?.toString();
//         if (serverId == null ||
//             serverId.isEmpty ||
//             serverStatusRaw == null) continue;

//         final serverStatus = _normalizeStatus(serverStatusRaw);
//         final prior = _statusByServerId[serverId];
//         if (prior != serverStatus) {
//           _statusByServerId[serverId] = serverStatus;
//           anyUiChange = true;
//         } else {
//           // still keep cache populated
//           _statusByServerId[serverId] = serverStatus;
//         }

//         final reasonRaw = item['reason']?.toString();
//         if (reasonRaw != null && reasonRaw.trim().isNotEmpty) {
//           final reason = reasonRaw.trim();
//           final priorReason = _statusReasonByServerId[serverId];
//           if (priorReason != reason) {
//             _statusReasonByServerId[serverId] = reason;
//             anyUiChange = true;
//           } else {
//             _statusReasonByServerId[serverId] = reason;
//           }
//         }

//         // === Update local DB rows (analog + digital) if changed ===
//         final analogRowId = _analogIdToRow[serverId];
//         if (analogRowId != null) {
//           final currentLocal = _findLocalClientStatusByServerId(serverId);
//           if (currentLocal == null || currentLocal != serverStatus) {
//             await DatabaseHelper.instance.updateStatus(analogRowId, serverStatus);
//             anyDbChange = true;
//           }
//         }

//         final digitalLocalId = _digitalIdToRow[serverId];
//         if (digitalLocalId != null) {
//           final currentLocal = _findLocalClientStatusByServerId(serverId);
//           if (currentLocal == null || currentLocal != serverStatus) {
//             await DigitalRegistrationDb.instance
//                 .updateStatus(digitalLocalId, serverStatus);
//             anyDbChange = true;
//           }
//         }

//         // === Update the in-memory list so UI changes immediately ===
//         final updated = _applyStatusToInMemoryClient(serverId, serverStatus);
//         if (updated) anyUiChange = true;
//       }

//       // If DB changed a lot (e.g. new records or deletions), reload list and rebuild maps.
//       if (anyDbChange) {
//         await _loadClients();
//         await _rebuildIdMaps();
//         anyUiChange = true;
//       }

//       if (anyUiChange && mounted) {
//         setState(() {});
//       }
//     } on TimeoutException {
//       if (mounted) setState(() => _isLive = false);
//     } catch (_) {
//       if (mounted) setState(() => _isLive = false);
//     } finally {
//       _pollingInProgress = false;
//     }
//   }

//   String? _findLocalClientStatusByServerId(String serverId) {
//     for (final c in _clients) {
//       final id = _extractServerIdFromClient(c);
//       if (id == serverId) {
//         return _normalizeStatus(c['status']?.toString());
//       }
//     }
//     return null;
//   }

//   bool _applyStatusToInMemoryClient(String serverId, String newStatus) {
//     bool changed = false;

//     for (int i = 0; i < _clients.length; i++) {
//       final c = _clients[i];
//       final id = _extractServerIdFromClient(c);
//       if (id != serverId) continue;

//       final current = _normalizeStatus(c['status']?.toString());
//       // don't override drafts
//       if (current == 'draft') continue;

//       if (current != newStatus) {
//         _clients[i] = {
//           ...c,
//           'status': newStatus,
//         };
//         changed = true;
//       }
//     }

//     return changed;
//   }

//   // ========================= LOAD CLIENTS =========================

//   Future<void> _loadClients() async {
//     // 1) analog
//     final analog = await DatabaseHelper.instance.getData();
//     final analogWithSource = analog
//         .map<Map<String, dynamic>>((c) => {
//               ...c,
//               'status': _normalizeStatus(c['status']?.toString()),
//               'source': 'analog',
//             })
//         .toList();

//     // 2) digital
//     final digitalRegs = await DigitalRegistrationDb.instance.getAll();
//     final digital = digitalRegs.map<Map<String, dynamic>>((reg) {
//       return {
//         'id': reg.id,
//         'status': _normalizeStatus(reg.status?.toString()),
//         'data': jsonEncode(reg.data),
//         'source': 'digital',
//       };
//     }).toList();

//     if (!mounted) return;

//     setState(() {
//       _clients = [...analogWithSource, ...digital];
//       listAvailable = _clients.isNotEmpty;
//     });
//   }

//   // ========================= UI HELPERS =========================

//   String _getClientName(Map<String, dynamic> client) {
//     final info = client['information'];
//     if (info != null && info.toString().trim().isNotEmpty) {
//       return info.toString().trim();
//     }

//     final dataRaw = client['data'];
//     if (dataRaw != null && dataRaw.toString().trim().isNotEmpty) {
//       try {
//         final decoded = jsonDecode(dataRaw.toString());
//         if (decoded is Map<String, dynamic>) {
//           final title = (decoded['titleValue'] ?? '').toString().trim();
//           final firstName = (decoded['firstName'] ?? '').toString().trim();
//           final surname = (decoded['surname'] ?? '').toString().trim();

//           final parts =
//               [title, firstName, surname].where((p) => p.isNotEmpty).toList();
//           if (parts.isNotEmpty) return parts.join(' ');
//         }
//       } catch (_) {}
//     }

//     return "No Name";
//   }

//   Future<void> _editClient(int id, String currentInfo) async {
//     final controller = TextEditingController(text: currentInfo);

//     await showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//         title: Text(
//           "Edit Client",
//           style: TextStyle(
//             fontWeight: FontWeight.w600,
//             color: AppColors.textPrimary,
//           ),
//         ),
//         content: TextField(
//           controller: controller,
//           decoration: InputDecoration(
//             labelText: "Client name",
//             hintText: "Enter new name",
//             border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child:
//                 Text("Cancel", style: TextStyle(color: AppColors.textSecondary)),
//           ),
//           ElevatedButton(
//             style: ElevatedButton.styleFrom(
//               backgroundColor: AppColors.primary,
//               foregroundColor: Colors.white,
//               shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(12)),
//             ),
//             onPressed: () async {
//               if (controller.text.trim().isEmpty) return;

//               await DatabaseHelper.instance
//                   .updateData(id, controller.text.trim());
//               if (!mounted) return;

//               Navigator.pop(context);
//               await _loadClients();
//               await _rebuildIdMaps();

//               ScaffoldMessenger.of(context).showSnackBar(
//                 SnackBar(
//                   content: const Text("Client updated successfully"),
//                   backgroundColor: AppColors.success,
//                 ),
//               );
//             },
//             child: const Text("Save"),
//           ),
//         ],
//       ),
//     );
//   }

//   Future<void> _deleteClient(Map<String, dynamic> client) async {
//     final int? id = client['id'] as int?;
//     if (id == null) return;

//     final source = client['source']?.toString() ?? 'analog';

//     if (source == 'digital') {
//       await DigitalRegistrationDb.instance.delete(id);
//     } else {
//       await DatabaseHelper.instance.deleteData(id);
//     }

//     await _loadClients();
//     await _rebuildIdMaps();

//     if (!mounted) return;

//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: const Text("Client deleted"),
//         backgroundColor: AppColors.danger,
//       ),
//     );
//   }

//   void _showEditDeleteOptions(Map<String, dynamic> client) {
//     final source = client['source']?.toString() ?? 'analog';

//     showModalBottomSheet(
//       context: context,
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//       ),
//       builder: (context) {
//         return SafeArea(
//           child: Padding(
//             padding: const EdgeInsets.symmetric(vertical: 8.0),
//             child: Wrap(
//               children: [
//                 Container(
//                   alignment: Alignment.center,
//                   padding: const EdgeInsets.symmetric(vertical: 6),
//                   child: Container(
//                     width: 40,
//                     height: 4,
//                     decoration: BoxDecoration(
//                       color: Colors.grey.shade300,
//                       borderRadius: BorderRadius.circular(2),
//                     ),
//                   ),
//                 ),
//                 if (source == 'analog')
//                   ListTile(
//                     leading: Icon(Icons.edit, color: AppColors.primary),
//                     title: const Text("Edit name"),
//                     onTap: () {
//                       Navigator.pop(context);
//                       _editClient(client['id'], client['information'] ?? "");
//                     },
//                   ),
//                 ListTile(
//                   leading: const Icon(Icons.delete, color: AppColors.danger),
//                   title: const Text("Delete"),
//                   onTap: () {
//                     Navigator.pop(context);
//                     _deleteClient(client);
//                   },
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }

//   void _showSignUpOptions(BuildContext context) {
//     showModalBottomSheet(
//       context: context,
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//       ),
//       builder: (context) {
//         return SafeArea(
//           child: Padding(
//             padding: const EdgeInsets.all(20),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Center(
//                   child: Container(
//                     width: 40,
//                     height: 4,
//                     margin: const EdgeInsets.only(bottom: 16),
//                     decoration: BoxDecoration(
//                       color: Colors.grey.shade300,
//                       borderRadius: BorderRadius.circular(2),
//                     ),
//                   ),
//                 ),
//                 Text(
//                   "Client registration method",
//                   style: TextStyle(
//                     fontSize: 18,
//                     fontWeight: FontWeight.bold,
//                     color: AppColors.textPrimary,
//                   ),
//                 ),
//                 const SizedBox(height: 6),
//                 Text(
//                   "Choose how you would like to register this client.",
//                   style:
//                       TextStyle(fontSize: 14, color: AppColors.textSecondary),
//                 ),
//                 const SizedBox(height: 20),
//                 ListTile(
//                   leading: CircleAvatar(
//                     backgroundColor: AppColors.primary.withOpacity(0.1),
//                     child: const Icon(Icons.phone_android,
//                         color: AppColors.primary),
//                   ),
//                   title: const Text("Digital registration"),
//                   subtitle:
//                       const Text("Capture details directly in the application"),
//                   onTap: () {
//                     Navigator.pop(context);
//                     Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                           builder: (context) => const DigitalSignUp()),
//                     ).then((_) async {
//                       await _loadClients();
//                       await _rebuildIdMaps();
//                       _startPolling(immediate: true);
//                     });
//                   },
//                 ),
//                 const SizedBox(height: 8),
//                 ListTile(
//                   leading: CircleAvatar(
//                     backgroundColor: AppColors.secondary.withOpacity(0.1),
//                     child: const Icon(Icons.camera_alt,
//                         color: AppColors.secondary),
//                   ),
//                   title: const Text("Forms upload"),
//                   subtitle:
//                       const Text("Upload scanned/photographed registration"),
//                   onTap: () {
//                     Navigator.pop(context);
//                     Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                           builder: (context) => const AnalogSignUp()),
//                     ).then((_) async {
//                       await _loadClients();
//                       await _rebuildIdMaps();
//                       _startPolling(immediate: true);
//                     });
//                   },
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }

//   void _openClient(Map<String, dynamic> client) {
//     final status = _normalizeStatus(_getEffectiveStatus(client));
//     final reason = _getReasonForClient(client);
//     final source = client['source']?.toString() ?? 'analog';

//     if (status == 'draft') {
//       if (source == 'digital') {
//         Map<String, dynamic> draftData = {};
//         final dataRaw = client['data'];
//         if (dataRaw != null && dataRaw.toString().trim().isNotEmpty) {
//           try {
//             final decoded = jsonDecode(dataRaw.toString());
//             if (decoded is Map<String, dynamic>) draftData = decoded;
//           } catch (_) {}
//         }

//         Navigator.push(
//           context,
//           MaterialPageRoute(
//             builder: (_) => DigitalSignUp(
//               draftData: draftData,
//               localId: client['id'] as int?,
//             ),
//           ),
//         ).then((_) async {
//           await _loadClients();
//           await _rebuildIdMaps();
//           _startPolling(immediate: true);
//         });
//       } else {
//         Navigator.push(
//           context,
//           MaterialPageRoute(builder: (_) => AnalogSignUp(draftClient: client)),
//         ).then((_) async {
//           await _loadClients();
//           await _rebuildIdMaps();
//           _startPolling(immediate: true);
//         });
//       }
//       return;
//     }

//     // not draft
//     if (source == 'digital') {
//       Map<String, dynamic> data = {};
//       final dataRaw = client['data'];

//       if (dataRaw != null && dataRaw.toString().trim().isNotEmpty) {
//         try {
//           final decoded = jsonDecode(dataRaw.toString());
//           if (decoded is Map<String, dynamic>) data = decoded;
//         } catch (_) {}
//       }

//       Navigator.push(
//         context,
//         MaterialPageRoute(
//           builder: (_) => DigitalClientPreview(
//             data: data,
//             status: status,
//             reason: reason,
//           ),
//         ),
//       ).then((_) {
//         _startPolling(immediate: true);
//       });
//     } else {
//       Navigator.push(
//         context,
//         MaterialPageRoute(
//           builder: (_) => ClientPreview(
//             client: client,
//             status: status,
//             reason: reason,
//           ),
//         ),
//       ).then((_) {
//         _startPolling(immediate: true);
//       });
//     }
//   }

//   Widget _buildEmptyState() {
//     return Center(
//       child: Padding(
//         padding: const EdgeInsets.all(32.0),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Icon(
//               Icons.folder_open,
//               size: 64,
//               color: AppColors.textSecondary.withOpacity(0.4),
//             ),
//             const SizedBox(height: 16),
//             Text(
//               "No clients yet",
//               style: TextStyle(
//                 fontSize: 20,
//                 fontWeight: FontWeight.w600,
//                 color: AppColors.textPrimary,
//               ),
//             ),
//             const SizedBox(height: 8),
//             Text(
//               "Start by registering a new client. You can use digital registration or upload scanned forms.",
//               textAlign: TextAlign.center,
//               style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
//             ),
//             const SizedBox(height: 24),
//             ElevatedButton.icon(
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: AppColors.primary,
//                 foregroundColor: Colors.white,
//                 padding:
//                     const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//                 shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(30)),
//               ),
//               onPressed: () => _showSignUpOptions(context),
//               icon: const Icon(Icons.person_add_outlined),
//               label: const Text("Add client"),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   // top bar
//   Widget _buildTopBar(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
//       child: Row(
//         children: [
//           const SizedBox(width: 6),
//           const Expanded(
//             child: Text(
//               "My Clients",
//               style: TextStyle(
//                 fontSize: 18,
//                 fontWeight: FontWeight.w700,
//                 color: Colors.white,
//               ),
//             ),
//           ),
//           IconButton(
//             style: ButtonStyle(
//               backgroundColor: MaterialStateProperty.all(AppColors.accent),
//               shape: MaterialStateProperty.all(const CircleBorder()),
//             ),
//             icon: const Icon(Icons.person_add, color: Colors.white),
//             onPressed: () => _showSignUpOptions(context),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildFilterBar() {
//     final items = [
//       {'key': 'all', 'label': 'All'},
//       {'key': 'approved', 'label': 'Approved'},
//       {'key': 'rejected', 'label': 'Rejected'},
//       {'key': 'bounced', 'label': 'Bounced'},
//       {'key': 'draft', 'label': 'Draft'},
//       {'key': 'pending', 'label': 'Pending'},
//     ];

//     return SizedBox(
//       height: 44,
//       child: SingleChildScrollView(
//         scrollDirection: Axis.horizontal,
//         physics: const BouncingScrollPhysics(),
//         padding: const EdgeInsets.symmetric(horizontal: 2),
//         child: Row(
//           children: items.map((it) {
//             final key = it['key']!;
//             final label = it['label']!;
//             final selected = _selectedFilter == key;

//             return Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 6),
//               child: ChoiceChip(
//                 label: Text(
//                   label,
//                   style: TextStyle(
//                     color: selected ? Colors.white : AppColors.textPrimary,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//                 selected: selected,
//                 onSelected: (_) => setState(() => _selectedFilter = key),
//                 selectedColor: AppColors.primary,
//                 backgroundColor: AppColors.cardBackground,
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(20),
//                   side: BorderSide(
//                     color: selected
//                         ? AppColors.primary
//                         : AppColors.primary.withOpacity(0.06),
//                   ),
//                 ),
//               ),
//             );
//           }).toList(),
//         ),
//       ),
//     );
//   }

//   List<Map<String, dynamic>> get _filteredClients {
//     if (_selectedFilter == 'all') return _clients;

//     final filter = _selectedFilter.toLowerCase().trim();

//     return _clients.where((client) {
//       final statusRaw = _normalizeStatus(_getEffectiveStatus(client));

//       if (filter == 'rejected') {
//         return statusRaw == 'rejected' || statusRaw == 'denied';
//       }

//       return statusRaw == filter;
//     }).toList();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppColors.background,
//       body: Stack(
//         children: [
//           Positioned(
//             left: 0,
//             right: 0,
//             top: 0,
//             child: SizedBox(
//               height: 220,
//               child: Image.asset(_headerImage, fit: BoxFit.cover),
//             ),
//           ),
//           Positioned(
//             left: 0,
//             right: 0,
//             top: 0,
//             child: Container(
//               height: 220,
//               decoration: const BoxDecoration(
//                 gradient: LinearGradient(
//                   colors: [Color(0xE6000000), Color(0x00000000)],
//                   begin: Alignment.bottomCenter,
//                   end: Alignment.topCenter,
//                 ),
//               ),
//             ),
//           ),
//           SafeArea(
//             child: Column(
//               children: [
//                 _buildTopBar(context),
//                 const SizedBox(height: 12),
//                 Expanded(
//                   child: Container(
//                     decoration: BoxDecoration(
//                       color: AppColors.background,
//                       borderRadius: const BorderRadius.vertical(
//                           top: Radius.circular(24)),
//                       boxShadow: [
//                         BoxShadow(
//                           color: Colors.black.withOpacity(0.12),
//                           blurRadius: 10,
//                           offset: const Offset(0, -2),
//                         ),
//                       ],
//                     ),
//                     child: Padding(
//                       padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
//                       child: listAvailable
//                           ? Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Row(
//                                   children: [
//                                     Text(
//                                       "Clients",
//                                       style: TextStyle(
//                                         fontSize: 18,
//                                         fontWeight: FontWeight.w600,
//                                         color: AppColors.textPrimary,
//                                       ),
//                                     ),
//                                     const SizedBox(width: 8),
//                                     Container(
//                                       padding: const EdgeInsets.symmetric(
//                                           horizontal: 10, vertical: 4),
//                                       decoration: BoxDecoration(
//                                         color:
//                                             AppColors.primary.withOpacity(0.1),
//                                         borderRadius: BorderRadius.circular(12),
//                                       ),
//                                       child: Text(
//                                         "${_clients.length}",
//                                         style: TextStyle(
//                                           fontSize: 12,
//                                           fontWeight: FontWeight.w600,
//                                           color: AppColors.primary,
//                                         ),
//                                       ),
//                                     ),
//                                     const Spacer(),

//                                     // ✅ LIVE/ERROR indicator (no spinner)
//                                     Container(
//                                       padding: const EdgeInsets.symmetric(
//                                           horizontal: 10, vertical: 6),
//                                       decoration: BoxDecoration(
//                                         color: AppColors.cardBackground,
//                                         borderRadius:
//                                             BorderRadius.circular(999),
//                                         border: Border.all(
//                                           color: AppColors.primary
//                                               .withOpacity(0.06),
//                                         ),
//                                       ),
//                                       child: Row(
//                                         mainAxisSize: MainAxisSize.min,
//                                         children: [
//                                           Container(
//                                             height: 18,
//                                             width: 18,
//                                             decoration: BoxDecoration(
//                                               color: _isLive
//                                                   ? Colors.green
//                                                   : Colors.red,
//                                               shape: BoxShape.circle,
//                                             ),
//                                             child: Icon(
//                                               _isLive
//                                                   ? Icons.check
//                                                   : Icons.close,
//                                               size: 12,
//                                               color: Colors.white,
//                                             ),
//                                           ),
//                                           const SizedBox(width: 8),
//                                           Text(
//                                             _isLive ? "Online" : "Offline",
//                                             style: TextStyle(
//                                               fontSize: 11,
//                                               fontWeight: FontWeight.w600,
//                                               color: _isLive
//                                                   ? Colors.green
//                                                   : Colors.red,
//                                             ),
//                                           ),
//                                         ],
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                                 const SizedBox(height: 8),
//                                 Text(
//                                   "Tap a client to view details or long press for more options.",
//                                   style: TextStyle(
//                                       fontSize: 12,
//                                       color: AppColors.textSecondary),
//                                 ),
//                                 const SizedBox(height: 12),
//                                 _buildFilterBar(),
//                                 const SizedBox(height: 12),
//                                 Expanded(
//                                   child: _filteredClients.isNotEmpty
//                                       ? ListView.separated(
//                                           physics:
//                                               const BouncingScrollPhysics(),
//                                           itemCount: _filteredClients.length,
//                                           separatorBuilder: (_, __) =>
//                                               const SizedBox(height: 4),
//                                           itemBuilder: (context, index) {
//                                             final client =
//                                                 _filteredClients[index];
//                                             return GestureDetector(
//                                               onLongPress: () =>
//                                                   _showEditDeleteOptions(
//                                                       client),
//                                               onTap: () => _openClient(client),
//                                               child: buildClientItem(
//                                                 _getClientName(client),
//                                                 _getEffectiveStatus(client),
//                                                 reason:
//                                                     _getReasonForClient(client),
//                                               ),
//                                             );
//                                           },
//                                         )
//                                       : Center(
//                                           child: Padding(
//                                             padding: const EdgeInsets.all(24.0),
//                                             child: Text(
//                                               "No clients in this category.",
//                                               style: TextStyle(
//                                                 fontSize: 14,
//                                                 color: AppColors.textSecondary,
//                                               ),
//                                             ),
//                                           ),
//                                         ),
//                                 ),
//                               ],
//                             )
//                           : _buildEmptyState(),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // ================= CLIENT ITEM CARD =================
// Widget buildClientItem(String name, String statusRaw, {String? reason}) {
//   final status = statusRaw.toString().toLowerCase().trim();

//   Color statusColor;
//   String label;

//   switch (status) {
//     case "approved":
//       statusColor = AppColors.success;
//       label = "Approved";
//       break;
//     case "denied":
//       statusColor = AppColors.danger;
//       label = "Denied";
//       break;
//     case "rejected":
//       statusColor = AppColors.danger;
//       label = "Rejected";
//       break;
//     case "bounced":
//       statusColor = AppColors.warning;
//       label = "Bounced";
//       break;
//     case "draft":
//       statusColor = AppColors.info;
//       label = "Draft";
//       break;
//     case "pending":
//     default:
//       if (status == 'bounce') {
//         statusColor = AppColors.warning;
//         label = "Bounced";
//       } else {
//         statusColor = AppColors.warning;
//         label = "Pending";
//       }
//   }

//   return Container(
//     margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
//     decoration: BoxDecoration(
//       color: AppColors.cardBackground,
//       borderRadius: BorderRadius.circular(18),
//       border: Border.all(color: AppColors.primary.withOpacity(0.06)),
//       boxShadow: [
//         BoxShadow(
//           color: Colors.black.withOpacity(0.06),
//           blurRadius: 8,
//           offset: const Offset(0, 4),
//         ),
//       ],
//     ),
//     child: Padding(
//       padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
//       child: Row(
//         children: [
//           Container(
//             width: 44,
//             height: 44,
//             decoration: BoxDecoration(
//               color: AppColors.primary.withOpacity(0.10),
//               borderRadius: BorderRadius.circular(14),
//             ),
//             child: const Icon(
//               Icons.person_outline,
//               size: 24,
//               color: AppColors.primary,
//             ),
//           ),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   name,
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                   style: TextStyle(
//                     fontSize: 15,
//                     fontWeight: FontWeight.w600,
//                     color: AppColors.textPrimary,
//                   ),
//                 ),
//                 const SizedBox(height: 4),
//                 Text(
//                   "Status: $label",
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                   style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
//                 ),
//                 if ((status == 'rejected' ||
//                         status == 'bounced' ||
//                         status == 'denied') &&
//                     reason != null &&
//                     reason.trim().isNotEmpty) ...[
//                   const SizedBox(height: 4),
//                   Text(
//                     "Reason: ${reason.trim()}",
//                     maxLines: 2,
//                     overflow: TextOverflow.ellipsis,
//                     style:
//                         TextStyle(fontSize: 11, color: AppColors.textSecondary),
//                   ),
//                 ],
//               ],
//             ),
//           ),
//           const SizedBox(width: 8),
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.end,
//             children: [
//               Container(
//                 padding:
//                     const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
//                 decoration: BoxDecoration(
//                   color: statusColor.withOpacity(0.12),
//                   borderRadius: BorderRadius.circular(20),
//                 ),
//                 child: Text(
//                   label,
//                   style: TextStyle(
//                     color: statusColor,
//                     fontSize: 11,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 6),
//               Icon(
//                 Icons.arrow_forward_ios_rounded,
//                 size: 14,
//                 color: AppColors.textSecondary.withOpacity(0.6),
//               ),
//             ],
//           ),
//         ],
//       ),
//     ),
//   );
// }
