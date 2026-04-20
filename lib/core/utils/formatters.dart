import 'package:intl/intl.dart';

final NumberFormat copCurrency = NumberFormat.currency(locale: 'es_CO', symbol: r'$');
final NumberFormat copCurrencyCompact = NumberFormat.currency(locale: 'es_CO', symbol: r'$ ', decimalDigits: 0);
final DateFormat dateOnlyFormatter = DateFormat('yyyy-MM-dd');
final DateFormat shortDateFormatter = DateFormat('dd/MM/yyyy');
final DateFormat shortDateTimeFormatter = DateFormat('dd/MM/yyyy HH:mm');
final DateFormat shortTimeFormatter = DateFormat('HH:mm');

String formatDateOnly(DateTime date) => dateOnlyFormatter.format(date);
String formatShortDate(DateTime date) => shortDateFormatter.format(date);
String formatShortDateTime(DateTime date) => shortDateTimeFormatter.format(date);
String formatShortTime(DateTime date) => shortTimeFormatter.format(date);
String formatCopCompact(num value) => copCurrencyCompact.format(value);
