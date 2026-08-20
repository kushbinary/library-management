with open("lib/screens/main_navigation.dart", "r") as f:
    content = f.read()

# Add import
if "import 'reports_screen.dart';" not in content:
    content = content.replace("import 'settings_screen.dart';", "import 'settings_screen.dart';\nimport 'reports_screen.dart';")

# Replace scaffold with ReportsScreen
old_scaffold = '    const Scaffold(body: Center(child: Text("Reports (Coming Soon)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))),'
new_scaffold = '    const ReportsScreen(),'
content = content.replace(old_scaffold, new_scaffold)

with open("lib/screens/main_navigation.dart", "w") as f:
    f.write(content)
