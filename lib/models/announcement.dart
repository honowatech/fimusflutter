class AnnouncementConfig {
  final int slideDuration;
  final int numberOfSlides;
  final List<AnnouncementSlide> slides;

  AnnouncementConfig({
    required this.slideDuration,
    required this.numberOfSlides,
    required this.slides,
  });

  factory AnnouncementConfig.fromJson(Map<String, dynamic> json) {
    final slidesList = json['slides'] as List? ?? [];
    final parsedSlides = slidesList
        .map((s) => AnnouncementSlide.fromJson(Map<String, dynamic>.from(s)))
        .toList();

    return AnnouncementConfig(
      slideDuration: json['slide_duration'] ?? 3,
      numberOfSlides: json['number_of_slides'] ?? 3,
      slides: parsedSlides,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'slide_duration': slideDuration,
      'number_of_slides': numberOfSlides,
      'slides': slides.map((s) => s.toJson()).toList(),
    };
  }
}

class AnnouncementSlide {
  final String? imageUrl;
  final String? imagePath;
  final String text;

  AnnouncementSlide({
    this.imageUrl,
    this.imagePath,
    required this.text,
  });

  factory AnnouncementSlide.fromJson(Map<String, dynamic> json) {
    return AnnouncementSlide(
      imageUrl: json['image_url'],
      imagePath: json['image_path'],
      text: json['text'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'image_url': imageUrl,
      'image_path': imagePath,
      'text': text,
    };
  }
}
