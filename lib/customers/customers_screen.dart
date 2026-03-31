import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../utils/responsive_layout.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  String _searchQuery = '';
  String _filterCriteria = 'All'; // All, Gold Tier, High Spender, Recent Visit
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Using AppProvider for customers
  CustomerProfile? _selectedCustomer;

  List<TransactionRecord> _transactionsForCustomer(
    AppProvider provider,
    CustomerProfile customer,
  ) {
    final id = customer.id.trim();
    final name = customer.name.trim().toLowerCase();
    return provider.transactions.where((t) {
      if (t.customerId.trim() == id && id.isNotEmpty) return true;
      return t.customerName.trim().toLowerCase() == name && name.isNotEmpty;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  List<VisitRecord> _visitHistoryFromTransactions(
    AppProvider provider,
    CustomerProfile customer,
  ) {
    final txs = _transactionsForCustomer(provider, customer);
    final earnRate = double.tryParse(provider.settings['pointsEarnRate'] ?? '10') ?? 10;
    final loyaltyEnabled = (provider.settings['enableLoyalty'] ?? 'true') == 'true';
    return txs.map((t) {
      final points = loyaltyEnabled && earnRate > 0 ? (t.total / earnRate).toInt() : 0;
      final services = t.servicesSummary.trim().isEmpty ? 'Service' : t.servicesSummary;
      final staff = t.staffName.trim().isEmpty ? 'Not assigned' : t.staffName.trim();
      return VisitRecord(
        date: t.date,
        services: services,
        staff: staff,
        amountPaid: t.total,
        pointsEarned: points,
      );
    }).toList();
  }

  List<CustomerProfile> get _filteredCustomers {
    final appProvider = context.watch<AppProvider>();
    var list = appProvider.customers.where((c) {
      final query = _searchQuery.toLowerCase();
      final matchNamePhone =
          c.name.toLowerCase().contains(query) || c.phone.contains(query);
      return matchNamePhone;
    }).toList();

    switch (_filterCriteria) {
      case 'Gold Tier':
        list = list.where((c) => c.tier == 'Gold').toList();
        break;
      case 'Silver Tier':
        list = list.where((c) => c.tier == 'Silver').toList();
        break;
      case 'High Spender':
        list.sort((a, b) => b.totalSpent.compareTo(a.totalSpent));
        break;
      case 'Recent Visit':
        list.sort((a, b) {
          final dateA = a.history.isNotEmpty
              ? a.history.first.date
              : DateTime(2000);
          final dateB = b.history.isNotEmpty
              ? b.history.first.date
              : DateTime(2000);
          return dateB.compareTo(dateA);
        });
        break;
    }
    return list;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final customers = context.read<AppProvider>().customers;
      if (customers.isNotEmpty) {
        setState(() => _selectedCustomer = customers.first);
      }
    });
  }

  void _showAddEditDialog([CustomerProfile? c]) {
    final isEditing = c != null;
    final nameCtrl = TextEditingController(text: c?.name ?? '');
    final phoneCtrl = TextEditingController(text: c?.phone ?? '');
    final notesCtrl = TextEditingController(text: c?.notes ?? '');
    String gender = c?.gender ?? 'Male';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSB) {
          return AlertDialog(
            title: Text(isEditing ? 'Edit Customer' : 'Add New Customer'),
            content: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Full Name'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: gender,
                      decoration: const InputDecoration(labelText: 'Gender'),
                      items: ['Male', 'Female', 'Other']
                          .map(
                            (g) => DropdownMenuItem(value: g, child: Text(g)),
                          )
                          .toList(),
                      onChanged: (v) => setStateSB(() => gender = v!),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Notes / Preferences / Allergies',
                      ),
                    ),
                    if (!isEditing)
                      const Padding(
                        padding: EdgeInsets.only(top: 12.0),
                        child: Text(
                          'Date of birth and extra details can be edited from the profile dashboard later.',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
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
                  if (nameCtrl.text.isEmpty || phoneCtrl.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Name and Phone are required!'),
                      ),
                    );
                    return;
                  }

                  final provider = context.read<AppProvider>();
                  if (isEditing) {
                    c.name = nameCtrl.text;
                    c.phone = phoneCtrl.text;
                    c.gender = gender;
                    c.notes = notesCtrl.text;
                    final ok = await provider.updateCustomerItem(c);
                    if (!context.mounted) return;
                    if (!ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Could not update this profile (invalid record id). '
                            'Add the customer again or contact support.',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    final idx =
                        provider.customers.indexWhere((x) => x.id == c.id);
                    setState(() {
                      _selectedCustomer =
                          idx >= 0 ? provider.customers[idx] : c;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Customer updated successfully'),
                      ),
                    );
                  } else {
                    final newCust = CustomerProfile(
                      id: DateTime.now().toString(),
                      name: nameCtrl.text,
                      phone: phoneCtrl.text,
                      gender: gender,
                      notes: notesCtrl.text,
                      memberSince: DateTime.now(),
                    );
                    await provider.addCustomer(newCust);
                    if (!context.mounted) return;
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                      _filterCriteria = 'All';
                      final idx = provider.customers.indexWhere(
                        (x) => x.id == newCust.id,
                      );
                      _selectedCustomer =
                          idx >= 0 ? provider.customers[idx] : newCust;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('New customer added')),
                    );
                  }
                  Navigator.pop(ctx);
                },
                child: const Text('Save Customer'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppBreakpoints.pagePadding(context),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isSmall = constraints.maxWidth < AppBreakpoints.tablet;

          Widget leftPanel = Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Directory',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.person_add,
                          color: Colors.blueAccent,
                        ),
                        tooltip: 'Add Customer',
                        onPressed: () => _showAddEditDialog(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Colors.white24),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _searchQuery = val),
                        decoration: InputDecoration(
                          icon: Icon(Icons.search, color: Colors.grey[400]),
                          hintText: 'Search name or phone...',
                          border: InputBorder.none,
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 20),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _filterCriteria,
                          isExpanded: true,
                          dropdownColor: Theme.of(context).cardColor,
                          items:
                              [
                                    'All',
                                    'Gold Tier',
                                    'Silver Tier',
                                    'High Spender',
                                    'Recent Visit',
                                  ]
                                  .map(
                                    (f) => DropdownMenuItem(
                                      value: f,
                                      child: Text('Filter: $f'),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (val) =>
                              setState(() => _filterCriteria = val!),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: _filteredCustomers.length,
                    separatorBuilder: (ctx, i) =>
                        const Divider(height: 1, color: Colors.white12),
                    itemBuilder: (context, index) {
                      final cust = _filteredCustomers[index];
                      final isSelected = _selectedCustomer?.id == cust.id;
                      return ListTile(
                        selected: isSelected,
                        selectedTileColor: Theme.of(
                          context,
                        ).primaryColor.withValues(alpha: 0.1),
                        leading: CircleAvatar(
                          backgroundColor: cust.tierColor.withValues(
                            alpha: 0.2,
                          ),
                          child: Text(
                            cust.name[0],
                            style: TextStyle(
                              color: cust.tierColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          cust.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          cust.phone,
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : Colors.grey,
                        ),
                        onTap: () => setState(() => _selectedCustomer = cust),
                      );
                    },
                  ),
                ),
              ],
            ),
          );

          Widget rightPanel = _selectedCustomer == null
              ? Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text('Select a customer to view profile'),
                  ),
                )
              : _buildProfileDashboard(
                  _selectedCustomer!,
                  context.watch<AppProvider>(),
                );

          if (isSmall) {
            return Column(
              children: [
                Expanded(flex: 3, child: leftPanel),
                const SizedBox(height: 24),
                Expanded(flex: 5, child: rightPanel),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: leftPanel),
              const SizedBox(width: 24),
              Expanded(flex: 5, child: rightPanel),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProfileDashboard(CustomerProfile customer, AppProvider provider) {
    final currency = provider.settings['currencySymbol'] ?? '\$';
    final visits = _visitHistoryFromTransactions(provider, customer);
    final totalVisits = visits.length;
    final lifetimeValue = visits.fold<double>(0, (s, v) => s + v.amountPaid);
    final loyaltyEnabled = (provider.settings['enableLoyalty'] ?? 'true') == 'true';
    final earnRate = double.tryParse(provider.settings['pointsEarnRate'] ?? '10') ?? 10.0;
    int displayLoyaltyPoints = customer.loyaltyPoints;
    if (loyaltyEnabled &&
        displayLoyaltyPoints <= 0 &&
        lifetimeValue > 0 &&
        earnRate > 0) {
      // Fallback for legacy records where loyalty points were not persisted.
      displayLoyaltyPoints = (lifetimeValue / earnRate).toInt();
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          // PROFILE HEADER
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24),
            ),
            child: LayoutBuilder(
              builder: (context, lc) {
                final profileRow = Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor:
                          customer.tierColor.withValues(alpha: 0.2),
                      child: Text(
                        customer.name.substring(0, 1),
                        style: TextStyle(
                          color: customer.tierColor,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            customer.name,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
                            children: [
                              OutlinedButton.icon(
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(text: customer.phone),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Phone copied: ${customer.phone}',
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.sms, size: 16),
                                label: const Text('Send SMS'),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: Colors.blueAccent,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.grey,
                                ),
                                tooltip: 'Edit Profile',
                                onPressed: () => _showAddEditDialog(customer),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.redAccent,
                                ),
                                tooltip: 'Delete Customer',
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (cDialog) => AlertDialog(
                                      title: const Text('Delete Customer'),
                                      content: const Text(
                                        'Are you sure you want to delete this customer? This action cannot be undone.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(cDialog),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.redAccent,
                                          ),
                                          onPressed: () {
                                            context
                                                .read<AppProvider>()
                                                .deleteCustomer(customer);
                                            setState(() {
                                              if (_selectedCustomer?.id ==
                                                  customer.id) {
                                                final filtered =
                                                    _filteredCustomers;
                                                _selectedCustomer =
                                                    filtered.isNotEmpty
                                                    ? filtered.first
                                                    : null;
                                              }
                                            });
                                            Navigator.pop(cDialog);
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Customer deleted',
                                                ),
                                              ),
                                            );
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
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.phone, size: 16, color: Colors.grey[400]),
                          const SizedBox(width: 4),
                          Text(
                            customer.phone,
                            style: TextStyle(color: Colors.grey[400]),
                          ),
                          const SizedBox(width: 16),
                          Icon(Icons.cake, size: 16, color: Colors.grey[400]),
                          const SizedBox(width: 4),
                          Text(
                            customer.dob != null
                                ? '${customer.dob!.day}/${customer.dob!.month}/${customer.dob!.year}'
                                : 'Not set',
                            style: TextStyle(color: Colors.grey[400]),
                          ),
                          const SizedBox(width: 16),
                          Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Member since ${customer.memberSince.year}',
                            style: TextStyle(color: Colors.grey[400]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                  ],
                );
                if (lc.maxWidth < 520) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: 520,
                      child: profileRow,
                    ),
                  );
                }
                return profileRow;
              },
            ),
          ),
          const SizedBox(height: 24),

          // METRICS AND NOTES
          LayoutBuilder(
            builder: (context, constraints) {
              final isCardSmall = constraints.maxWidth < 600;

              Widget leftStats = Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            totalVisits.toString(),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Total Visits',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 40, color: Colors.white24),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            '$currency${lifetimeValue.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Lifetime Value',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 40, color: Colors.white24),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            loyaltyEnabled ? displayLoyaltyPoints.toString() : 'Off',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: loyaltyEnabled
                                  ? customer.tierColor
                                  : Colors.grey[500],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                loyaltyEnabled
                                    ? '${customer.tier} Tier'
                                    : 'Loyalty Disabled',
                                style: TextStyle(
                                  color: loyaltyEnabled
                                      ? customer.tierColor
                                      : Colors.grey[500],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );

              Widget rightNotes = Container(
                height: 120,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.notes, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Notes & Preferences',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Text(
                          customer.notes.isEmpty
                              ? 'No notes added.'
                              : customer.notes,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              );

              if (isCardSmall) {
                return Column(
                  children: [leftStats, const SizedBox(height: 16), rightNotes],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: leftStats),
                  const SizedBox(width: 24),
                  Expanded(flex: 2, child: rightNotes),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // VISIT HISTORY TABLE
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Visit History',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                if (visits.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                      child: Text(
                        'No past visits recorded.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingTextStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      columns: const [
                        DataColumn(label: Text('Date')),
                        DataColumn(label: Text('Services Taken')),
                        DataColumn(label: Text('Staff')),
                        DataColumn(label: Text('Amount Paid')),
                        DataColumn(label: Text('Points Earned')),
                      ],
                      rows: visits.map((h) {
                        return DataRow(
                          cells: [
                            DataCell(
                              Text(
                                '${h.date.day}/${h.date.month}/${h.date.year}',
                              ),
                            ),
                            DataCell(Text(h.services)),
                            DataCell(Text(h.staff)),
                            DataCell(
                              Text(
                                '$currency${h.amountPaid.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                '+${h.pointsEarned}',
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
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
