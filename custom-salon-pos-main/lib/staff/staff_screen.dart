import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../constants/app_currency.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../utils/responsive_layout.dart';

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  final List<String> _roles = [
    'Barber',
    'Stylist',
    'Receptionist',
    'Manager',
    'Admin',
  ];

  String _currencySymbol(BuildContext context) =>
      context.read<AppProvider>().settings['currencySymbol'] ??
          kDefaultCurrencySymbol;

  String _staffNameById(AppProvider provider, String? staffId) {
    if (staffId == null || staffId.isEmpty) return 'Unknown';
    final i = provider.staff.indexWhere((s) => s.id == staffId);
    return i >= 0 ? provider.staff[i].name : 'Staff #$staffId';
  }

  ({int jobs, Set<String> clients}) _staffJobsAndClients(
    AppProvider provider,
    StaffProfile staff,
  ) {
    int jobs = 0;
    final clients = <String>{};
    final target = staff.name.trim().toLowerCase();

    for (final tx in provider.transactions) {
      final customer = tx.customerName.trim().isEmpty
          ? 'Walk-in Customer'
          : tx.customerName.trim();
      bool countedThisTx = false;

      if (tx.items.isNotEmpty) {
        for (final item in tx.items) {
          if (item.assignedStaff.trim().toLowerCase() == target) {
            jobs++;
            countedThisTx = true;
          }
        }
      } else {
        // Stored format example: "Haircut [Staff: Ali] | Beard [Staff: Ahmed]"
        final raw = tx.servicesSummary;
        if (raw.isNotEmpty) {
          final parts = raw.split('|');
          for (final p in parts) {
            final marker = '[Staff:';
            final idx = p.toLowerCase().indexOf(marker.toLowerCase());
            if (idx >= 0) {
              final after = p.substring(idx + marker.length);
              final endIdx = after.indexOf(']');
              final assigned = (endIdx >= 0 ? after.substring(0, endIdx) : after)
                  .trim()
                  .toLowerCase();
              if (assigned == target) {
                jobs++;
                countedThisTx = true;
              }
            } else if (tx.staffName.trim().toLowerCase() == target) {
              jobs++;
              countedThisTx = true;
            }
          }
        } else if (tx.staffName.trim().toLowerCase() == target) {
          jobs++;
          countedThisTx = true;
        }
      }

      if (countedThisTx) {
        clients.add(customer);
      }
    }

    return (jobs: jobs, clients: clients);
  }

  List<({
    DateTime date,
    String customer,
    String paymentMethod,
    double billTotal,
    int jobsInBill,
    String services,
  })> _staffJobDetails(AppProvider provider, StaffProfile staff) {
    final target = staff.name.trim().toLowerCase();
    final result = <({
      DateTime date,
      String customer,
      String paymentMethod,
      double billTotal,
      int jobsInBill,
      String services,
    })>[];

    for (final tx in provider.transactions) {
      int jobsInBill = 0;
      final matchedServices = <String>[];

      if (tx.items.isNotEmpty) {
        for (final item in tx.items) {
          if (item.assignedStaff.trim().toLowerCase() == target) {
            jobsInBill++;
            matchedServices.add(item.service.name);
          }
        }
      } else {
        final raw = tx.servicesSummary.trim();
        if (raw.isNotEmpty) {
          final parts = raw.split('|');
          for (final p in parts) {
            final piece = p.trim();
            final marker = '[Staff:';
            final idx = piece.toLowerCase().indexOf(marker.toLowerCase());
            if (idx >= 0) {
              final serviceName = piece.substring(0, idx).trim();
              final after = piece.substring(idx + marker.length);
              final endIdx = after.indexOf(']');
              final assigned = (endIdx >= 0 ? after.substring(0, endIdx) : after)
                  .trim()
                  .toLowerCase();
              if (assigned == target) {
                jobsInBill++;
                matchedServices.add(serviceName.isEmpty ? 'Service' : serviceName);
              }
            }
          }
        }
        if (jobsInBill == 0 && tx.staffName.trim().toLowerCase() == target) {
          jobsInBill = 1;
          matchedServices.add(raw.isEmpty ? 'Service' : raw);
        }
      }

      if (jobsInBill > 0) {
        result.add((
          date: tx.date,
          customer: tx.customerName.trim().isEmpty
              ? 'Walk-in Customer'
              : tx.customerName.trim(),
          paymentMethod: tx.paymentMethod.trim().isEmpty
              ? 'Cash'
              : tx.paymentMethod.trim(),
          billTotal: tx.total,
          jobsInBill: jobsInBill,
          services: matchedServices.join(', '),
        ));
      }
    }

    result.sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  ({int jobs, double sales}) _staffMonthJobsSales(
    AppProvider provider,
    StaffProfile staff,
  ) {
    final target = staff.name.trim().toLowerCase();
    final now = DateTime.now();
    int jobs = 0;
    double sales = 0;

    for (final tx in provider.transactions) {
      if (tx.date.year != now.year || tx.date.month != now.month) continue;

      int jobsInBill = 0;
      int totalServicesInBill = 0;

      if (tx.items.isNotEmpty) {
        totalServicesInBill = tx.items.length;
        for (final item in tx.items) {
          if (item.assignedStaff.trim().toLowerCase() == target) {
            jobsInBill++;
          }
        }
      } else {
        final raw = tx.servicesSummary.trim();
        if (raw.isNotEmpty) {
          final parts = raw.split('|');
          totalServicesInBill = parts.length;
          for (final p in parts) {
            final piece = p.trim();
            final marker = '[Staff:';
            final idx = piece.toLowerCase().indexOf(marker.toLowerCase());
            if (idx >= 0) {
              final after = piece.substring(idx + marker.length);
              final endIdx = after.indexOf(']');
              final assigned = (endIdx >= 0 ? after.substring(0, endIdx) : after)
                  .trim()
                  .toLowerCase();
              if (assigned == target) {
                jobsInBill++;
              }
            }
          }
        } else {
          totalServicesInBill = 1;
        }

        if (jobsInBill == 0 && tx.staffName.trim().toLowerCase() == target) {
          jobsInBill = 1;
        }
      }

      if (jobsInBill > 0) {
        jobs += jobsInBill;
        final denom = totalServicesInBill <= 0 ? jobsInBill : totalServicesInBill;
        sales += tx.total * (jobsInBill / denom);
      }
    }

    return (jobs: jobs, sales: sales);
  }

  void _showJobsAndClientsDialog(AppProvider provider, StaffProfile staff) {
    final stats = _staffJobsAndClients(provider, staff);
    final sortedClients = stats.clients.toList()..sort();
    final details = _staffJobDetails(provider, staff);
    final currency = _currencySymbol(context);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${staff.name} - Job Details'),
        content: SizedBox(
          width: 760,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total jobs handled: ${stats.jobs}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'Clients served: ${sortedClients.length}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Bills handled',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (details.isEmpty)
                Text(
                  'No client records found for this staff yet.',
                  style: TextStyle(color: Colors.grey[400]),
                )
              else
                SizedBox(
                  height: 280,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Date')),
                        DataColumn(label: Text('Customer')),
                        DataColumn(label: Text('Jobs')),
                        DataColumn(label: Text('Services')),
                        DataColumn(label: Text('Bill Total')),
                        DataColumn(label: Text('Payment')),
                      ],
                      rows: details.map((d) {
                        final date =
                            '${d.date.year}-${d.date.month.toString().padLeft(2, '0')}-${d.date.day.toString().padLeft(2, '0')}';
                        return DataRow(
                          cells: [
                            DataCell(Text(date)),
                            DataCell(Text(d.customer)),
                            DataCell(Text(d.jobsInBill.toString())),
                            DataCell(
                              SizedBox(
                                width: 200,
                                child: Text(
                                  d.services,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(
                              Text('$currency${d.billTotal.toStringAsFixed(2)}'),
                            ),
                            DataCell(Text(d.paymentMethod)),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _staffAvatarKey(String staffId) => 'staffAvatar_$staffId';

  Future<void> _pickStaffAvatar(StaffProfile staff) async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Avatar upload is available on desktop/mobile app.'),
        ),
      );
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
      );
      if (result == null || result.files.isEmpty) return;

      final imagePath = result.files.single.path;
      if (imagePath == null || imagePath.isEmpty) return;

      await context.read<AppProvider>().saveSettings({
        _staffAvatarKey(staff.id): imagePath,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Avatar updated for ${staff.name}.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update avatar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildStaffAvatar(AppProvider provider, StaffProfile staff) {
    final avatarPath = provider.settings[_staffAvatarKey(staff.id)];
    var hasImage = false;
    String? resolvedPath;
    if (avatarPath != null && avatarPath.isNotEmpty) {
      try {
        if (File(avatarPath).existsSync()) {
          hasImage = true;
          resolvedPath = avatarPath;
        }
      } catch (_) {
        hasImage = false;
      }
    }

    return CircleAvatar(
      backgroundColor: Colors.white10,
      backgroundImage:
          hasImage && resolvedPath != null ? FileImage(File(resolvedPath)) : null,
      child: hasImage
          ? null
          : Text(
              staff.name.isNotEmpty ? staff.name[0].toUpperCase() : 'U',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
    );
  }

  void _showMarkAttendanceDialog(StaffProfile staff) {
    final selectedStaff = staff;
    String status = 'Present';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSB) {
          return AlertDialog(
            title: Text('Mark Attendance: ${selectedStaff.name}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Select today\'s status:'),
                const SizedBox(height: 16),
                InputDecorator(
                  decoration: const InputDecoration(labelText: 'Status'),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: status,
                      isExpanded: true,
                      items: ['Present', 'Absent', 'Half Day', 'Leave']
                          .map(
                            (s) => DropdownMenuItem(value: s, child: Text(s)),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setStateSB(() => status = v);
                      },
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final app = context.read<AppProvider>();
                  await app.markAttendanceForStaff(
                    selectedStaff,
                    status,
                  );
                  if (!mounted || !ctx.mounted) return;
                  Navigator.pop(ctx);
                  messenger.showSnackBar(
                    SnackBar(content: Text('Marked as $status')),
                  );
                },
                child: const Text('Save Record'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showPaymentDialog(bool isAdvance, StaffProfile staff) {
    final selectedStaff = staff;
    final amountCtrl = TextEditingController();
    final sym = _currencySymbol(context);
    final payroll = context.read<AppProvider>().payrollForStaff(selectedStaff);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(
            isAdvance ? 'Record Advance Payment' : 'Process Salary Payment',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Payable this month: $sym${payroll.payableNow.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Amount ($sym)'),
              ),
              const SizedBox(height: 8),
              if (isAdvance)
                const Text(
                  'Advance taken will be automatically deducted from the final outstanding payable.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text);
                if (amount != null && amount > 0) {
                  final messenger = ScaffoldMessenger.of(context);
                  final app = context.read<AppProvider>();
                  await app.recordStaffPayment(
                    selectedStaff,
                    amount,
                    isAdvance: isAdvance,
                  );
                  if (!mounted || !ctx.mounted) return;
                  Navigator.pop(ctx);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        '$sym${amount.toStringAsFixed(2)} logged successfully!',
                      ),
                    ),
                  );
                }
              },
              child: const Text('Confirm Payment'),
            ),
          ],
        );
      },
    );
  }

  void _showAddEditStaffDialog([StaffProfile? s]) {
    final sym = _currencySymbol(context);
    final isEditing = s != null;
    final nameCtrl = TextEditingController(text: s?.name ?? '');
    final phoneCtrl = TextEditingController(text: s?.phone ?? '');
    final cnicCtrl = TextEditingController(text: s?.cnic ?? '');
    final addressCtrl = TextEditingController(text: s?.address ?? '');
    final emergencyCtrl = TextEditingController(
      text: s?.emergencyContact ?? '',
    );
    final baseCtrl = TextEditingController(
      text: s?.baseSalary.toString() ?? '',
    );
    final commCtrl = TextEditingController(
      text: s?.commissionRate.toString() ?? '',
    );

    String role = s?.role ?? _roles[0];
    PaymentStructure structure =
        s?.structure ?? PaymentStructure.commissionOnly;
    bool isPercent = s?.isCommissionPercentage ?? true;
    bool isActive = s?.isActive ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSB) {
          return AlertDialog(
            title: Text(isEditing ? 'Edit Staff Profile' : 'Add New Staff'),
            content: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Basic Information',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blueAccent,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Full Name',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: role,
                            decoration: const InputDecoration(
                              labelText: 'Role',
                            ),
                            items: _roles
                                .map(
                                  (r) => DropdownMenuItem(
                                    value: r,
                                    child: Text(r),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setStateSB(() => role = v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: phoneCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Phone Number',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: emergencyCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Emergency Contact',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: cnicCtrl,
                            decoration: const InputDecoration(
                              labelText: 'CNIC / ID Number',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: addressCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Home Address',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Payroll Configuration',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blueAccent,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<PaymentStructure>(
                      initialValue: structure,
                      decoration: const InputDecoration(
                        labelText: 'Payment Structure',
                      ),
                      items: PaymentStructure.values.map((v) {
                        String name = '';
                        switch (v) {
                          case PaymentStructure.commissionOnly:
                            name = 'Commission Only';
                            break;
                          case PaymentStructure.fixedSalary:
                            name = 'Fixed Monthly';
                            break;
                          case PaymentStructure.dailyWage:
                            name = 'Daily Wage';
                            break;
                          case PaymentStructure.hybrid:
                            name = 'Hybrid (Base + Comm)';
                            break;
                        }
                        return DropdownMenuItem(value: v, child: Text(name));
                      }).toList(),
                      onChanged: (v) => setStateSB(() => structure = v!),
                    ),
                    const SizedBox(height: 12),
                    if (structure == PaymentStructure.fixedSalary ||
                        structure == PaymentStructure.dailyWage ||
                        structure == PaymentStructure.hybrid)
                      TextField(
                        controller: baseCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Base Amount ($sym / period)',
                        ),
                      ),
                    if (structure == PaymentStructure.commissionOnly ||
                        structure == PaymentStructure.hybrid) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: commCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Commission Amount',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Row(
                              children: [
                                Switch(
                                  value: isPercent,
                                  onChanged: (v) =>
                                      setStateSB(() => isPercent = v),
                                  activeThumbColor: Theme.of(
                                    context,
                                  ).primaryColor,
                                ),
                                Text(
                                  isPercent
                                      ? 'Percentage (%)'
                                      : 'Fixed Flat ($sym)',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                    SwitchListTile(
                      title: const Text('Staff Account Active'),
                      subtitle: const Text(
                        'Toggle to deactivate former employees (hides from billing)',
                      ),
                      value: isActive,
                      activeThumbColor: Colors.green,
                      onChanged: (v) => setStateSB(() => isActive = v),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final provider = context.read<AppProvider>();
                  if (isEditing) {
                    s.name = nameCtrl.text;
                    s.role = role;
                    s.phone = phoneCtrl.text;
                    s.cnic = cnicCtrl.text;
                    s.address = addressCtrl.text;
                    s.emergencyContact = emergencyCtrl.text;
                    s.structure = structure;
                    s.isActive = isActive;
                    s.baseSalary = double.tryParse(baseCtrl.text) ?? 0;
                    s.commissionRate = double.tryParse(commCtrl.text) ?? 0;
                    s.isCommissionPercentage = isPercent;
                    final ok = await provider.updateStaffItem(s);
                    if (!context.mounted) return;
                    if (!ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Could not save: invalid staff id. Re-add this staff member if needed.',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                  } else {
                    final newS = StaffProfile(
                      id: DateTime.now().toString(),
                      name: nameCtrl.text,
                      role: role,
                      phone: phoneCtrl.text,
                      cnic: cnicCtrl.text,
                      address: addressCtrl.text,
                      emergencyContact: emergencyCtrl.text,
                      structure: structure,
                      isActive: isActive,
                      joinDate: DateTime.now(),
                      baseSalary: double.tryParse(baseCtrl.text) ?? 0,
                      commissionRate: double.tryParse(commCtrl.text) ?? 0,
                      isCommissionPercentage: isPercent,
                    );
                    await provider.addStaff(newS);
                    if (!context.mounted) return;
                  }
                  Navigator.pop(ctx);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Staff record saved!')),
                  );
                },
                child: const Text('Save Profile'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _formatCsvDate(DateTime d) {
    // Stable ISO-like text date for exports (never timestamp).
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String _excelTextDateCell(DateTime d) {
    // Force text in Excel CSV import to avoid:
    // 1) serial number conversion
    // 2) date display as #### when Excel applies date type
    return '="${_formatCsvDate(d)}"';
  }

  String _csvEscape(String input) {
    final cleaned = input.replaceAll('"', '""');
    return '"$cleaned"';
  }

  Future<void> _exportAttendanceCsv(AppProvider provider) async {
    if (provider.attendance.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No attendance records to export.')),
      );
      return;
    }

    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('CSV export is available on desktop/mobile app.'),
        ),
      );
      return;
    }

    try {
      final rows = <String>[
        'staff_id,staff_name,date,status',
      ];
      final entries = List<AttendanceRecord>.from(provider.attendance)
        ..sort((a, b) => b.date.compareTo(a.date));
      for (final e in entries) {
        final name = _staffNameById(provider, e.staffId);
        rows.add(
          '${_csvEscape(e.staffId ?? '')}'
          ',${_csvEscape(name)}'
          ',${_excelTextDateCell(e.date)}'
          ',${_csvEscape(e.status)}',
        );
      }

      final targetDir =
          await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final filePath =
          '${targetDir.path}${Platform.pathSeparator}attendance_export_$ts.csv';
      final file = File(filePath);
      // Add BOM and CRLF to improve Excel CSV compatibility on Windows.
      await file.writeAsString('\uFEFF${rows.join('\r\n')}');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Attendance CSV exported: ${file.path}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not export attendance CSV: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAttendanceLogSheet(AppProvider provider) {
    final entries = List<AttendanceRecord>.from(provider.attendance)
      ..sort((a, b) => b.date.compareTo(a.date));
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(ctx).height * 0.65,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Attendance log',
                          style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: entries.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'No attendance records yet. Use the row menu (⋮) → Mark Attendance, or open Active staff.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: entries.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final e = entries[i];
                            final name = _staffNameById(provider, e.staffId);
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.white12,
                                child: Text(
                                  e.status.isNotEmpty
                                      ? e.status[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(name),
                              subtitle: Text(
                                '${_formatDate(e.date)} · ${e.status}',
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showActiveStaffSheet(AppProvider provider) {
    final active = provider.staff.where((s) => s.isActive).toList();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(ctx).height * 0.55,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Active staff (${active.length})',
                          style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: active.isEmpty
                      ? const Center(child: Text('No active staff members.'))
                      : ListView.separated(
                          itemCount: active.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final s = active[i];
                            return ListTile(
                              leading: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () => _pickStaffAvatar(s),
                                child: _buildStaffAvatar(provider, s),
                              ),
                              title: Text(s.name),
                              subtitle: Text(
                                '${s.role} · ${s.phone.isNotEmpty ? s.phone : 'N/A'}',
                              ),
                              trailing: TextButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _showMarkAttendanceDialog(s);
                                },
                                child: const Text('Attendance'),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showServicesMonthSummary(AppProvider provider, String currency) {
    final activeStaff = provider.staff.where((s) => s.isActive).toList();
    final now = DateTime.now();

    List<({
      DateTime date,
      String customer,
      String paymentMethod,
      double billTotal,
      int jobsInBill,
      String services,
    })> monthDetails(StaffProfile s) {
      return _staffJobDetails(provider, s).where((d) {
        return d.date.year == now.year && d.date.month == now.month;
      }).toList();
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Services & sales (this month)'),
        content: SizedBox(
          width: 880,
          child: activeStaff.isEmpty
              ? const Text('No active staff.')
              : SingleChildScrollView(
                  child: Column(
                    children: activeStaff.map((s) {
                      final totals = _staffMonthJobsSales(provider, s);
                      final details = monthDetails(s);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ExpansionTile(
                          title: Text(
                            '${s.name}: ${totals.jobs} services, $currency${totals.sales.toStringAsFixed(2)} sales',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          children: [
                            if (details.isEmpty)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'No tracked records for this month.',
                                    style: TextStyle(color: Colors.grey[400]),
                                  ),
                                ),
                              )
                            else
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columns: const [
                                    DataColumn(label: Text('Date')),
                                    DataColumn(label: Text('Customer')),
                                    DataColumn(label: Text('Package / Service')),
                                    DataColumn(label: Text('Jobs')),
                                    DataColumn(label: Text('Bill')),
                                    DataColumn(label: Text('Payment')),
                                  ],
                                  rows: details.map((d) {
                                    final date =
                                        '${d.date.year}-${d.date.month.toString().padLeft(2, '0')}-${d.date.day.toString().padLeft(2, '0')}';
                                    return DataRow(
                                      cells: [
                                        DataCell(Text(date)),
                                        DataCell(Text(d.customer)),
                                        DataCell(
                                          SizedBox(
                                            width: 260,
                                            child: Text(
                                              d.services,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                        DataCell(Text(d.jobsInBill.toString())),
                                        DataCell(
                                          Text(
                                            '$currency${d.billTotal.toStringAsFixed(2)}',
                                          ),
                                        ),
                                        DataCell(Text(d.paymentMethod)),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            const SizedBox(height: 6),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showPayrollDueBreakdown(AppProvider provider, String currency) {
    final activeStaff = provider.staff.where((s) => s.isActive).toList();
    final buf = StringBuffer();
    for (final s in activeStaff) {
      final p = provider.payrollForStaff(s);
      buf.writeln(
        '${s.name}: $currency${p.payableNow.toStringAsFixed(2)}',
      );
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Payroll due by staff (this month)'),
        content: SingleChildScrollView(
          child: Text(
            buf.isEmpty
                ? 'No active staff.'
                : buf.toString().trimRight(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final currency =
        provider.settings['currencySymbol'] ?? kDefaultCurrencySymbol;
    return Padding(
      padding: AppBreakpoints.pagePadding(context),
      child: LayoutBuilder(
        builder: (context, c) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(provider, currency, c.maxWidth),
              const SizedBox(height: 24),
              Expanded(child: _buildStaffTable(provider, currency, c.maxWidth)),
              const SizedBox(height: 24),
              _buildPayrollCards(provider, currency, c.maxWidth),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(
    AppProvider provider,
    String currency,
    double viewportWidth,
  ) {
    final narrow = viewportWidth < AppBreakpoints.mobile;
    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload staff & attendance',
            onPressed: () async {
              await provider.loadAttendance();
              await provider.loadStaff();
            },
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => _showAttendanceLogSheet(provider),
          icon: const Icon(Icons.fact_check_outlined, size: 20),
          label: Text(narrow ? 'Attendance' : 'Attendance log'),
        ),
        OutlinedButton.icon(
          onPressed: () => _exportAttendanceCsv(provider),
          icon: const Icon(Icons.download_rounded, size: 20),
          label: Text(narrow ? 'CSV' : 'Export CSV'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF6231),
            padding: EdgeInsets.symmetric(
              horizontal: narrow ? 14 : 20,
              vertical: narrow ? 12 : 16,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text(
            'Add Staff',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          onPressed: () => _showAddEditStaffDialog(),
        ),
      ],
    );

    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Staff Management',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          actions,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Staff Management',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        actions,
      ],
    );
  }

  Widget _buildStaffTable(
    AppProvider provider,
    String currency,
    double viewportWidth,
  ) {
    final staffList = provider.staff;
    // Horizontal scroll must give the inner Row a *bounded* max width, or
    // `Expanded` children throw (unbounded width from minWidth-only constraints).
    final tableWidth = viewportWidth < 900 ? 900.0 : viewportWidth;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white12)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: tableWidth,
                child: Row(
                  children: [
                    const Expanded(
                  flex: 3,
                  child: Text(
                    'NAME',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Expanded(
                  flex: 2,
                  child: Text(
                    'PHONE',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Expanded(
                  flex: 2,
                  child: Text(
                    'ROLE',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Expanded(
                  flex: 2,
                  child: Text(
                    'ATTENDANCE (M)',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Expanded(
                  flex: 2,
                  child: Text(
                    'PAYABLE (M)',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'ACTIONS',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: platformIsWide(context)
                            ? TextAlign.right
                            : TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: staffList.length,
              separatorBuilder: (ctx, i) =>
                  const Divider(color: Colors.white12, height: 1),
              itemBuilder: (ctx, i) {
                final s = staffList[i];
                final payroll = provider.payrollForStaff(s);
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: tableWidth,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 12.0,
                      ),
                      child: Row(
                        children: [
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => _pickStaffAvatar(s),
                              child: _buildStaffAvatar(provider, s),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                s.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          s.phone.isNotEmpty ? s.phone : 'N/A',
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: s.role == 'Admin'
                                  ? Colors.redAccent.withOpacity(0.2)
                                  : Colors.blueAccent.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              s.role,
                              style: TextStyle(
                                color: s.role == 'Admin'
                                    ? Colors.redAccent
                                    : Colors.blueAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          (() {
                            final stats = _staffJobsAndClients(provider, s);
                            return 'P:${payroll.presentDays} H:${payroll.halfDays} A:${payroll.absentDays} · Jobs:${stats.jobs}';
                          })(),
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '$currency${payroll.payableNow.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: payroll.payableNow >= 0
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Row(
                          mainAxisAlignment: platformIsWide(context)
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.edit,
                                size: 18,
                                color: Colors.grey,
                              ),
                              onPressed: () => _showAddEditStaffDialog(s),
                            ),
                            MenuAnchor(
                              builder: (context, controller, child) {
                                return IconButton(
                                  icon: const Icon(
                                    Icons.more_vert,
                                    size: 20,
                                    color: Colors.grey,
                                  ),
                                  tooltip: 'More actions',
                                  onPressed: () {
                                    if (controller.isOpen) {
                                      controller.close();
                                    } else {
                                      controller.open();
                                    }
                                  },
                                );
                              },
                              menuChildren: [
                                MenuItemButton(
                                  onPressed: () =>
                                      _showMarkAttendanceDialog(s),
                                  child: const Text('Mark Attendance'),
                                ),
                                MenuItemButton(
                                  onPressed: () =>
                                      _showPaymentDialog(false, s),
                                  child: const Text('Process Salary'),
                                ),
                                MenuItemButton(
                                  onPressed: () =>
                                      _showPaymentDialog(true, s),
                                  child: const Text('Record Advance'),
                                ),
                                MenuItemButton(
                                  onPressed: () =>
                                      _showJobsAndClientsDialog(provider, s),
                                  child: const Text('Jobs & Clients'),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: Colors.redAccent,
                              ),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Delete Staff?'),
                                    content: const Text(
                                      'Are you sure you want to delete this staff member?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                        ),
                                        onPressed: () {
                                          provider.deleteStaff(s);
                                          Navigator.pop(ctx);
                                        },
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool platformIsWide(BuildContext context) =>
      MediaQuery.of(context).size.width > 800;

  Widget _buildPayrollCards(
    AppProvider provider,
    String currency,
    double viewportWidth,
  ) {
    final activeStaff = provider.staff.where((s) => s.isActive).toList();
    final snapshots = activeStaff.map(provider.payrollForStaff).toList();
    final totalPayable = snapshots.fold<double>(
      0,
      (sum, p) => sum + p.payableNow,
    );
    int totalServices = 0;
    double totalSales = 0;
    for (final s in activeStaff) {
      final j = _staffMonthJobsSales(provider, s);
      totalServices += j.jobs;
      totalSales += j.sales;
    }

    final gap = viewportWidth < AppBreakpoints.mobile ? 12.0 : 16.0;

    if (viewportWidth < AppBreakpoints.mobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RoleCard(
            title: 'Active Staff',
            desc: '${activeStaff.length} currently active — tap to list',
            color: Colors.blueAccent,
            icon: Icons.groups,
            onTap: () => _showActiveStaffSheet(provider),
          ),
          SizedBox(height: gap),
          _RoleCard(
            title: 'Total Services (M)',
            desc:
                '$totalServices services\n$currency${totalSales.toStringAsFixed(2)} sales — tap for detail',
            color: Colors.orangeAccent,
            icon: Icons.trending_up,
            onTap: () => _showServicesMonthSummary(provider, currency),
          ),
          SizedBox(height: gap),
          _RoleCard(
            title: 'Payroll Due (M)',
            desc:
                '$currency${totalPayable.toStringAsFixed(2)}\nNet payable — tap for breakdown',
            color: totalPayable >= 0 ? Colors.greenAccent : Colors.redAccent,
            icon: Icons.payments_outlined,
            onTap: () => _showPayrollDueBreakdown(provider, currency),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _RoleCard(
            title: 'Active Staff',
            desc: '${activeStaff.length} currently active — tap to list',
            color: Colors.blueAccent,
            icon: Icons.groups,
            onTap: () => _showActiveStaffSheet(provider),
          ),
        ),
        SizedBox(width: gap),
        Expanded(
          child: _RoleCard(
            title: 'Total Services (M)',
            desc:
                '$totalServices services\n$currency${totalSales.toStringAsFixed(2)} sales — tap for detail',
            color: Colors.orangeAccent,
            icon: Icons.trending_up,
            onTap: () => _showServicesMonthSummary(provider, currency),
          ),
        ),
        SizedBox(width: gap),
        Expanded(
          child: _RoleCard(
            title: 'Payroll Due (M)',
            desc:
                '$currency${totalPayable.toStringAsFixed(2)}\nNet payable — tap for breakdown',
            color: totalPayable >= 0 ? Colors.greenAccent : Colors.redAccent,
            icon: Icons.payments_outlined,
            onTap: () => _showPayrollDueBreakdown(provider, currency),
          ),
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String desc;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;

  const _RoleCard({
    required this.title,
    required this.desc,
    required this.color,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).cardColor;
    final content = Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return Container(
        decoration: BoxDecoration(
          color: cardColor,
          border: Border.all(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: content,
      );
    }

    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            border: Border.all(color: color.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: content,
        ),
      ),
    );
  }
}
