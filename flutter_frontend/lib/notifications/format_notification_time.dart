import 'package:cloud_firestore/cloud_firestore.dart';

/// Formats a Firestore timestamp into a human-readable relative time string
/// 
/// Returns:
/// - "Just now" for notifications less than 1 minute old
/// - "Xm ago" for notifications less than 60 minutes old
/// - "Xh ago" for notifications less than 24 hours old
/// - "Yesterday" for notifications from yesterday
/// - "Xd ago" for notifications less than 7 days old
/// - "DD/MM" for older notifications
/// 
/// Usage:
/// ```dart
/// String timeString = formatNotificationTime(notification['time']);
/// // Output: "5m ago" or "2h ago" or "15/01"
/// ```
String formatNotificationTime(dynamic timestamp) {
  if (timestamp == null) return "Just now";
  
  DateTime date;
  
  if (timestamp is Timestamp) {
    date = timestamp.toDate();
  } else if (timestamp is DateTime) {
    date = timestamp;
  } else {
    return "Just now";
  }

  final Duration diff = DateTime.now().difference(date);

  if (diff.inSeconds < 60) {
    return "Just now";
  } else if (diff.inMinutes < 60) {
    return "${diff.inMinutes}m ago";
  } else if (diff.inHours < 24) {
    return "${diff.inHours}h ago";
  } else if (diff.inDays == 1) {
    return "Yesterday";
  } else if (diff.inDays < 7) {
    return "${diff.inDays}d ago";
  } else {
    // Format as DD/MM
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}";
  }
}

/// Formats a timestamp into a full date-time string
/// 
/// Returns: "Jan 15, 2025 at 2:30 PM"
/// 
/// Usage:
/// ```dart
/// String fullTime = formatNotificationFullTime(notification['time']);
/// ```
String formatNotificationFullTime(dynamic timestamp) {
  if (timestamp == null) return "Unknown time";
  
  DateTime date;
  
  if (timestamp is Timestamp) {
    date = timestamp.toDate();
  } else if (timestamp is DateTime) {
    date = timestamp;
  } else {
    return "Unknown time";
  }

  final months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
  final period = date.hour >= 12 ? 'PM' : 'AM';
  final minute = date.minute.toString().padLeft(2, '0');

  return "${months[date.month - 1]} ${date.day}, ${date.year} at $hour:$minute $period";
}

/// Formats a timestamp into date only (no time)
/// 
/// Returns: "January 15, 2025"
/// 
/// Usage:
/// ```dart
/// String dateString = formatNotificationDate(notification['time']);
/// ```
String formatNotificationDate(dynamic timestamp) {
  if (timestamp == null) return "Unknown date";
  
  DateTime date;
  
  if (timestamp is Timestamp) {
    date = timestamp.toDate();
  } else if (timestamp is DateTime) {
    date = timestamp;
  } else {
    return "Unknown date";
  }

  final months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  return "${months[date.month - 1]} ${date.day}, ${date.year}";
}

/// Formats timestamp into time only (no date)
/// 
/// Returns: "2:30 PM"
/// 
/// Usage:
/// ```dart
/// String timeString = formatNotificationTimeOnly(notification['time']);
/// ```
String formatNotificationTimeOnly(dynamic timestamp) {
  if (timestamp == null) return "Unknown time";
  
  DateTime date;
  
  if (timestamp is Timestamp) {
    date = timestamp.toDate();
  } else if (timestamp is DateTime) {
    date = timestamp;
  } else {
    return "Unknown time";
  }

  final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
  final period = date.hour >= 12 ? 'PM' : 'AM';
  final minute = date.minute.toString().padLeft(2, '0');

  return "$hour:$minute $period";
}

