# 💻 SubTrack Code Explained (Deep Dive)

เอกสารนี้รวบรวมโค้ดส่วนสำคัญของโปรเจ็ค SubTrack พร้อมคำอธิบายเพื่อให้เข้าใจการทำงานในแต่ละส่วนครับ

---

### 🗓️ 1. ระบบปฏิทิน (The Calendar Engine)
เราใช้ Library `table_calendar` และเชื่อมข้อมูลจาก Repository มาแสดงผลเป็น Event ในแต่ละวัน

```dart
// ไฟล์: calendar_screen.dart
TableCalendar<CalendarEvent>(
  firstDay: DateTime.utc(2020, 1, 1),
  lastDay: DateTime.utc(2030, 12, 31),
  focusedDay: _focusedDay,
  calendarFormat: CalendarFormat.month,
  
  // โหลด Event (จุดสีบนปฏิทิน) จากข้อมูลที่คัดกรองแล้ว
  eventLoader: (day) => _getEventsForDay(day, processedEvents),
  
  // ตกแต่ง Marker (จุดสีใต้ตัวเลข)
  calendarBuilders: CalendarBuilders(
    markerBuilder: (context, date, events) {
      if (events.isEmpty) return null;
      return Positioned(
        bottom: 1,
        child: Row(
          children: events.map((event) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 0.5),
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _getStatusColor(event.status), // สีตามสถานะ Paid/Upcoming
            ),
          )).toList(),
        ),
      );
    },
  ),
)
```

---

### 🌐 2. ระบบหลังบ้าน (Supabase & Auth)
การจัดการ Session และการล็อกอินทั้งหมดผ่าน Supabase Client

```dart
// ไฟล์: auth_repository.dart
class AuthRepository {
  final SupabaseClient _supabase;

  // Sign In ด้วย Google OAuth
  Future<void> signInWithGoogle() async {
    await _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'com.example.subtrack2://login-callback/',
      queryParams: {'prompt': 'select_account'},
    );
  }

  // ติดตามการเปลี่ยนแปลงสถานะการล็อกอิน
  Stream<User?> authStateChanges() {
    return _supabase.auth.onAuthStateChange.map((data) => data.session?.user);
  }
}
```

---

### 🎨 3. ระบบ Premium Gradients (UI Decoration)
เราใช้ `LinearGradient` ของ Flutter โดยตรงเพื่อประสิทธิภาพสูงสุดในการแสดงผล

```dart
// ตัวอย่าง Gradient ในหน้า Dashboard
decoration: BoxDecoration(
  borderRadius: BorderRadius.circular(24),
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      gradientColors[0], // สีหลัก (เช่น Deep Blue)
      gradientColors[1], // สีสว่าง (เช่น Light Blue)
    ],
  ),
  boxShadow: [
    BoxShadow(
      color: gradientColors[0].withValues(alpha: 0.3),
      blurRadius: 12,
      offset: const Offset(0, 6),
    ),
  ],
)
```

---

### 📊 4. ระบบประวัติการจ่ายเงิน (Payment History)
เราใช้ระบบ SQL Relation ในการบันทึกข้อมูลการจ่ายเงินลงในตาราง `payment_history`

```dart
// ไฟล์: subscription_repository.dart
Future<void> markAsPaid(String subId, double amount, DateTime paidAt, DateTime nextDate) async {
  // 1. บันทึกประวัติลงตาราง payment_history
  await _supabase.from('payment_history').insert({
    'subscription_id': subId,
    'amount': amount,
    'date': paidAt.toIso8601String(),
    'status': 'Paid',
  });

  // 2. อัปเดตวันจ่ายรอบถัดไปในตาราง subscriptions
  await _supabase.from('subscriptions')
      .update({'next_payment_date': nextDate.toIso8601String()})
      .eq('id', subId);
}
```

---

### 🔔 5. ระบบแจ้งเตือน (Notifications Logic)
ตั้งเวลาแจ้งเตือนล่วงหน้าตามวันที่คำนวณจากรอบบิล

```dart
// ไฟล์: notification_service.dart
Future<void> scheduleSubscriptionReminder(Subscription sub) async {
  // คำนวณวันที่ต้องเตือน (ล่วงหน้า X วัน)
  final reminderDate = sub.nextPaymentDate.subtract(Duration(days: sub.reminderDaysPrior));
  
  // ตั้งเวลา 9:00 AM ของวันนั้น
  final scheduledDate = tz.TZDateTime(
    tz.local, reminderDate.year, reminderDate.month, reminderDate.day, 9, 0
  );

  await _notificationsPlugin.zonedSchedule(
    sub.id.hashCode,
    'ถึงกำหนดชำระ: ${sub.name}',
    'ยอดชำระ ฿${sub.price} เร็วๆ นี้ครับ',
    scheduledDate,
    const NotificationDetails(...),
    uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
  );
}
```

### 👤 6. ระบบข้อมูลผู้ใช้ (User Profile Initialization)
เราใช้ Logic พิเศษในการตรวจสอบว่าผู้ใช้ล็อกอินครั้งแรกหรือไม่ เพื่อสร้างข้อมูลพื้นฐาน (Seed Data) ให้โดยอัตโนมัติ

```dart
// ไฟล์: user_profile_repository.dart
Future<void> _initializeNewUser(User user) async {
  // 1. สร้าง Profile พื้นฐาน
  await _supabase.from('profiles').upsert({
    'id': user.id,
    'email': user.email ?? '',
    'currency': 'THB',
    'monthly_budget': 0.0,
  });

  // 2. Seed หมวดหมู่เริ่มต้น (Food, Transport, etc.)
  final defaults = Category.defaults('THB');
  for (final cat in defaults) {
    await _supabase.from('categories').upsert({
      'user_id': user.id,
      'name': cat.name,
      'icon_code': cat.iconCode,
      'color_value': cat.colorValue,
    });
  }
}
```

---

### 📂 7. การจัดการหมวดหมู่ (Dynamic Category Management)
การดึงข้อมูลหมวดหมู่ใช้ระบบ **Real-time Stream** ทำให้เมื่อมีการเพิ่มหรือลบหมวดหมู่ หน้าจอจะอัปเดตทันทีโดยไม่ต้อง Refresh

```dart
// ไฟล์: category_repository.dart
Stream<List<Category>> watchCategories() {
  return _supabase
      .from('categories')
      .stream(primaryKey: ['id']) // ใช้ Real-time Stream
      .eq('user_id', uid)
      .order('created_at')
      .asyncMap((rows) async {
        // ถ้าเป็น User ใหม่ที่ยังไม่มีหมวดหมู่ ให้ Seed ค่าเริ่มต้นทันที
        if (rows.isEmpty) {
          await _seedDefaults(uid);
          return Category.defaults('THB');
        }
        return rows.map(_rowToCategory).toList();
      });
}
```

---
**Summary**: โปรเจ็คนี้เน้นการใช้ **Clean Architecture** และ **State Management (Riverpod)** เพื่อให้โค้ดสามารถอ่านและขยายผลได้ง่ายที่สุดครับ
