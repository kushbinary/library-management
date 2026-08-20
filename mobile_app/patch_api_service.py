import re

with open('lib/services/api_service.dart', 'r') as f:
    content = f.read()

merge_logic = """
        // Update local cache for this specific user
        // Merge offline added students (IDs > 1000000000000)
        try {
          final raw = prefs.getString(key);
          if (raw != null) {
             final List<dynamic> oldList = json.decode(raw);
             for(var item in oldList) {
               final s = Student.fromJson(item);
               if (s.id != null && s.id! > 1000000000000) {
                 if (!students.any((e) => e.id == s.id)) {
                   students.insert(0, s);
                 }
               }
             }
          }
        } catch (_) {}

        final jsonList = students.map((s) => s.toJson()).toList();
"""

content = content.replace(
    """        // Update local cache for this specific user
        final jsonList = students.map((s) => s.toJson()).toList();""",
    merge_logic
)

with open('lib/services/api_service.dart', 'w') as f:
    f.write(content)
