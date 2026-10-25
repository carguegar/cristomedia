import 'content.dart';
import 'review.dart';
import 'associated_user.dart';

class ContentDetail {
  final Content content;
  final List<Review> reviews;
  final List<AssociatedUser> associatedUsers;

  ContentDetail({
    required this.content,
    required this.reviews,
    required this.associatedUsers,
  });
}
