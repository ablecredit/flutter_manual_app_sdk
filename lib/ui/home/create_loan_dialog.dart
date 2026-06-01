import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../../data/repository/dropdown_items_repository.dart';

const _samplePayload = {
  'loan_reference': 'LN-REF-20260430-9012',
  'client_unique_id': 'CUST-20260430-9012',
  'product_id': 'MUT-IND-3065',
  'branch_id': 'ML1348',
  'source_system': '',
  'user_name': 'Field Agent',
  'branch_name': 'Bangalore Central',
  'business_profile': {
    'product': 'LAP',
    'business_model': 'Trading',
    'industry': 'Fashion Apparel',
  },
  'data': {
    'borrower_details': {
      'state_name': 'karnataka',
      'entity_type': 'individual',
      'name': 'Shwetanka Srivastava',
      'dob': '24/01/1988',
      'mobile': '8197837043',
      'owner_of_business': 'Yes',
    },
    'employment_details': {'nature_of_employment': 'Full-Time'},
    'loan_details': {
      'business_name': 'trends',
      'quantum': '500000',
      'tenure': '24',
    },
  },
};

class CreateLoanDialog extends StatefulWidget {
  const CreateLoanDialog({super.key});

  @override
  State<CreateLoanDialog> createState() => _CreateLoanDialogState();
}

class _CreateLoanDialogState extends State<CreateLoanDialog> {
  final _dropdownRepo = DropdownItemsRepository();

  final _loanReference = TextEditingController();
  final _userName = TextEditingController(text: 'Field Agent');
  final _branchName = TextEditingController(text: 'Bangalore Central');

  List<String> _products = [];
  List<String> _businessModels = [];
  String? _selectedProduct;
  String? _selectedBusinessModel;

  @override
  void initState() {
    super.initState();
    _loadDropdowns();
  }

  Future<void> _loadDropdowns() async {
    final products = await _dropdownRepo.loadProducts();
    final models = await _dropdownRepo.loadBusinessModels();
    if (!mounted) return;
    setState(() {
      _products = products;
      _businessModels = models;
      _selectedProduct = products.isNotEmpty ? products.first : null;
      _selectedBusinessModel = models.isNotEmpty ? models.first : null;
    });
  }

  Future<void> _addProduct() async {
    final name = await _showAddItemDialog('Add product');
    if (name == null || !mounted) return;
    await _dropdownRepo.addProduct(name);
    await _loadDropdowns();
    if (!mounted) return;
    setState(() => _selectedProduct = name);
  }

  Future<void> _addBusinessModel() async {
    final name = await _showAddItemDialog('Add business model');
    if (name == null || !mounted) return;
    await _dropdownRepo.addBusinessModel(name);
    await _loadDropdowns();
    if (!mounted) return;
    setState(() => _selectedBusinessModel = name);
  }

  Future<String?> _showAddItemDialog(String title) {
    String value = '';
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(title),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Enter name'),
            textInputAction: TextInputAction.done,
            onChanged: (v) => value = v,
            onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, value.trim()),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _create() {
    final loanReference = _loanReference.text.trim();
    if (loanReference.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loan reference is required')),
      );
      return;
    }

    final payload = Map<String, dynamic>.from(_samplePayload);
    payload['loan_reference'] = loanReference;
    payload['user_name'] = _userName.text.trim();
    payload['branch_name'] = _branchName.text.trim();

    final bp = Map<String, dynamic>.from(payload['business_profile'] as Map);
    if (_selectedProduct != null) bp['product'] = _selectedProduct;
    if (_selectedBusinessModel != null) bp['business_model'] = _selectedBusinessModel;
    payload['business_profile'] = bp;

    Navigator.of(context).pop(payload);
  }

  @override
  void dispose() {
    _loanReference.dispose();
    _userName.dispose();
    _branchName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildField(_loanReference, 'Loan Reference *'),
                  const SizedBox(height: 16),
                  _buildDropdownRow(
                    label: 'Product',
                    items: _products,
                    value: _selectedProduct,
                    onChanged: (v) => setState(() => _selectedProduct = v),
                    onAdd: _addProduct,
                  ),
                  const SizedBox(height: 16),
                  _buildDropdownRow(
                    label: 'Business Model',
                    items: _businessModels,
                    value: _selectedBusinessModel,
                    onChanged: (v) => setState(() => _selectedBusinessModel = v),
                    onAdd: _addBusinessModel,
                  ),
                  const SizedBox(height: 16),
                  _buildField(_userName, 'User Name'),
                  const SizedBox(height: 16),
                  _buildField(_branchName, 'Branch Name'),
                  const SizedBox(height: 4),
                  Text(
                    'AbleCredit.createNewLoanCase(...)',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: AppColors.gray600),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(onPressed: _create, child: const Text('Create')),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'New Loan Case',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(labelText: label),
      textInputAction: TextInputAction.next,
    );
  }

  Widget _buildDropdownRow({
    required String label,
    required List<String> items,
    required String? value,
    required ValueChanged<String?> onChanged,
    required VoidCallback onAdd,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
          ),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onChanged,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: onAdd,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: AppColors.black,
            ),
            child: Text('+ Add $label', style: const TextStyle(fontSize: 12)),
          ),
        ),
      ],
    );
  }
}
