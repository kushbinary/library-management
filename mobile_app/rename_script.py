import os
import re

directory = 'lib/screens'

for filename in os.listdir(directory):
    if filename.endswith(".dart"):
        filepath = os.path.join(directory, filename)
        with open(filepath, 'r') as f:
            content = f.read()

        # Update imports
        content = content.replace("import '../models/student.dart';", "import '../models/member.dart';")
        content = content.replace("import 'add_student_screen.dart';", "import 'add_member_screen.dart';")
        content = content.replace("import 'members_screen.dart';", "import 'members_list_screen.dart';")
        content = content.replace("import 'package:library_management/models/student.dart';", "import 'package:library_management/models/member.dart';")

        # Update types and variables
        content = content.replace("Student", "Member")
        content = content.replace("student", "member")
        content = content.replace("students", "members")
        content = content.replace("Students", "Members")

        with open(filepath, 'w') as f:
            f.write(content)

