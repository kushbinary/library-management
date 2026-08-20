with open("lib/screens/dashboard_screen.dart", "r") as f:
    content = f.read()

import re

# find the gesture detector that opens the modal
start_idx = content.find("GestureDetector(")
end_idx = content.find("           ],", start_idx)

if start_idx == -1 or end_idx == -1:
    print("Could not find bounds")
    exit(1)

new_code = """GestureDetector(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: const Color(0xFFF4F7F6),
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                  builder: (ctx) => Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Choose Avatar', style: TextStyle(color: Color(0xFF333333), fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 20),
                        const Text('Male Profiles', style: TextStyle(color: Color(0xFF555555), fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: _maleAvatars.map((url) => _buildAvatarCard(url, true, 'Admin', 'Male Profile', ctx)).toList(),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text('Female Profiles', style: TextStyle(color: Color(0xFF555555), fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: _femaleAvatars.map((url) => _buildAvatarCard(url, false, 'Admin', 'Female Profile', ctx)).toList(),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                );
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF818CF8), width: 2),
                  image: DecorationImage(
                    image: NetworkImage(_avatarUrl),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
"""

replaced = content[:start_idx] + new_code + content[end_idx:]

card_code = """
  Widget _buildAvatarCard(String url, bool isMale, String title, String subtitle, BuildContext ctx) {
    return GestureDetector(
      onTap: () {
        _setAvatar(url);
        Navigator.pop(ctx);
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 15, bottom: 15, left: 5, top: 5),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
          border: _avatarUrl == url ? Border.all(color: isMale ? const Color(0xFF007bff) : const Color(0xFFe83e8c), width: 2) : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isMale ? const Color(0xFF007bff) : const Color(0xFFe83e8c),
                  width: 3,
                ),
                color: const Color(0xFFeef2f3),
                image: DecorationImage(
                  image: NetworkImage(url),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(color: Color(0xFF333333), fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: Color(0xFF777777), fontSize: 12)),
          ],
        ),
      ),
    );
  }

}
"""

replaced = replaced.replace("}\n", card_code, 1) if replaced.endswith("}\n") else replaced.rstrip()[:-1] + card_code

with open("lib/screens/dashboard_screen.dart", "w") as f:
    f.write(replaced)
