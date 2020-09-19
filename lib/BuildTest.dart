import 'package:testing_serializable/testing_serializable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'BuildTest.g.dart';

@TestingSerializable()
class Value {
  int a;
  String b;

  Value({this.a, this.b});
}
