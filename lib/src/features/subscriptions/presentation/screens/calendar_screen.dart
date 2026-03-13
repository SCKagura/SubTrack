import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:subtrack/src/features/subscriptions/data/subscription_repository.dart';
import 'package:subtrack/src/features/subscriptions/domain/subscription.dart';
import 'package:subtrack/src/features/subscriptions/domain/payment_record.dart';
import 'package:table_calendar/table_calendar.dart';

// Helper class for calendar events
class CalendarEvent {
  final String title;
  final double amount;
  final String currency;
  final DateTime date;
  final String status; // 'Paid', 'Upcoming', 'Skipped'
  final String subName;

  CalendarEvent({
    required this.title,
    required this.amount,
    required this.currency,
    required this.date,
    required this.status,
    required this.subName,
  });
}

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  List<CalendarEvent> _getEventsForDay(
    DateTime day,
    Map<DateTime, List<CalendarEvent>> events,
  ) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return events[normalizedDay] ?? [];
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Paid':
        return Colors.green;
      case 'Skipped':
        return Colors.redAccent;
      case 'Upcoming':
        return Colors.orange;
      case 'Termination':
        return Colors.purpleAccent;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(subscriptionRepositoryProvider);

    return StreamBuilder<List<Subscription>>(
      stream: repo.watchSubscriptions(),
      builder: (context, subSnapshot) {
        if (!subSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final subs = subSnapshot.data!;

        return FutureBuilder<List<List<PaymentRecord>>>(
          future: Future.wait(subs.map((s) => repo.getHistory(s.id))),
          builder: (context, historySnapshot) {
            final Map<DateTime, List<CalendarEvent>> processedEvents = {};

            // 1. Upcoming Payments
            for (final sub in subs) {
              if (sub.status == 'Active') {
                final nextDate = DateTime(
                  sub.nextPaymentDate.year,
                  sub.nextPaymentDate.month,
                  sub.nextPaymentDate.day,
                );
                processedEvents
                    .putIfAbsent(nextDate, () => [])
                    .add(
                      CalendarEvent(
                        title: 'Due',
                        amount: sub.price,
                        currency: '฿',
                        date: nextDate,
                        status: 'Upcoming',
                        subName: sub.name,
                      ),
                    );
              }

              // 2. Termination Date
              if (sub.terminationDate != null) {
                final termDate = DateTime(
                  sub.terminationDate!.year,
                  sub.terminationDate!.month,
                  sub.terminationDate!.day,
                );
                processedEvents
                    .putIfAbsent(termDate, () => [])
                    .add(
                      CalendarEvent(
                        title: 'End',
                        amount: 0,
                        currency: '',
                        date: termDate,
                        status: 'Termination',
                        subName: '${sub.name} (สิ้นสุด)',
                      ),
                    );
              }
            }

            // 3. Past Payments
            if (historySnapshot.hasData) {
              final allHistories = historySnapshot.data!;
              for (int i = 0; i < allHistories.length; i++) {
                for (final record in allHistories[i]) {
                  final recordDate = DateTime(
                    record.date.year,
                    record.date.month,
                    record.date.day,
                  );
                  final subName = i < subs.length ? subs[i].name : 'Unknown';
                  processedEvents
                      .putIfAbsent(recordDate, () => [])
                      .add(
                        CalendarEvent(
                          title: record.status,
                          amount: record.amount,
                          currency: '฿',
                          date: recordDate,
                          status: record.status,
                          subName: subName,
                        ),
                      );
                }
              }
            }

            // Get selected day events
            final normalizedSelected = DateTime(
              (_selectedDay ?? _focusedDay).year,
              (_selectedDay ?? _focusedDay).month,
              (_selectedDay ?? _focusedDay).day,
            );
            final selectedEvents = processedEvents[normalizedSelected] ?? [];

            // Today total
            final todayKey = DateTime(
              DateTime.now().year,
              DateTime.now().month,
              DateTime.now().day,
            );
            final todayEvents = processedEvents[todayKey] ?? [];
            final todayTotal = todayEvents
                .where((e) => e.status == 'Upcoming' || e.status == 'Paid')
                .fold<double>(0, (sum, e) => sum + e.amount);

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ปฏิทิน',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'ติดตามรายการจ่ายทั้งในอดีตและอนาคต',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Today's summary strip
                  if (todayEvents.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC67C00).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFC67C00).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.today,
                              color: Color(0xFFC67C00),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "วันนี้: ${todayEvents.length} รายการ — ฿${todayTotal.toStringAsFixed(0)}",
                              style: const TextStyle(
                                color: Color(0xFFC67C00),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Calendar
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: TableCalendar<CalendarEvent>(
                      locale: 'th_TH',
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (day) =>
                          isSameDay(_selectedDay, day),
                      eventLoader: (day) =>
                          _getEventsForDay(day, processedEvents),
                      headerStyle: const HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        titleTextStyle: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                        leftChevronIcon: Icon(
                          Icons.chevron_left,
                          color: Colors.white70,
                        ),
                        rightChevronIcon: Icon(
                          Icons.chevron_right,
                          color: Colors.white70,
                        ),
                        headerPadding: EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(color: Colors.transparent),
                      ),
                      daysOfWeekStyle: const DaysOfWeekStyle(
                        weekdayStyle: TextStyle(color: Colors.grey),
                        weekendStyle: TextStyle(color: Colors.grey),
                      ),
                      calendarStyle: CalendarStyle(
                        outsideDaysVisible: false,
                        defaultTextStyle: const TextStyle(
                          color: Colors.white70,
                        ),
                        weekendTextStyle: const TextStyle(
                          color: Colors.white70,
                        ),
                        todayDecoration: BoxDecoration(
                          color: const Color(0xFFC67C00).withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                        ),
                        selectedDecoration: const BoxDecoration(
                          color: Colors.deepPurple,
                          shape: BoxShape.circle,
                        ),
                        markerDecoration: const BoxDecoration(
                          color: Colors.transparent,
                        ),
                        markersMaxCount: 3,
                      ),
                      calendarBuilders: CalendarBuilders(
                        markerBuilder: (context, date, events) {
                          if (events.isEmpty) return null;
                          return Positioned(
                            bottom: 4,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: events.take(3).map((event) {
                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 1.5,
                                  ),
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _getStatusColor(event.status),
                                  ),
                                );
                              }).toList(),
                            ),
                          );
                        },
                      ),
                      onDaySelected: (selectedDay, focusedDay) {
                        if (!isSameDay(_selectedDay, selectedDay)) {
                          setState(() {
                            _selectedDay = selectedDay;
                            _focusedDay = focusedDay;
                          });
                        }
                      },
                      onPageChanged: (focusedDay) {
                        _focusedDay = focusedDay;
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Legend
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        _buildLegendDot(Colors.green, 'จ่ายแล้ว'),
                        const SizedBox(width: 16),
                        _buildLegendDot(Colors.orange, 'เร็วๆ นี้'),
                        const SizedBox(width: 16),
                        _buildLegendDot(Colors.redAccent, 'ข้ามแล้ว'),
                        const SizedBox(width: 16),
                        _buildLegendDot(Colors.purpleAccent, 'วันเลิกใช้งาน'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Events for selected day
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat(
                            'EEEE, d MMMM',
                          ).format(_selectedDay ?? _focusedDay),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (selectedEvents.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: const Column(
                              children: [
                                Icon(
                                  Icons.event_available,
                                  size: 40,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'ไม่มีรายการในวันนี้',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        else
                          ...selectedEvents.map(
                            (event) => _buildEventCard(event),
                          ),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildEventCard(CalendarEvent event) {
    final color = _getStatusColor(event.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              event.status == 'Paid'
                  ? Icons.check_circle
                  : event.status == 'Skipped'
                  ? Icons.remove_circle
                  : event.status == 'Termination'
                  ? Icons.cancel
                  : Icons.schedule,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.subName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  event.status == 'Upcoming'
                      ? 'ครบกำหนด'
                      : event.status == 'Paid'
                          ? 'จ่ายแล้ว'
                          : event.status == 'Termination'
                              ? 'วันสิ้นสุด'
                              : 'ข้ามแล้ว',
                  style: TextStyle(color: color, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            event.status == 'Termination'
                ? 'คงเหลือ'
                : event.status != 'Skipped'
                    ? '${event.currency}${event.amount.toStringAsFixed(0)}'
                    : '—',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
