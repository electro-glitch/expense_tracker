class GroupModel {
  final String id;
  final String name;
  final List<String> members;
  final Map<String, double> balances;

  GroupModel({
    required this.id,
    required this.name,
    required this.members,
    this.balances = const {},
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'members': members,
        'balances': balances,
      };

  factory GroupModel.fromJson(Map<String, dynamic> json) => GroupModel(
        id: json['id'] as String,
        name: json['name'] as String,
        members: List<String>.from(json['members'] ?? []),
        balances: (json['balances'] as Map<String, dynamic>?)?.map(
              (key, value) => MapEntry(key, (value as num).toDouble()),
            ) ??
            {},
      );

  /// Debt Simplification Algorithm
  /// Returns a list of simplified settlements: {from: uid, to: uid, amount: double}
  List<Map<String, dynamic>> getSimplifiedSettlements() {
    List<Map<String, dynamic>> debtors = [];
    List<Map<String, dynamic>> creditors = [];

    // 1. Separate members into debtors and creditors
    balances.forEach((uid, balance) {
      if (balance < -0.01) {
        debtors.add({'uid': uid, 'balance': balance.abs()});
      } else if (balance > 0.01) {
        creditors.add({'uid': uid, 'balance': balance});
      }
    });

    // 2. Sort to process largest amounts first (Greedy approach)
    debtors.sort((a, b) => b['balance'].compareTo(a['balance']));
    creditors.sort((a, b) => b['balance'].compareTo(a['balance']));

    List<Map<String, dynamic>> settlements = [];
    int d = 0;
    int c = 0;

    // 3. Resolve debts
    while (d < debtors.length && c < creditors.length) {
      double amount = debtors[d]['balance'] < creditors[c]['balance'] 
          ? debtors[d]['balance'] 
          : creditors[c]['balance'];

      settlements.add({
        'from': debtors[d]['uid'],
        'to': creditors[c]['uid'],
        'amount': amount,
      });

      debtors[d]['balance'] -= amount;
      creditors[c]['balance'] -= amount;

      if (debtors[d]['balance'] < 0.01) d++;
      if (creditors[c]['balance'] < 0.01) c++;
    }

    return settlements;
  }
}
