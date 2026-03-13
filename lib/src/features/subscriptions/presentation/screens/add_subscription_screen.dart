import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:subtrack/src/features/authentication/data/auth_repository.dart';
import 'package:subtrack/src/features/subscriptions/data/category_repository.dart';
import 'package:subtrack/src/features/subscriptions/data/subscription_repository.dart';
import 'package:subtrack/src/features/subscriptions/domain/subscription.dart';
import 'package:subtrack/src/features/subscriptions/domain/family_member.dart';
import 'package:subtrack/src/features/subscriptions/domain/category.dart';

class AddSubscriptionScreen extends ConsumerStatefulWidget {
  final Subscription? subscriptionToEdit;

  const AddSubscriptionScreen({super.key, this.subscriptionToEdit});

  @override
  ConsumerState<AddSubscriptionScreen> createState() =>
      _AddSubscriptionScreenState();
}

class _AddSubscriptionScreenState extends ConsumerState<AddSubscriptionScreen> {
  final _pageController = PageController();
  int _currentStep = 0;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _urlController = TextEditingController();
  final _logoUrlController = TextEditingController();

  String? _selectedCategoryId;
  String? _selectedFamilyMemberId;
  BillingCycle _selectedCycle = BillingCycle.monthly;
  DateTime _startDate = DateTime.now();
  DateTime _nextPaymentDate = DateTime.now();
  String _currency = 'THB';
  final int _repeatEvery = 1;
  bool _isFreeTrial = false;
  bool _isAutoRenew = true;
  bool _hasReminder = true;
  int _reminderDaysPrior = 1;
  DateTime? _terminationDate;

