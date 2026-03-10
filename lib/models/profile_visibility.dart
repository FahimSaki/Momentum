class ProfileVisibility {
  final bool showEmail;
  final bool showName;
  final bool showBio;

  ProfileVisibility({
    this.showEmail = false,
    this.showName = true,
    this.showBio = true,
  });

  factory ProfileVisibility.fromJson(Map json) {
    return ProfileVisibility(
      showEmail: json['showEmail'] ?? false,
      showName: json['showName'] ?? true,
      showBio: json['showBio'] ?? true,
    );
  }

  Map toJson() {
    return {'showEmail': showEmail, 'showName': showName, 'showBio': showBio};
  }
}
