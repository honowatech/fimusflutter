class NotificationPreferences {
  final bool notifyDebts;
  final bool notifyContacts;
  final bool notifyJointAccounts;

  NotificationPreferences({
    this.notifyDebts = true,
    this.notifyContacts = true,
    this.notifyJointAccounts = true,
  });

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      notifyDebts: json['notify_debts'] ?? true,
      notifyContacts: json['notify_contacts'] ?? true,
      notifyJointAccounts: json['notify_joint_accounts'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'notify_debts': notifyDebts,
      'notify_contacts': notifyContacts,
      'notify_joint_accounts': notifyJointAccounts,
    };
  }
}
