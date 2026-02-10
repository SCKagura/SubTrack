import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:subtrack/src/features/subscriptions/domain/payment_record.dart';
import 'package:subtrack/src/features/subscriptions/domain/subscription.dart';

part 'subscription_repository.g.dart';

class SubscriptionRepository {
  // กล่องเก็บข้อมูล (Hive Box) เปรียบเสมือนตารางใน Database
  final Box<Subscription> _subscriptionBox;
  final Box<PaymentRecord> _paymentBox;
  final String? Function() _getUserId;

  SubscriptionRepository(
    this._subscriptionBox,
    this._paymentBox,
    this._getUserId,
  );

  // --- Subscription CRUD (จัดการข้อมูลพื้นฐาน) ---

  // ฟังก์ชันดึงข้อมูล Subscription ทั้งหมดมาแสดง (กรองตาม userId)
  List<Subscription> getAllSubscriptions() {
    final userId = _getUserId();
    if (userId == null) return [];
    return _subscriptionBox.values.where((s) => s.userId == userId).toList();
  }

  // ฟังก์ชันเฝ้าดูการเปลี่ยนแปลงของข้อมูล (Stream)
  // เมื่อมีการเพิ่ม/ลบ/แก้ไข ข้อมูลใน Box จะส่งรายการใหม่มาให้ UI อัปเดตทันที
  Stream<List<Subscription>> watchSubscriptions() async* {
    yield getAllSubscriptions();
    await for (final _ in _subscriptionBox.watch()) {
      yield getAllSubscriptions();
    }
  }

  // ฟังก์ชันดึงเฉพาะรายการที่ถูกยกเลิก (Cancelled) ไปเก็บไว้ใน Archive
  List<Subscription> getArchivedSubscriptions() {
    final userId = _getUserId();
    if (userId == null) return [];
    return _subscriptionBox.values
        .where((s) => s.status == 'Cancelled' && s.userId == userId)
        .toList();
  }

  // เพิ่ม Subscription ใหม่
  Future<void> addSubscription(Subscription subscription) async {
    await _subscriptionBox.put(subscription.id, subscription);
  }

  // แก้ไขข้อมูล Subscription
  Future<void> updateSubscription(Subscription subscription) async {
    await _subscriptionBox.put(subscription.id, subscription);
  }

  // ยกเลิก Subscription (เปลี่ยนสถานะเป็น Cancelled แทนการลบ)
  Future<void> cancelSubscription(String id) async {
    final sub = _subscriptionBox.get(id);
    if (sub != null) {
      final updated = sub.copyWith(status: 'Cancelled');
      await _subscriptionBox.put(id, updated);
    }
  }

  // ลบ Subscription ถาวร (ใช้เมื่อต้องการล้างข้อมูลจริงๆ)
  Future<void> deleteSubscription(String id) async {
    await _subscriptionBox.delete(id);
    // ในอนาคตอาจจะลบ Payment History ที่เกี่ยวข้องด้วยก็ได้
  }

  // --- Manual Tracking Logic (ระบบบันทึกการจ่ายเงิน) ---

  // ฟังก์ชัน "Mark as Paid" (บันทึกว่าจ่ายเงินแล้ว)
  // 1. สร้าง Record ประวัติการจ่าย
  // 2. อัปเดตวันครบกำหนดครั้งถัดไป (Next Payment Date)
  Future<void> markAsPaid(
    String subscriptionId,
    double amount,
    DateTime paymentDate,
    DateTime nextPaymentDate,
  ) async {
    // 1. สร้าง Record ประวัติการจ่ายเงิน (ใบเสร็จ)
    final record = PaymentRecord.create(
      subscriptionId: subscriptionId,
      amount: amount,
      date: paymentDate, // ใช้วันที่จ่ายจริงที่ผู้ใช้เลือก
      status: 'Paid',
      userId: _getUserId(),
    );
    await _paymentBox.put(record.id, record);

    // 2. อัปเดตวันครบกำหนดครั้งถัดไปใน Subscription หลัก
    final sub = _subscriptionBox.get(subscriptionId);
    if (sub != null) {
      // อัปเดตเฉพาะ field 'nextPaymentDate'
      final updated = sub.copyWith(nextPaymentDate: nextPaymentDate);
      await _subscriptionBox.put(subscriptionId, updated);
    }
  }

  // ฟังก์ชัน "Skip Payment" (ข้ามงวดนี้)
  // เหมือน Mark as Paid แต่ยอดเงินเป็น 0
  Future<void> skipPayment(
    String subscriptionId,
    DateTime skippedDate,
    DateTime nextPaymentDate,
  ) async {
    // 1. สร้าง Skip Record ($0)
    final record = PaymentRecord.create(
      subscriptionId: subscriptionId,
      amount: 0.0,
      date: skippedDate,
      status: 'Skipped',
      userId: _getUserId(),
    );
    await _paymentBox.put(record.id, record);

    // 2. อัปเดตวันครบกำหนดครั้งถัดไป
    final sub = _subscriptionBox.get(subscriptionId);
    if (sub != null) {
      final updated = sub.copyWith(nextPaymentDate: nextPaymentDate);
      await _subscriptionBox.put(subscriptionId, updated);
    }
  }

  // ดึงประวัติการจ่ายเงินทั้งหมดของ Subscription นั้นๆ
  // เรียงจาก ใหม่ -> เก่า
  List<PaymentRecord> getHistory(String subscriptionId) {
    return _paymentBox.values
        .where((r) => r.subscriptionId == subscriptionId)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date)); // Sort: Newest first
  }
}

@Riverpod(keepAlive: true)
SubscriptionRepository subscriptionRepository(SubscriptionRepositoryRef ref) {
  throw UnimplementedError('Initialize in main.dart');
}
