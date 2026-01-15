// lib/pages/MyClients.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pfs_agent/pages/AnalogSignUp.dart';
import 'package:pfs_agent/pages/DigitalSignUp.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;


import '../config/api_config.dart';

import '../layouts/Colors.dart';
import 'database/digital_registration_db.dart';

import 'database_helper.dart';
import 'ClentPreview.dart';
import 'DigitalClientPreview.dart'; // adjust relative path if needed

class MyClients extends StatefulWidget {
  @override
  MyClientsState createState() => MyClientsState();
}

class MyClientsState extends State<MyClients> {
  bool listAvailable = false;
  List<Map<String, dynamic>> _clients = [];

  // NEW: currently selected filter (all / approved / rejected / bounce / draft / pending)
  String _selectedFilter = 'all';

  // Use same background image style as Dashboard
  final String _headerImage = 'assets/images/back1.png';

  // Polling timer
  Timer? _pollTimer;
  final String _statusUrl =
      ApiConfig.baseUrl+'/registrations/status';

  // Keep local maps to quickly find which local row corresponds to a server id
  // key: createdId (string), value: local row id (int)
  Map<String, int> _analogIdToRow = {};
  Map<String, int> _digitalIdToRow = {};

  // keep latest server response (optional debugging)
  String? _lastRawResponse;

