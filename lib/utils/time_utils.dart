import 'package:intl/intl.dart';

String formatTimestamp(DateTime dateTime) {
  return DateFormat('HH:mm').format(dateTime);
}
