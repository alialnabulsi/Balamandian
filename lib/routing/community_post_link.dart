const communityPostLinkParameter = 'post';

final _communityPostPath = RegExp(
  r'^/posts/[a-fA-F0-9]{8}(?:-[a-fA-F0-9]{4}){3}-[a-fA-F0-9]{12}$',
);

String? communityPostPath(String? path) =>
    path != null && _communityPostPath.hasMatch(path) ? path : null;