/// Formats timestamp with custom relative time ranges
/// 
/// Returns more granular time descriptions
/// 
/// Usage:
/// ```dart
/// String timeString = formatNotificationTimeDetailed(notification['time']);
/// ```
String formatNotificationTimeDetailed(dynamic timestamp) {
  if (timestamp == null) return "Just now";
  
  DateTime date;
  
  if (timestamp is Timestamp) {
    date = timestamp.toDate();
  } else if (timestamp is DateTime) {
    date = timestamp;
  } else {
    return "Just now";
  }

  final Duration diff = DateTime.now().difference(date);

  if (diff.inSeconds < 10) {
    return "Just now";
  } else if (diff.inSeconds < 60) {
    return "${diff.inSeconds} seconds ago";
  } else if (diff.inMinutes == 1) {
    return "1 minute ago";
  } else if (diff.inMinutes < 60) {
    return "${diff.inMinutes} minutes ago";
  } else if (diff.inHours == 1) {
    return "1 hour ago";
  } else if (diff.inHours < 24) {
    return "${diff.inHours} hours ago";
  } else if (diff.inDays == 1) {
    return "Yesterday at ${formatNotificationTimeOnly(timestamp)}";
  } else if (diff.inDays < 7) {
    final days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    return "${days[date.weekday % 7]} at ${formatNotificationTimeOnly(timestamp)}";
  } else {
    return formatNotificationFullTime(timestamp);
  }
}

/// Check if notification is from today
/// 
/// Usage:
/// ```dart
/// if (isNotificationToday(notification['time'])) {
///   // Show special styling
/// }
/// ```
bool isNotificationToday(dynamic timestamp) {
  if (timestamp == null) return false;
  
  DateTime date;
  
  if (timestamp is Timestamp) {
    date = timestamp.toDate();
  } else if (timestamp is DateTime) {
    date = timestamp;
  } else {
    return false;
  }

  final now = DateTime.now();
  return date.year == now.year && 
         date.month == now.month && 
         date.day == now.day;
}

/// Check if notification is recent (within last hour)
/// 
/// Usage:
/// ```dart
/// if (isNotificationRecent(notification['time'])) {
///   // Show "NEW" badge
/// }
/// ```
bool isNotificationRecent(dynamic timestamp) {
  if (timestamp == null) return false;
  
  DateTime date;
  
  if (timestamp is Timestamp) {
    date = timestamp.toDate();
  } else if (timestamp is DateTime) {
    date = timestamp;
  } else {
    return false;
  }

  final Duration diff = DateTime.now().difference(date);
  return diff.inHours < 1;
}

/// Get relative time category for grouping notifications
/// Returns: "today", "yesterday", "this_week", "older"
/// 
/// Usage:
/// ```dart
/// String category = getNotificationTimeCategory(notification['time']);
/// // Use for grouping in ListView sections
/// ```
String getNotificationTimeCategory(dynamic timestamp) {
  if (timestamp == null) return "older";
  
  DateTime date;
  
  if (timestamp is Timestamp) {
    date = timestamp.toDate();
  } else if (timestamp is DateTime) {
    date = timestamp;
  } else {
    return "older";
  }

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final lastWeek = today.subtract(const Duration(days: 7));

  final notifDate = DateTime(date.year, date.month, date.day);

  if (notifDate == today) {
    return "today";
  } else if (notifDate == yesterday) {
    return "yesterday";
  } else if (notifDate.isAfter(lastWeek)) {
    return "this_week";
  } else {
    return "older";
  }
}

/// Format duration since notification was created
/// Returns human-readable duration
/// 
/// Usage:
/// ```dart
/// String duration = formatNotificationAge(notification['time']);
/// // Output: "2 hours and 30 minutes ago"
/// ```
String formatNotificationAge(dynamic timestamp) {
  if (timestamp == null) return "Unknown age";
  
  DateTime date;
  
  if (timestamp is Timestamp) {
    date = timestamp.toDate();
  } else if (timestamp is DateTime) {
    date = timestamp;
  } else {
    return "Unknown age";
  }

  final Duration diff = DateTime.now().difference(date);

  if (diff.inDays > 0) {
    return "${diff.inDays} ${diff.inDays == 1 ? 'day' : 'days'} ago";
  } else if (diff.inHours > 0) {
    final minutes = diff.inMinutes % 60;
    if (minutes > 0) {
      return "${diff.inHours} ${diff.inHours == 1 ? 'hour' : 'hours'} and $minutes ${minutes == 1 ? 'minute' : 'minutes'} ago";
    }
    return "${diff.inHours} ${diff.inHours == 1 ? 'hour' : 'hours'} ago";
  } else if (diff.inMinutes > 0) {
    return "${diff.inMinutes} ${diff.inMinutes == 1 ? 'minute' : 'minutes'} ago";
  } else {
    return "Just now";
  }
}