  @override
  void initState() {
    super.initState();
    _loadClients().then((_) {
      // start polling after initial load
      _startPolling();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // keep clients refreshed if dependencies change
    _loadClients();
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }

  void _startPolling() {
    // If there's an existing timer, cancel it
    _stopPolling();
    // Poll every 5 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted) return;
      await _pollAndSyncStatuses();
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _loadClients() async {
    // 1) Load analog clients
    final analog = await DatabaseHelper.instance.getData();
    final analogWithSource = analog
        .map<Map<String, dynamic>>((c) => {
      ...c,
      'source': 'analog',
    })
        .toList();

    // 2) Load digital registrations
    final digitalRegs = await DigitalRegistrationDb.instance.getAll();
    final digital = digitalRegs.map<Map<String, dynamic>>((reg) {
      return {
        'id': reg.id,
        'status': reg.status,
        'data': jsonEncode(reg.data),
        'source': 'digital',
      };
    }).toList();

    if (!mounted) return;
    setState(() {
      _clients = [
        ...analogWithSource,
        ...digital,
      ];
      listAvailable = _clients.isNotEmpty;
    });
  }

  /// Build helper maps from server-created id -> local row id
  Future<void> _buildIdMaps() async {
    _analogIdToRow.clear();
    _digitalIdToRow.clear();

    // analog rows
    final analogRows = await DatabaseHelper.instance.getData();
    for (final r in analogRows) {
      final formDataRaw = r['form_data'];
      if (formDataRaw == null) continue;
      try {
        final parsed = json.decode(formDataRaw.toString());
        if (parsed is Map<String, dynamic>) {
          final createdId = parsed['id_number'];
          if (createdId != null) {
            final idStr = createdId.toString().trim();
            if (idStr.isNotEmpty) {
              final rowIdRaw = r['id'];
              if (rowIdRaw != null) {
                final rowId = rowIdRaw is int
                    ? rowIdRaw
                    : int.tryParse(rowIdRaw.toString());
                if (rowId != null) {
                  _analogIdToRow[idStr] = rowId;
                }
              }
            }
          }
        }
      } catch (e) {
        // ignore parse errors for that row
        print('Warning: failed to parse analog form_data for row ${r['id']}: $e');
      }
    }

    // digital rows
    final digitalRegs = await DigitalRegistrationDb.instance.getAll();
    for (final reg in digitalRegs) {
      try {
        dynamic parsed;
        if (reg.data is String) {
          parsed = json.decode(reg.data as String);
        } else {
          parsed = reg.data;
        }

        if (parsed is Map<String, dynamic>) {
          final createdId = parsed['id_number'] ?? parsed['id'];
          if (createdId != null) {
            final idStr = createdId.toString().trim();
            if (idStr.isNotEmpty) {
              final localId = reg.id; // local DB id for digital reg
              if (localId != null) {
                _digitalIdToRow[idStr] = localId;
              }
            }
          }
        }
      } catch (e) {
        print('Warning: failed to parse digital reg data for local id ${reg.id}: $e');
      }
    }

    // debug
    print('Analog id map: $_analogIdToRow');
    print('Digital id map: $_digitalIdToRow');
  }

  /// Collect server ids the same way testing did: read analog form_data.id_number and digital data.id_number
  Future<List<dynamic>> _collectServerIds() async {
    final ids = <dynamic>[];

    // analog
    final analogRows = await DatabaseHelper.instance.getData();
    for (final r in analogRows) {
      final formDataRaw = r['form_data'];
      if (formDataRaw == null) continue;
      try {
        final parsed = json.decode(formDataRaw.toString());
        if (parsed is Map<String, dynamic>) {
          final createdId = parsed['id_number'];
          if (createdId != null) {
            final idStr = createdId.toString().trim();
            if (idStr.isNotEmpty && !ids.contains(createdId)) ids.add(createdId);
          }
        }
      } catch (e) {
        // ignore per-row parse errors
        print('Failed to parse analog form_data for row id ${r['id']}: $e');
      }
    }

    // digital
    final digitalRegs = await DigitalRegistrationDb.instance.getAll();
    for (final reg in digitalRegs) {
      try {
        dynamic parsed;
        if (reg.data is String) {
          parsed = json.decode(reg.data as String);
        } else {
          parsed = reg.data;
        }
        if (parsed is Map<String, dynamic>) {
          final createdId = parsed['id_number'] ?? parsed['id'];
          if (createdId != null) {
            final idStr = createdId.toString().trim();
            if (idStr.isNotEmpty && !ids.contains(createdId)) ids.add(createdId);
          }
        }
      } catch (e) {
        print('Failed to parse digital reg data for local id ${reg.id}: $e');
      }
    }

    print('Collected server ids to check: $ids');
    return ids;
  }

  Future<void> _pollAndSyncStatuses() async {
    try {
      // Build maps for quick lookup when updating DB rows
      await _buildIdMaps();

      final ids = await _collectServerIds();
      if (ids.isEmpty) {
        // nothing to do
        return;
      }

      // prepare request
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final body = json.encode({'registration_ids': ids});
      print('Polling status - POST $_statusUrl');
      print('Headers: $headers');
      print('Body: $body');

      final response = await http
          .post(Uri.parse(_statusUrl), headers: headers, body: body)
          .timeout(const Duration(seconds: 15));

      print('Poll response status: ${response.statusCode}');
      print('Poll response body: ${response.body}');
      _lastRawResponse = response.body;

      if (response.statusCode < 200 || response.statusCode >= 300) {
        // server error — ignore this cycle but keep logs
        return;
      }

      Map<String, dynamic>? jsonResp;
      try {
        jsonResp = json.decode(response.body) as Map<String, dynamic>?;
      } catch (e) {
        print('Failed to decode poll JSON: $e');
        return;
      }

      if (jsonResp == null) return;

      final dataRaw = jsonResp['data'];
      if (dataRaw is! List) return;

      var anyChanged = false;

      // For each returned status item: { "id": 1, "status": "approved", "source": "upload" }
      for (final item in dataRaw) {
        if (item is! Map) continue;
        final serverId = item['id']?.toString();
        final serverStatusRaw = item['status']?.toString();
        if (serverId == null || serverStatusRaw == null) continue;
        final serverStatus = serverStatusRaw.toLowerCase().trim();

        // find local analog row (if any)
        if (_analogIdToRow.containsKey(serverId)) {
          final localRowId = _analogIdToRow[serverId]!;
          // find current local status — need to read row
          try {
            final rows = await DatabaseHelper.instance.getData();
            final matching = rows.where((r) {
              final rowForm = r['form_data'];
              if (rowForm == null) return false;
              try {
                final parsed = json.decode(rowForm.toString());
                if (parsed is Map<String, dynamic>) {
                  final created = parsed['id_number']?.toString();
                  return created == serverId;
                }
              } catch (_) {}
              return false;
            }).toList();

            final localRow = matching.isNotEmpty ? matching.first : null;
            final currentLocalStatus = (localRow != null && localRow.isNotEmpty) ? (localRow['status']?.toString() ?? '') : '';

            if (currentLocalStatus.toLowerCase() != serverStatus) {
              // update DB row status
              await DatabaseHelper.instance.updateStatus(localRowId, serverStatus);
              anyChanged = true;
              print('Updated analog row $localRowId status -> $serverStatus (server id $serverId)');
            }
          } catch (e) {
            print('Error updating analog status for serverId $serverId: $e');
          }
        }

        // find local digital row (if any)
        if (_digitalIdToRow.containsKey(serverId)) {
          final localDigitalId = _digitalIdToRow[serverId]!;
          try {
            // Read the digital record to compare status
            final digitalRegs = await DigitalRegistrationDb.instance.getAll();
            final matching = digitalRegs.where((r) {
              try {
                dynamic parsed;
                if (r.data is String) {
                  parsed = json.decode(r.data as String);
                } else {
                  parsed = r.data;
                }
                if (parsed is Map<String, dynamic>) {
                  final created = (parsed['id_number'] ?? parsed['id'])?.toString();
                  return created == serverId;
                }
              } catch (_) {}
              return false;
            }).toList();

            final localReg = matching.isNotEmpty ? matching.first : null;
            final currentLocalStatus = localReg != null ? (localReg.status?.toString() ?? '') : '';

            if (currentLocalStatus.toLowerCase() != serverStatus) {
              // Note: assume DigitalRegistrationDb has updateStatus(localId, newStatus)
              await DigitalRegistrationDb.instance.updateStatus(localDigitalId, serverStatus);
              anyChanged = true;
              print('Updated digital local id $localDigitalId status -> $serverStatus (server id $serverId)');
            }
          } catch (e) {
            print('Error updating digital status for serverId $serverId: $e');
          }
        }
      } // end for each item

      if (anyChanged) {
        // refresh clients and the UI
        await _loadClients();
      }
    } catch (e, st) {
      print('Exception in polling: $e\n$st');
      // ignore — we'll retry next tick
    }
  }

  /// 👇 smart name extractor
  String _getClientName(Map<String, dynamic> client) {
    final info = client['information'];
    if (info != null && info.toString().trim().isNotEmpty) {
      return info.toString().trim();
    }

    final dataRaw = client['data'];
    if (dataRaw != null && dataRaw.toString().trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(dataRaw.toString());
        if (decoded is Map<String, dynamic>) {
          final title = (decoded['titleValue'] ?? '').toString().trim();
          final firstName = (decoded['firstName'] ?? '').toString().trim();
          final surname = (decoded['surname'] ?? '').toString().trim();

          final parts =
          [title, firstName, surname].where((p) => p.isNotEmpty).toList();

          if (parts.isNotEmpty) {
            return parts.join(' ');
          }
        }
      } catch (_) {}
    }

    return "No Name";
  }

  Future<void> _editClient(int id, String currentInfo) async {
    TextEditingController _controller =
    TextEditingController(text: currentInfo);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          "Edit Client",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        content: TextField(
          controller: _controller,
          decoration: InputDecoration(
            labelText: "Client name",
            hintText: "Enter new name",
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Cancel",
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              if (_controller.text.trim().isEmpty) return;

              await DatabaseHelper.instance
                  .updateData(id, _controller.text.trim());
              Navigator.pop(context);
              _loadClients();

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Client updated successfully"),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteClient(Map<String, dynamic> client) async {
    final int? id = client['id'] as int?;
    if (id == null) return;

    final source = client['source']?.toString() ?? 'analog';

    if (source == 'digital') {
      await DigitalRegistrationDb.instance.delete(id);
    } else {
      await DatabaseHelper.instance.deleteData(id);
    }

    await _loadClients();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Client deleted"),
        backgroundColor: AppColors.danger,
      ),
    );
  }

  void _showEditDeleteOptions(Map<String, dynamic> client) {
    final source = client['source']?.toString() ?? 'analog';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Wrap(
              children: [
                Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                if (source == 'analog')
                  ListTile(
                    leading: Icon(Icons.edit, color: AppColors.primary),
                    title: const Text("Edit name"),
                    onTap: () {
                      Navigator.pop(context);
                      _editClient(client['id'], client['information'] ?? "");
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.delete, color: AppColors.danger),
                  title: const Text("Delete"),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteClient(client);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSignUpOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  "Client registration method",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Choose how you would like to register this client.",
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: const Icon(Icons.phone_android,
                        color: AppColors.primary),
                  ),
                  title: const Text("Digital registration"),
                  subtitle:
                  const Text("Capture details directly in the application"),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const DigitalSignUp()),
                    ).then((_) {
                      _loadClients();
                    });
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.secondary.withOpacity(0.1),
                    child:
                    const Icon(Icons.camera_alt, color: AppColors.secondary),
                  ),
                  title: const Text("Forms upload"),
                  subtitle:
                  const Text("Upload scanned/photographed registration"),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AnalogSignUp(),
                      ),
                    ).then((_) {
                      _loadClients();
                    });
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openClient(Map<String, dynamic> client) {
    final statusRaw = client['status'] ?? '';
    final status = statusRaw.toString().toLowerCase();
    final source = client['source']?.toString() ?? 'analog';

    if (status == 'draft') {
      if (source == 'digital') {
        Map<String, dynamic> draftData = {};
        final dataRaw = client['data'];

        if (dataRaw != null && dataRaw.toString().trim().isNotEmpty) {
          try {
            final decoded = jsonDecode(dataRaw.toString());
            if (decoded is Map<String, dynamic>) {
              draftData = decoded;
            }
          } catch (_) {}
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DigitalSignUp(
              draftData: draftData,
              localId: client['id'] as int?,
            ),
          ),
        ).then((_) => _loadClients());
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AnalogSignUp(draftClient: client),
          ),
        ).then((_) => _loadClients());
      }
    } else {
      if (source == 'digital') {
        Map<String, dynamic> data = {};
        final dataRaw = client['data'];

        if (dataRaw != null && dataRaw.toString().trim().isNotEmpty) {
          try {
            final decoded = jsonDecode(dataRaw.toString());
            if (decoded is Map<String, dynamic>) {
              data = decoded;
            }
          } catch (_) {}
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DigitalClientPreview(
              data: data,
              status: status,
            ),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClientPreview(client: client),
          ),
        );
      }
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_open,
              size: 64,
              color: AppColors.textSecondary.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              "No clients yet",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Start by registering a new client. You can use digital registration or upload scanned forms.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: () => _showSignUpOptions(context),
              icon: const Icon(Icons.person_add_outlined),
              label: const Text("Add client"),
            ),
          ],
        ),
      ),
    );
  }

  // 🔹 top bar over hero (back + title + add) – same “glass” feel as dashboard
  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      child: Row(
        children: [
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              "My Clients",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          IconButton(
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all(
                AppColors.accent,
              ),
              shape: MaterialStateProperty.all(
                const CircleBorder(),
              ),
            ),
            icon: const Icon(Icons.person_add, color: Colors.white),
            onPressed: () => _showSignUpOptions(context),
          ),
        ],
      ),
    );
  }

  // NEW: build horizontal filter bar
  Widget _buildFilterBar() {
    final items = [
      {'key': 'all', 'label': 'All'},
      {'key': 'approved', 'label': 'Approved'},
      {'key': 'rejected', 'label': 'Rejected'},
      {'key': 'bounce', 'label': 'Bounce'},
      {'key': 'draft', 'label': 'Draft'},
      {'key': 'pending', 'label': 'Pending'},
    ];

    return SizedBox(
      height: 44,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Row(
          children: items.map((it) {
            final key = it['key']!;
            final label = it['label']!;
            final bool selected = _selectedFilter == key;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: ChoiceChip(
                label: Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                selected: selected,
                onSelected: (_) {
                  setState(() {
                    _selectedFilter = key;
                  });
                },
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.cardBackground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: selected
                        ? AppColors.primary
                        : AppColors.primary.withOpacity(0.06),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // helper: returns clients filtered per _selectedFilter
  List<Map<String, dynamic>> get _filteredClients {
    if (_selectedFilter == 'all') return _clients;

    final filter = _selectedFilter.toLowerCase().trim();

    return _clients.where((client) {
      final statusRaw = (client['status'] ?? '').toString().toLowerCase().trim();

      // special: "rejected" filter should include both 'rejected' and 'denied'
      if (filter == 'rejected') {
        if (statusRaw == 'rejected' || statusRaw == 'denied') return true;
        return false;
      }

      // otherwise match exact status (e.g., approved, bounce, draft, pending)
      return statusRaw == filter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // 🔹 hero background like dashboard
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: SizedBox(
              height: 220,
              child: Image.asset(
                _headerImage,
                fit: BoxFit.cover,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              height: 220,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xE6000000),
                    Color(0x00000000),
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildTopBar(context),
                const SizedBox(height: 12),

                // 🔹 main content sheet – same “card from bottom” feel
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 10,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
                      child: listAvailable
                          ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                "Clients",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color:
                                  AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  "${_clients.length}",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Tap a client to view details or long press for more options.",
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // NEW: filter bar
                          _buildFilterBar(),
                          const SizedBox(height: 12),

                          Expanded(
                            child: _filteredClients.isNotEmpty
                                ? ListView.separated(
                              itemCount: _filteredClients.length,
                              separatorBuilder: (_, __) =>
                              const SizedBox(height: 4),
                              itemBuilder: (context, index) {
                                final client = _filteredClients[index];
                                return GestureDetector(
                                  onLongPress: () =>
                                      _showEditDeleteOptions(client),
                                  onTap: () => _openClient(client),
                                  child: _buildClientItem(
                                    _getClientName(client),
                                    client['status']?.toString() ??
                                        "pending",
                                  ),
                                );
                              },
                            )
                                : Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Text(
                                  "No clients in this category.",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                          : _buildEmptyState(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ================= CLIENT ITEM CARD (same visual style) =================
Widget _buildClientItem(String name, String statusRaw) {
  final status = statusRaw.toString().toLowerCase();

  Color statusColor;
  String label;

  switch (status) {
    case "approved":
      statusColor = AppColors.success;
      label = "Approved";
      break;
    case "denied":
      statusColor = AppColors.danger;
      label = "Denied";
      break;
    case "rejected": // 👈 NEW SUPPORT
      statusColor = AppColors.danger;
      label = "Rejected"; // 👈 Display nicely
      break;

    case "draft":
      statusColor = AppColors.info;
      label = "Draft";
      break;
    case "pending":
    default:
    // include bounce as pending fallback if not recognized
      if (status == 'bounce') {
        statusColor = AppColors.warning;
        label = "Bounce";
      } else {
        statusColor = AppColors.warning;
        label = "Pending";
      }
  }

  return Container(
    margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
    decoration: BoxDecoration(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: AppColors.primary.withOpacity(0.06),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: Row(
        children: [
          // leading avatar/icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.person_outline,
              size: 24,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),

          // name + small status text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Status: $label",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // status pill + arrow
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: AppColors.textSecondary.withOpacity(0.6),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
