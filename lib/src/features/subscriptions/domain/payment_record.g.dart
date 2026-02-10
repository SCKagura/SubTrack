// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PaymentRecordAdapter extends TypeAdapter<PaymentRecord> {
  @override
  final int typeId = 2;

  @override
  PaymentRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PaymentRecord(
      id: fields[0] as String,
      subscriptionId: fields[1] as String,
      date: fields[2] as DateTime,
      amount: fields[3] as double,
      status: fields[4] as String,
      note: fields[5] as String?,
      userId: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, PaymentRecord obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.subscriptionId)
      ..writeByte(2)
      ..write(obj.date)
      ..writeByte(3)
      ..write(obj.amount)
      ..writeByte(4)
      ..write(obj.status)
      ..writeByte(5)
      ..write(obj.note)
      ..writeByte(6)
      ..write(obj.userId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaymentRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
