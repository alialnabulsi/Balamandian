import 'community.dart';
import 'profile_models.dart';

class AcademicSpace {
  AcademicSpace(CommunityJson json)
    : id = json['id'] as String,
      title = json['title'] as String,
      kind = json['kind'] as String,
      description = json['description'] as String,
      department = json['affiliation'] as String?,
      courseCode = json['courseCode'] as String?,
      courseName = json['courseName'] as String?,
      memberCount = json['memberCount'] as int,
      joined = json['joined'] == true,
      canJoin = json['canJoin'] == true,
      image = json['image'] == null
          ? null
          : CommunityImage.fromJson(json['image'] as CommunityJson);
  final String id, title, description, kind;
  final String? department, courseCode, courseName;
  final int memberCount;
  final bool joined, canJoin;
  final CommunityImage? image;
  bool get official => kind == 'channel';
  String get affiliation =>
      official ? department ?? '' : '$courseCode · $courseName';
}

class AcademicCourse {
  AcademicCourse(CommunityJson json)
    : code = json['code'] as String,
      name = json['name'] as String,
      department = json['department'] as String;
  final String code, name, department;
}

class AcademicItem {
  AcademicItem(CommunityJson json)
    : id = json['id'] as String,
      kind = json['kind'] as String,
      title = json['title'] as String,
      body = json['body'] as String,
      mine = json['mine'] == true,
      pinned = json['pinned'] == true,
      reminded = json['reminded'] == true,
      filename = json['filename'] as String?,
      mime = json['mime'] as String?,
      location = json['location'] as String?,
      resolvedId = json['resolvedId'] as String?,
      startsAt = DateTime.tryParse(json['startsAt']?.toString() ?? '')
          ?.toLocal(),
      published = DateTime.parse(json['createdAt'] as String).toLocal(),
      fileSize = json['fileSize'] as int?,
      answerCount = json['answerCount'] as int,
      author = json['author'] == null
          ? null
          : PublicUserIdentity.fromJson(json['author']);
  final String id, kind, title, body;
  final String? filename, mime, location, resolvedId;
  final DateTime? startsAt;
  final DateTime published;
  final bool mine, pinned, reminded;
  final int? fileSize;
  final int answerCount;
  final PublicUserIdentity? author;
}
