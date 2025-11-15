enum UserRole {
  official('Official'),
  vendor('Vendor'),
  resident('Resident');

  const UserRole(this.displayName);
  final String displayName;
}

