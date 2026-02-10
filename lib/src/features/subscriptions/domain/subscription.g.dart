// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subscription.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SubscriptionAdapter extends TypeAdapter<Subscription> {
  @override
  final int typeId = 4;

  @override
  Subscription read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Subscription(
      id: fields[0] as String,
      name: fields[1] as String,
      categoryId: fields[2] as String,
      price: fields[3] as double,
      currency: fields[4] as String,
      cycle: fields[5] as BillingCycle,
      firstPaymentDate: fields[6] as DateTime,
      nextPaymentDate: fields[7] as DateTime,
      status: fields[8] as String,
      familyMemberId: fields[9] as String?,
      userId: fields[10] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Subscription obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.categoryId)
      ..writeByte(3)
      ..write(obj.price)
      ..writeByte(4)
      ..write(obj.currency)
      ..writeByte(5)
      ..write(obj.cycle)
      ..writeByte(6)
      ..write(obj.firstPaymentDate)
      ..writeByte(7)
      ..write(obj.nextPaymentDate)
      ..writeByte(8)
      ..write(obj.status)
      ..writeByte(9)
      ..write(obj.familyMemberId)
      ..writeByte(10)
      ..write(obj.userId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubscriptionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class BillingCycleAdapter extends TypeAdapter<BillingCycle> {
  @override
  final int typeId = 3;

  @override
  BillingCycle read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return BillingCycle.weekly;
      case 1:
        return BillingCycle.monthly;
      case 2:
        return BillingCycle.yearly;
      default:
        return BillingCycle.weekly;
    }
  }

  @override
  void write(BinaryWriter writer, BillingCycle obj) {
    switch (obj) {
      case BillingCycle.weekly:
        writer.writeByte(0);
        break;
      case BillingCycle.monthly:
        writer.writeByte(1);
        break;
      case BillingCycle.yearly:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BillingCycleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
