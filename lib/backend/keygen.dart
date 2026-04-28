class Generator {
  Future<Map<String, String>> genkey(String key, String password) async {
    if (password.isEmpty) return {"error": "Error: No Password"};

    var map = {
      "trial": await trial(key, password),
      "month1": await month1(key, password),
      "month3": await month3(key, password),
      "month6": await month6(key, password),
      "month12": await month12(key, password),
      "lifetime": await lifetime(key, password),
      // test
    };
    return map;
  }

  // Tier functions: Now they append the expiry date before XORing
  Future<String> trial(String key, String password) async => _applyXor(
    "$key|${_getExpiry(0, 7)}",
    password.codeUnitAt(0),
  ); // 7 Days for trial

  Future<String> month1(String key, String password) async =>
      _applyXor("$key|${_getExpiry(1, 0)}", _getSafeCode(password, 1));

  Future<String> month3(String key, String password) async =>
      _applyXor("$key|${_getExpiry(3, 0)}", _getSafeCode(password, 2));

  Future<String> month6(String key, String password) async =>
      _applyXor("$key|${_getExpiry(6, 0)}", _getSafeCode(password, 3));

  Future<String> month12(String key, String password) async =>
      _applyXor("$key|${_getExpiry(12, 0)}", _getSafeCode(password, 4));

  Future<String> lifetime(String key, String password) async =>
      _applyXor("$key|9999-12-31", _getSafeCode(password, 5));

  // HELPER 1: Date Generator
  String _getExpiry(int months, int days) {
    DateTime now = DateTime.now();
    DateTime expiry = DateTime(now.year, now.month + months, now.day + days);

    // Returns format: YYYY-MM-DD
    return "${expiry.year}-${expiry.month.toString().padLeft(2, '0')}-${expiry.day.toString().padLeft(2, '0')}";
  }

  // HELPER 2: Prevents the RangeError crash
  int _getSafeCode(String p, int index) {
    return p.length > index ? p.codeUnitAt(index) : p.codeUnitAt(p.length - 1);
  }

  // HELPER 3: Performs XOR and converts to READABLE HEX
  String _applyXor(String data, int mask) {
    StringBuffer buffer = StringBuffer();

    for (int i = 0; i < data.length; i++) {
      int charCode = data.codeUnitAt(i) ^ mask;
      buffer.write(charCode.toRadixString(16).padLeft(2, '0').toUpperCase());
    }

    return buffer.toString();
  }
}
