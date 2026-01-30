// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tile_image.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TileImageAdapter extends TypeAdapter<TileImage> {
  @override
  final int typeId = 0;

  @override
  TileImage read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TileImage(
      id: fields[0] as String,
      path: fields[1] as String,
      r: fields[2] as int,
      g: fields[3] as int,
      b: fields[4] as int,
    );
  }

  @override
  void write(BinaryWriter writer, TileImage obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.path)
      ..writeByte(2)
      ..write(obj.r)
      ..writeByte(3)
      ..write(obj.g)
      ..writeByte(4)
      ..write(obj.b);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TileImageAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
