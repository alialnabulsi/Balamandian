import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MemberListHeader extends StatelessWidget implements PreferredSizeWidget {
  const MemberListHeader({
    super.key,
    required this.discover,
    required this.tabs,
    this.username,
    this.followers,
    this.following,
  });
  final bool discover;
  final TabController tabs;
  final String? username;
  final int? followers, following;
  @override
  Size get preferredSize => Size.fromHeight(discover ? 64 : 120);
  @override
  Widget build(BuildContext context) => AppBar(
    toolbarHeight: discover ? 64 : 72,
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(discover ? 'Discover members' : 'Connections'),
        if (!discover && username != null)
          Text(
            '@$username',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    ),
    bottom: discover
        ? null
        : TabBar(
            controller: tabs,
            tabs: [
              Tab(
                child: Text(
                  'Followers${followers == null ? '' : ' · ${NumberFormat.compact().format(followers)}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Tab(
                child: Text(
                  'Following${following == null ? '' : ' · ${NumberFormat.compact().format(following)}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
  );
}
