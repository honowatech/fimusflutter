import 'dart:convert';

void main() {
  // Simulate decoding JSON, which often results in List<dynamic> containing _Map<String, dynamic>
  String jsonStr = '[{"name": "Cameroun", "code": "CM"}, {"name": "Sénégal", "code": "SN"}]';
  var decoded = json.decode(jsonStr) as List<dynamic>;
  
  try {
    var list1 = List<Map<String, dynamic>>.from(decoded);
    print("List.from success: $list1");
  } catch (e) {
    print("List.from failed: $e");
  }

  // What if the map has dynamic keys/values?
  var dynamicMapList = <dynamic>[
    <dynamic, dynamic>{'name': 'Cameroun', 'code': 'CM'},
    <dynamic, dynamic>{'name': 'Sénégal', 'code': 'SN'},
  ];
  try {
    var list2 = List<Map<String, dynamic>>.from(dynamicMapList);
    print("List.from with dynamic keys success: $list2");
  } catch (e) {
    print("List.from with dynamic keys failed: $e");
  }

  try {
    var list3 = dynamicMapList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    print("Safe conversion success: $list3");
  } catch (e) {
    print("Safe conversion failed: $e");
  }
}
