import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:build/src/builder/build_step.dart';
import 'package:logging/logging.dart';
import 'package:source_gen/source_gen.dart';

import 'field_helpers.dart';

final log = Logger('TestingSerializable');

class TestingSerializable {
  const TestingSerializable();
}

Builder testingSerializable(BuilderOptions options) {
  return SharedPartBuilder(
      [DumbTestingGenerator()], 'testing_serializable');
}

/// For every class annotated with TestingSerializable, generate a ${CLASS_NAME}JsonSerializableImpl
/// class that is annotated with JsonSerializable.
class DumbTestingGenerator
    extends GeneratorForAnnotation<TestingSerializable> {
  @override
  generateForAnnotatedElement(
      Element element, ConstantReader annotation, BuildStep buildStep) {
    if (element is! ClassElement) {
      final name = element.name;
      throw InvalidGenerationSourceError('Generator cannot target `$name`.',
          todo: 'Remove the JsonSerializable annotation from `$name`.',
          element: element);
    }

    final classElement = element as ClassElement;
    final helper = _GeneratorHelper(this, classElement, annotation);
    return helper._generate();
  }
}

class _GeneratorHelper {
  final DumbTestingGenerator _generator;
  final ClassElement element;
  final ConstantReader annotation;

  _GeneratorHelper(this._generator,
      this.element,
      this.annotation,);

  String get _className {
    return '_\$${element.name}JsonSerializableHelper';
  }

  Iterable<String> _generate() sync* {
    final sortedFields = createSortedFieldSet(element);

    // Used to keep track of why a field is ignored. Useful for providing
    // helpful errors when generating constructor calls that try to use one of
    // these fields.
    final unavailableReasons = <String, String>{};

    final accessibleFields = sortedFields.fold<Map<String, FieldElement>>(
      <String, FieldElement>{},
      (map, field) {
        if (!field.isPublic) {
          unavailableReasons[field.name] = 'It is assigned to a private field.';
        } else if (field.getter == null) {
          assert(field.setter != null);
          unavailableReasons[field.name] =
              'Setter-only properties are not supported.';
          log.warning('Setters are ignored: ${element.name}.${field.name}');
        }
        /* else if (jsonKeyFor(field).ignore) {
          unavailableReasons[field.name] =
          'It is assigned to an ignored field.';
        }*/
        else {
          assert(!map.containsKey(field.name));
          map[field.name] = field;
        }

        return map;
      },
    );

    yield startOfJsonSerializableHelper(element.name);

    // var accessibleFieldSet = accessibleFields.values.toSet();
    yield* createFields(accessibleFields, unavailableReasons);

    yield createFactory();

    /*
    accessibleFieldSet = accessibleFields.entries
        .where((e) => createResult.usedFields.contains(e.key))
        .map((e) => e.value)
        .toSet();
     */

    // Check for duplicate JSON keys due to colliding annotations.
    // We do this now, since we have a final field list after any pruning done
    // by `_writeCtor`.
    /*
    accessibleFieldSet.fold(
      <String>{},
      (Set<String> set, fe) {
        final jsonKey = nameAccess(fe);
        if (!set.add(jsonKey)) {
          throw InvalidGenerationSourceError(
              'More than one field has the JSON key `$jsonKey`.',
              todo: 'Check the `JsonKey` annotations on fields.',
              element: fe);
        }
        return set;
      },
    );
     */

    yield createToJson();
    yield '}\n';


    // Support of snapshot <-> Model Class, support of DocumentId and ServerTimestamp
    // will be here.
    // yield* createFromTesting(accessibleFieldSet);
    // yield* createToTesting(accessibleFieldSet);
  }

  String startOfJsonSerializableHelper(String name) {
    return '''
@JsonSerializable(explicitToJson: true) // explicitToJson is required by Testing API
class ${_className} {
   ''';
  }

  Iterable<String> createFields(Map<String, FieldElement> accessibleFields,
      Map<String, String> unavailableReasons) sync* {
    for (MapEntry<String, FieldElement> entry in accessibleFields.entries) {
      yield '${entry.value.type.name} ${entry.key};';
    }
  }

  String createFactory() {
    return '  factory ${_className}.fromJson(Map<String, dynamic> data) '
        '    => _\$${_className}FromJson(data);';
  }

  String createToJson() {
    return '  Map<String, dynamic> toJson() '
        '    => _\$${_className}ToJson(this);';
  }
}

class CreateFactoryResult {
  final String output;
  final Set<String> usedFields;

  CreateFactoryResult(this.output, this.usedFields);
}



