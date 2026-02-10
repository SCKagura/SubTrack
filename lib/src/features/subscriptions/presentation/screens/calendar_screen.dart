import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:subtrack/src/features/subscriptions/data/subscription_repository.dart';
import 'package:subtrack/src/features/subscriptions/domain/subscription.dart';
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
  Map<DateTime, List<CalendarEvent>> _events = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  // Fetch and aggregate data
  Future<void> _loadEvents(
    List<Subscription> subs,
    SubscriptionRepository repo,
  ) async {
    final Map<DateTime, List<CalendarEvent>> newEvents = {};

    for (final sub in subs) {
      // 1. Future: Next Payment (Upcoming)
      if (sub.status == 'Active') {
        final nextDate = DateTime(
          sub.nextPaymentDate.year,
          sub.nextPaymentDate.month,
          sub.nextPaymentDate.day,
        );
        if (newEvents[nextDate] == null) newEvents[nextDate] = [];
        newEvents[nextDate]!.add(
          CalendarEvent(
            title: 'Payment Due',
            amount: sub.price,
            currency: '฿', // Enforcing THB as per previous request
            date: nextDate,
            status: 'Upcoming',
            subName: sub.name,
          ),
        );
      }

      // 2. History: Past Payments (Paid/Skipped)
      final history = repo.getHistory(sub.id);
      for (final record in history) {
        final recordDate = DateTime(
          record.date.year,
          record.date.month,
          record.date.day,
        );
        if (newEvents[recordDate] == null) newEvents[recordDate] = [];
        newEvents[recordDate]!.add(
          CalendarEvent(
            title: record.status == 'Skipped'
                ? 'Skipped Payment'
                : 'Payment Made',
            amount: record.amount,
            currency: '฿',
            date: recordDate,
            status: record.status == 'Paid' ? 'Paid' : 'Skipped',
            subName: sub.name,
          ),
        );
      }
    }

    // Sort events inside map? Not strictly necessary for TableCalendar but good for List
    setState(() {
      _events = newEvents;
    });
  }

  List<CalendarEvent> _getEventsForDay(DateTime day) {
    // TableCalendar queries with UTC or tailored dates, safe to strip time
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _events[normalizedDay] ?? [];
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Paid':
        return Colors.green;
      case 'Skipped':
        return Colors.redAccent; // Or Grey
      case 'Upcoming':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(subscriptionRepositoryProvider);

    return StreamBuilder<List<Subscription>>(
      stream: repo.watchSubscriptions(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());

        final subs = snapshot.data!;

        // Trigger data processing when stream updates
        // Note: calling setState inside build is bad.
        // Better to use a FutureBuilder or just process synchronously if fast.
        // Since getHistory is synchronous in our mock/Hive impl, we can process here.
        // We'll process into a local variable to avoid setState loops.

        final Map<DateTime, List<CalendarEvent>> processedEvents = {};

        for (final sub in subs) {
          // Future
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

          // History
          final history = repo.getHistory(sub.id);
          for (final record in history) {
            final recordDate = DateTime(
              record.date.year,
              record.date.month,
              record.date.day,
            );
            processedEvents
                .putIfAbsent(recordDate, () => [])
                .add(
                  CalendarEvent(
                    title: record.status,
                    amount: record.amount,
                    currency: '฿',
                    date: recordDate,
                    status: record.status, // Paid or Skipped
                    subName: sub.name,
                  ),
                );
          }
        }

        return Scaffold(
          body: Column(
            children: [
              TableCalendar<CalendarEvent>(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                eventLoader: (day) {
                  final normalizedDay = DateTime(day.year, day.month, day.day);
                  return processedEvents[normalizedDay] ?? [];
                },

                // Custom Markers based on status
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, date, events) {
                    if (events.isEmpty) return null;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: events.take(3).map((event) {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1.5),
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _getStatusColor(event.status),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),

                calendarStyle: const CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: Colors.blueAccent,
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: Colors.deepPurple,
                    shape: BoxShape.circle,
                  ),
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
              const SizedBox(height: 8),

              // Event List for Selected Day
              Expanded(
                child: Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: Builder(
                    builder: (context) {
                      final normalizedSelected = DateTime(
                        (_selectedDay ?? _focusedDay).year,
                        (_selectedDay ?? _focusedDay).month,
                        (_selectedDay ?? _focusedDay).day,
                      );
                      final events = processedEvents[normalizedSelected] ?? [];

                      if (events.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                Icons.event_available,
                                size: 48,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No events this day.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: events.length,
                        itemBuilder: (context, index) {
                          final event = events[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: ListTile(
                              leading: Icon(
                                event.status == 'Paid'
                                    ? Icons.check_circle
                                    : event.status == 'Skipped'
                                    ? Icons.remove_circle
                                    : Icons.schedule,
                                color: _getStatusColor(event.status),
                              ),
                              title: Text(
                                event.subName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(event.status),
                              trailing: Text(
                                '${event.currency}${event.amount}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: _getStatusColor(event.status),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