  @override
  void initState() {
    super.initState();
    if (widget.subscriptionToEdit != null) {
      final sub = widget.subscriptionToEdit!;
      _nameController.text = sub.name;
      _priceController.text = sub.price.toString();
      _selectedCategoryId = sub.categoryId;
      _selectedFamilyMemberId = sub.familyMemberId;
      _selectedCycle = sub.cycle;
      _startDate = sub.firstPaymentDate;
      _nextPaymentDate = sub.nextPaymentDate;
      _currency = sub.currency;
      _isAutoRenew = sub.status.toLowerCase() != 'cancelled';
      _hasReminder = sub.hasReminder;
      _reminderDaysPrior = sub.reminderDaysPrior;
      _urlController.text = sub.url ?? '';
      _logoUrlController.text = sub.logoUrl ?? '';
      _terminationDate = sub.terminationDate;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _priceController.dispose();
    _urlController.dispose();
    _logoUrlController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _saveSubscription();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.subscriptionToEdit != null
                  ? 'แก้ไขการสมัครสมาชิก'
                  : 'เพิ่มการสมัครสมาชิกใหม่',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              'เพิ่มรายการบริการที่คุณใช้งานเพื่อติดตามการชำระเงินรายรอบ',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;

          return Row(
            children: [
              // Side Navigation
              if (!isMobile)
                Container(
                  width: 140,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      _buildSidebarItem(0, 'บริการ'),
                      _buildSidebarItem(1, 'ราคา'),
                      _buildSidebarItem(2, 'กำหนดการ'),
                      _buildSidebarItem(3, 'แจ้งเตือน'),
                      const Spacer(),
                      _buildSidebarItem(-1, 'รายละเอียด', isOptional: true),
                    ],
                  ),
                ),
              if (isMobile)
                Container(
                  width: 64,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: const BoxDecoration(
                    border: Border(right: BorderSide(color: Colors.white10)),
                  ),
                  child: Column(
                    children: [
                      _buildSidebarIcon(0, Icons.info_outline),
                      _buildSidebarIcon(1, Icons.payments_outlined),
                      _buildSidebarIcon(2, Icons.calendar_today_outlined),
                      _buildSidebarIcon(3, Icons.notifications_active_outlined),
                      const Spacer(),
                      _buildSidebarIcon(-1, Icons.more_horiz, isOptional: true),
                    ],
                  ),
                ),
              // Form Content
              Expanded(
                child: Form(
                  key: _formKey,
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (index) =>
                        setState(() => _currentStep = index),
                    children: [
                      _buildServiceStep(isMobile),
                      _buildPricingStep(isMobile),
                      _buildScheduleStep(isMobile),
                      _buildRemindersStep(isMobile),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        color: Colors.black,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: _previousStep,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.white24),
                ),
              ),
              child: Text(_currentStep == 0 ? 'ยกเลิก' : 'ย้อนกลับ'),
            ),
            ElevatedButton(
              onPressed: _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC67C00),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(_currentStep == 3 ? 'บันทึก' : 'ถัดไป'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarItem(int index, String label, {bool isOptional = false}) {
    final isActive = _currentStep == index;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isActive ? Colors.white12 : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isActive
              ? Border.all(color: Colors.white24)
              : Border.all(color: Colors.transparent),
        ),
        child: Text(
          label + (isOptional ? '\n(Optional)' : ''),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey,
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarIcon(
    int index,
    IconData icon, {
    bool isOptional = false,
  }) {
    final isActive = _currentStep == index;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isActive ? Colors.white12 : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isActive
              ? Border.all(color: Colors.white24)
              : Border.all(color: Colors.transparent),
        ),
        child: Icon(
          icon,
          color: isActive ? Colors.white : Colors.grey,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildServiceStep(bool isMobile) {
    final catRepo = ref.read(categoryRepositoryProvider);
    return StreamBuilder<List<Category>>(
      stream: catRepo.watchCategories(),
      builder: (context, snapshot) {
        final categories = snapshot.data ?? [];
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'เลือกรายการหลัก',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'แตะบริการยอดนิยมเพื่อกรอกข้อมูลอัตโนมัติ',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
              const SizedBox(height: 12),
              _buildServiceTemplates(categories),
              const SizedBox(height: 24),
              if (isMobile) ...[
                _buildTextField(
                  controller: _nameController,
                  label: 'ชื่อบริการ *',
                  hint: 'YouTube Premium',
                ),
                const SizedBox(height: 16),
                _buildDropdownField<String>(
                  label: 'หมวดหมู่ *',
                  value: _selectedCategoryId,
                  hint: 'เลือกหมวดหมู่',
                  items: categories.map((c) {
                    return DropdownMenuItem(
                      value: c.id,
                      child: Row(
                        children: [
                          Icon(
                            IconData(c.iconCode, fontFamily: 'MaterialIcons'),
                            color: Color(c.colorValue),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              c.name,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedCategoryId = val),
                ),
                const SizedBox(height: 16),
                _buildFamilyMemberDropdown(true),
              ] else
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildTextField(
                        controller: _nameController,
                        label: 'ชื่อบริการ *',
                        hint: 'YouTube Premium',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: _buildDropdownField<String>(
                        label: 'หมวดหมู่ *',
                        value: _selectedCategoryId,
                        hint: 'เลือกหมวดหมู่',
                        items: categories.map((c) {
                          return DropdownMenuItem(
                            value: c.id,
                            child: Row(
                              children: [
                                Icon(
                                  IconData(
                                    c.iconCode,
                                    fontFamily: 'MaterialIcons',
                                  ),
                                  color: Color(c.colorValue),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  c.name,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) =>
                            setState(() => _selectedCategoryId = val),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              if (!isMobile) _buildFamilyMemberDropdown(false),
              const SizedBox(height: 24),
              _buildTextField(
                controller: _urlController,
                label: 'ลิงก์เว็บไซต์',
                hint: 'https://www.youtube.com/premium',
              ),
              const Text(
                'เว็บไซต์อย่างเป็นทางการของบริการ',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 24),
              _buildLogoPreview(isMobile),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPricingStep(bool isMobile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isMobile) ...[
            _buildTextField(
              controller: _priceController,
              label: 'จำนวนเงิน *',
              hint: '109',
              prefixText: '฿ ',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            _buildDropdownField<String>(
              label: 'สกุลเงิน',
              value: _currency,
              items: ['THB', 'USD', 'EUR']
                  .map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Text(
                        c,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (val) => setState(() => _currency = val!),
            ),
          ] else
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _priceController,
                    label: 'จำนวนเงิน *',
                    hint: '109',
                    prefixText: '฿ ',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDropdownField<String>(
                    label: 'สกุลเงิน',
                    value: _currency,
                    items: ['THB', 'USD', 'EUR']
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text(
                              c,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => setState(() => _currency = val!),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 24),
          if (isMobile) ...[
            _buildDropdownField<BillingCycle>(
              label: 'รอบการชำระเงิน *',
              value: _selectedCycle,
              items: BillingCycle.values.map((c) {
                return DropdownMenuItem(
                  value: c,
                  child: Text(
                    c.toString().split('.').last.toUpperCase(),
                    style: const TextStyle(fontSize: 13, color: Colors.white),
                  ),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedCycle = val!),
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: TextEditingController(text: '$_repeatEvery'),
              label: 'Repeat every',
              hint: '1',
              keyboardType: TextInputType.number,
            ),
          ] else
            Row(
              children: [
                Expanded(
                  child: _buildDropdownField<BillingCycle>(
                    label: 'รอบการชำระเงิน *',
                    value: _selectedCycle,
                    items: BillingCycle.values.map((c) {
                      return DropdownMenuItem(
                        value: c,
                        child: Text(
                          c.toString().split('.').last.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedCycle = val!),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: TextEditingController(text: '$_repeatEvery'),
                    label: 'จ่ายทุกๆ',
                    hint: '1',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 24),
          const Divider(color: Colors.white10),
          const SizedBox(height: 24),
          const Text(
            'โปรโมชั่น / ราคาช่วงเริ่มต้น',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const Text(
            'ตั้งราคาพิเศษสำหรับช่วงแนะนำการใช้งาน',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: TextEditingController(),
            label: 'ราคาช่วงแนะนำ',
            hint: 'e.g. 9.99',
            prefixText: '฿ ',
          ),
          const SizedBox(height: 16),
          _buildDatePickerField(
            label: 'สิ้นสุดราคาแนะนำเมื่อ',
            hint: 'ราคานี้จะสิ้นสุดเมื่อไหร่?',
            value: null,
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildFamilyMemberDropdown(bool isMobile) {
    final subRepo = ref.read(subscriptionRepositoryProvider);

    return StreamBuilder<List<FamilyMember>>(
      stream: subRepo.watchFamilyMembers(),
      builder: (context, snapshot) {
        final members = snapshot.data ?? [];

        return _buildDropdownField<String>(
          label: 'สมาชิกในครอบครัว',
          value: _selectedFamilyMemberId,
          hint: 'เลือกสมาชิก',
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text(
                'ฉัน (ค่าเริ่มต้น)',
                style: TextStyle(fontSize: 14, color: Colors.white),
              ),
            ),
            ...members.map((m) {
              return DropdownMenuItem<String>(
                value: m.id,
                child: Row(
                  children: [
                    if (m.isCurrentUser)
                      const Icon(Icons.person, size: 16, color: Colors.grey)
                    else
                      Container(
                        width: 20,
                        height: 20,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: Colors.purple,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          m.name.isNotEmpty ? m.name[0] : '?',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Text(
                      m.name,
                      style: const TextStyle(fontSize: 14, color: Colors.white),
                    ),
                  ],
                ),
              );
            }),
          ],
          onChanged: (val) => setState(() => _selectedFamilyMemberId = val),
        );
      },
    );
  }

  Widget _buildScheduleStep(bool isMobile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isMobile) ...[
            _buildDatePickerField(
              label: 'วันที่เริ่ม *',
              value: _startDate,
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _startDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (picked != null) setState(() => _startDate = picked);
              },
            ),
            const SizedBox(height: 16),
            _buildDatePickerField(
              label: 'วันที่ชำระรอบถัดไป *',
              value: _nextPaymentDate,
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _nextPaymentDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (picked != null) setState(() => _nextPaymentDate = picked);
              },
            ),
          ] else
            Row(
              children: [
                Expanded(
                  child: _buildDatePickerField(
                    label: 'วันที่เริ่ม *',

                    value: _startDate,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _startDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) setState(() => _startDate = picked);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDatePickerField(
                    label: 'วันที่ชำระรอบถัดไป *',
                    value: _nextPaymentDate,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _nextPaymentDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setState(() => _nextPaymentDate = picked);
                      }
                    },
                  ),
                ),
              ],
            ),
          const SizedBox(height: 24),
          _buildSwitchTile(
            title: 'อยู่ในช่วงทดลองใช้ฟรี',
            subtitle:
                'เปิดหากคุณกำลังใช้ช่วงทดลองใช้ฟรีและจะเปลี่ยนเป็นแบบจ่ายเงินอัตโนมัติ',
            value: _isFreeTrial,
            onChanged: (val) => setState(() => _isFreeTrial = val),
          ),
          const SizedBox(height: 24),
          _buildSwitchTile(
            title: 'ต่ออายุอัตโนมัติ',
            subtitle:
                'ต่ออายุอัตโนมัติทุกๆ รอบการชำระเงิน ปิดเพื่อยกเลิกบริการหลังจบรอบปัจจุบัน',
            value: _isAutoRenew,
            onChanged: (val) => setState(() => _isAutoRenew = val),
          ),
          const SizedBox(height: 24),
          _buildDatePickerField(
            label: 'วันเลิกใช้งาน (ถ้ามี)',
            value: _terminationDate,
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _terminationDate ?? DateTime.now().add(const Duration(days: 30)),
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
                selectableDayPredicate: (day) => day.isAfter(_startDate),
              );
              if (picked != null) setState(() => _terminationDate = picked);
            },
            suffixIcon: _terminationDate != null
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey),
                    onPressed: () => setState(() => _terminationDate = null),
                  )
                : null,
          ),
          if (_terminationDate != null)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4),
              child: Text(
                'บริการจะสิ้นสุดลงในวันที่ ${DateFormat('d MMMM yyyy', 'th_TH').format(_terminationDate!)}',
                style: const TextStyle(color: Color(0xFFC67C00), fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    IconData? prefixIcon,
    IconData? suffixIcon,
    String? prefixText,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
            prefixText: prefixText,
            prefixStyle: const TextStyle(color: Colors.white),
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, color: Colors.grey)
                : null,
            suffixIcon: suffixIcon != null
                ? Icon(suffixIcon, color: Colors.grey)
                : null,
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white24),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white10),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFC67C00)),
            ),
          ),
        ),
      ],
    );
  }

  // --- Service Template Quick Select ---

  static const List<Map<String, dynamic>> _serviceTemplates = [
    {
      'name': 'Netflix',
      'price': 419.0,
      'icon': '🎬',
      'category': 'Entertainment',
      'url': 'https://netflix.com',
      'logoUrl': 'https://icon.horse/icon/netflix.com',
    },
    {
      'name': 'Spotify',
      'price': 99.0,
      'icon': '🎵',
      'category': 'Music',
      'url': 'https://spotify.com',
      'logoUrl': 'https://icon.horse/icon/spotify.com',
    },
    {
      'name': 'Spotify Family',
      'price': 209.0,
      'icon': '🎵',
      'category': 'Music',
      'url': 'https://spotify.com',
      'logoUrl': 'https://icon.horse/icon/spotify.com',
    },
    {
      'name': 'YouTube Premium',
      'price': 179.0,
      'icon': '▶️',
      'category': 'Entertainment',
      'url': 'https://youtube.com',
      'logoUrl': 'https://icon.horse/icon/youtube.com',
    },
    {
      'name': 'Disney+',
      'price': 269.0,
      'icon': '🏰',
      'category': 'Entertainment',
      'url': 'https://disneyplus.com',
      'logoUrl': 'https://icon.horse/icon/disneyplus.com',
    },
    {
      'name': 'Apple TV+',
      'price': 99.0,
      'icon': '🍎',
      'category': 'Entertainment',
      'url': 'https://tv.apple.com',
      'logoUrl': 'https://icon.horse/icon/tv.apple.com',
    },
    {
      'name': 'Adobe Creative Cloud',
      'price': 1755.0,
      'icon': '🎨',
      'category': 'Productivity',
      'url': 'https://adobe.com',
      'logoUrl': 'https://icon.horse/icon/adobe.com',
    },
    {
      'name': 'GitHub Copilot',
      'price': 360.0,
      'icon': '🤖',
      'category': 'Productivity',
      'url': 'https://github.com',
      'logoUrl': 'https://icon.horse/icon/github.com',
    },
    {
      'name': 'ChatGPT Plus',
      'price': 680.0,
      'icon': '💬',
      'category': 'Productivity',
      'url': 'https://chatgpt.com',
      'logoUrl': 'https://icon.horse/icon/chatgpt.com',
    },
    {
      'name': 'iCloud+ 50GB',
      'price': 35.0,
      'icon': '☁️',
      'category': 'Cloud',
      'url': 'https://icloud.com',
      'logoUrl': 'https://icon.horse/icon/icloud.com',
    },
    {
      'name': 'iCloud+ 200GB',
      'price': 109.0,
      'icon': '☁️',
      'category': 'Cloud',
      'url': 'https://icloud.com',
      'logoUrl': 'https://icon.horse/icon/icloud.com',
    },
    {
      'name': 'Google One 100GB',
      'price': 59.0,
      'icon': '🔵',
      'category': 'Cloud',
      'url': 'https://google.com',
      'logoUrl': 'https://icon.horse/icon/google.com',
    },
    {
      'name': 'Microsoft 365',
      'price': 2699.0,
      'icon': '📊',
      'category': 'Productivity',
      'url': 'https://microsoft365.com',
      'logoUrl': 'https://icon.horse/icon/microsoft.com',
    },
    {
      'name': 'LINE MAN',
      'price': 49.0,
      'icon': '🛵',
      'category': 'Food',
      'url': 'https://lineman.line.me',
      'logoUrl': 'https://icon.horse/icon/lineman.line.me',
    },
    {
      'name': 'Canva Pro',
      'price': 599.0,
      'icon': '✏️',
      'category': 'Productivity',
      'url': 'https://canva.com',
      'logoUrl': 'https://icon.horse/icon/canva.com',
    },
    {
      'name': 'NordVPN',
      'price': 129.0,
      'icon': '🔒',
      'category': 'Utilities',
      'url': 'https://nordvpn.com',
      'logoUrl': 'https://icon.horse/icon/nordvpn.com',
    },
  ];

  Widget _buildServiceTemplates(List<Category> categories) {
    return SizedBox(
      height: 120,
      child: GridView.builder(
        scrollDirection: Axis.horizontal,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.45,
        ),
        itemCount: _serviceTemplates.length,
        itemBuilder: (context, index) {
          final template = _serviceTemplates[index];
          final isSelected = _nameController.text == template['name'];
          return GestureDetector(
            onTap: () {
              setState(() {
                _nameController.text = template['name'] as String;
                _priceController.text =
                    (template['price'] as double).toStringAsFixed(0);

                // Auto-select category if name matches
                final targetCatName =
                    (template['category'] as String).toLowerCase();
                final matchedCat = categories.firstWhere(
                  (c) =>
                      c.name.toLowerCase().contains(targetCatName) ||
                      targetCatName.contains(c.name.toLowerCase()),
                  orElse: () => categories.isNotEmpty
                      ? categories.first
                      : Category.create(
                          name: 'General',
                          color: Colors.grey,
                          icon: Icons.category,
                        ),
                );
                _selectedCategoryId = matchedCat.id;

                // Auto-fill URL and Logo
                if (template.containsKey('url')) {
                  _urlController.text = template['url'] as String;
                }
                if (template.containsKey('logoUrl')) {
                  _logoUrlController.text = template['logoUrl'] as String;
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFC67C00).withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? const Color(0xFFC67C00) : Colors.white10,
                ),
              ),
              child: Row(
                children: [
                  Text(
                    template['icon'] as String,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      template['name'] as String,
                      style: TextStyle(
                        color: isSelected
                            ? const Color(0xFFC67C00)
                            : Colors.white70,
                        fontSize: 11,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true,
          hint: hint != null
              ? Text(
                  hint,
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                )
              : null,
          dropdownColor: const Color(0xFF1E1E1E),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white24),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white10),
            ),
          ),
          items: items,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildDatePickerField({
    required String label,
    DateTime? value,
    String? hint,
    required VoidCallback onTap,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_month, color: Colors.grey, size: 20),
                const SizedBox(width: 12),
                  Text(
                    value != null
                        ? DateFormat('MMM d, yyyy').format(value)
                        : (hint ?? 'Select date'),
                    style: TextStyle(
                      color: value != null ? Colors.white : Colors.grey,
                    ),
                  ),
                  const Spacer(),
                  if (suffixIcon != null) suffixIcon,
                ],
              ),
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: const Color(0xFFC67C00),
          activeTrackColor: const Color(0xFFC67C00).withValues(alpha: 0.3),
        ),
      ],
    );
  }

  Widget _buildLogoPreview(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'โลโก้ (URL รูปภาพภายนอก)',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _logoUrlController,
                label: '',
                hint: 'https://example.com/logo.png',
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: 'ดึงโลโก้อัตโนมัติจากลิงก์เว็บไซต์',
              child: ElevatedButton(
                onPressed: () {
                  if (_urlController.text.isNotEmpty) {
                    var url = _urlController.text;
                    if (!url.startsWith('http')) {
                      url = 'https://$url';
                    }
                    final uri = Uri.tryParse(url);
                    if (uri != null && uri.host.isNotEmpty) {
                      setState(() {
                        // Use icon.horse for reliable favicon fetching
                        _logoUrlController.text = 'https://icon.horse/icon/${uri.host}';
                      });
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.amber),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_logoUrlController.text.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                _logoUrlController.text,
                height: 60,
                width: 60,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.broken_image, color: Colors.grey, size: 40);
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRemindersStep(bool isMobile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'การแจ้งเตือน',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'ตั้งค่าให้แอปแจ้งเตือนคุณก่อนถึงกำหนดชำระเงิน',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 24),
          _buildSwitchTile(
            title: 'เปิดการแจ้งเตือน',
            subtitle: 'รับการแจ้งเตือนสำหรับบริการนี้',
            value: _hasReminder,
            onChanged: (val) => setState(() => _hasReminder = val),
          ),
          if (_hasReminder) ...[
            const SizedBox(height: 24),
            _buildDropdownField<int>(
              label: 'แจ้งเตือนล่วงหน้า',
              value: _reminderDaysPrior,
              items: const [
                DropdownMenuItem(value: 0, child: Text('ตรงวัน (09:00 น.)', style: TextStyle(color: Colors.white, fontSize: 14))),
                DropdownMenuItem(value: 1, child: Text('ล่วงหน้า 1 วัน', style: TextStyle(color: Colors.white, fontSize: 14))),
                DropdownMenuItem(value: 2, child: Text('ล่วงหน้า 2 วัน', style: TextStyle(color: Colors.white, fontSize: 14))),
                DropdownMenuItem(value: 3, child: Text('ล่วงหน้า 3 วัน', style: TextStyle(color: Colors.white, fontSize: 14))),
                DropdownMenuItem(value: 7, child: Text('ล่วงหน้า 1 สัปดาห์', style: TextStyle(color: Colors.white, fontSize: 14))),
              ],
              onChanged: (val) => setState(() => _reminderDaysPrior = val ?? 1),
            ),
          ],
        ],
      ),
    );
  }

  void _saveSubscription() {
    if (_formKey.currentState!.validate()) {
      final userId = ref.read(authRepositoryProvider).currentUser?.id;
      final priceStr = _priceController.text;
      final price = double.tryParse(priceStr) ?? 0.0;

      if (widget.subscriptionToEdit != null) {
        final newSub = Subscription(
          id: widget.subscriptionToEdit!.id,
          name: _nameController.text,
          categoryId: _selectedCategoryId ?? '',
          price: price,
          currency: _currency,
          cycle: _selectedCycle,
          firstPaymentDate: _startDate,
          nextPaymentDate: _nextPaymentDate,
          status: _isAutoRenew ? 'Active' : 'Cancelled',
          familyMemberId: _selectedFamilyMemberId,
          userId: userId,
          url: _urlController.text.isNotEmpty ? _urlController.text : null,
          logoUrl: _logoUrlController.text.isNotEmpty ? _logoUrlController.text : null,
          hasReminder: _hasReminder,
          reminderDaysPrior: _reminderDaysPrior,
          terminationDate: _terminationDate,
        );
        ref.read(subscriptionRepositoryProvider).updateSubscription(newSub);
      } else {
        final sub = Subscription.create(
          name: _nameController.text,
          categoryId: _selectedCategoryId ?? '',
          price: price,
          currency: _currency,
          cycle: _selectedCycle,
          firstPaymentDate: _startDate,
          familyMemberId: _selectedFamilyMemberId,
          userId: userId,
          hasReminder: _hasReminder,
          reminderDaysPrior: _reminderDaysPrior,
          terminationDate: _terminationDate,
        );
        // If they manually set next payment date in form, we should use it
        final subWithDate = sub.copyWith(
          nextPaymentDate: _nextPaymentDate,
          url: _urlController.text.isNotEmpty ? _urlController.text : null,
          logoUrl: _logoUrlController.text.isNotEmpty ? _logoUrlController.text : null,
        );

        ref.read(subscriptionRepositoryProvider).addSubscription(subWithDate);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('บันทึกข้อมูลสำเร็จ! ✅'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    }
  }
}
