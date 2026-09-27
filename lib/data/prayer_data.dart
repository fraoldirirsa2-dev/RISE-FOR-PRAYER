import 'package:rise_for_prayer/models/hour_data.dart';

const ethMonths = [
  'መስከረም',
  'ጥቅምት',
  'ህዳር',
  'ታህሳስ',
  'ጥር',
  'የካቲት',
  'መጋቢት',
  'ሚያዝያ',
  'ግንቦት',
  'ሰኔ',
  'ሐምሌ',
  'ነሐሴ',
  'ጳጉሜ',
];

const ethMonthsEnglish = [
  'Meskerem',
  'Tikimt',
  'Hidar',
  'Tahsas',
  'Tir',
  'Yekatit',
  'Megabit',
  'Miazia',
  'Ginbot',
  'Sene',
  'Hamle',
  'Nehase',
  'Pagume',
];

const weekEth = ['እሁ', 'ሰኞ', 'ማክ', 'ረቡ', 'ሐሙ', 'አርብ', 'ቅዳ'];
const weekGreg = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

const hours = [
  HourData(
    id: 0,
    eth: 'ቀዳሚት ሰዓት',
    en: 'Prime',
    time: '6:00 AM',
    icon: '🌅',
    ge: 'ቀዳሚት',
  ),
  HourData(
    id: 1,
    eth: 'ሦስተኛ ሰዓት',
    en: 'Terce',
    time: '9:00 AM',
    icon: '☀️',
    ge: 'ሦስተኛ',
  ),
  HourData(
    id: 2,
    eth: 'ስድስተኛ ሰዓት',
    en: 'Sext',
    time: '12:00 PM',
    icon: '🌞',
    ge: 'ስድስተኛ',
  ),
  HourData(
    id: 3,
    eth: 'ዘጠነኛ ሰዓት',
    en: 'Nones',
    time: '3:00 PM',
    icon: '🕐',
    ge: 'ዘጠነኛ',
  ),
  HourData(
    id: 4,
    eth: 'ምሽት ሰዓት',
    en: 'Vespers',
    time: '6:00 PM',
    icon: '🌇',
    ge: 'ምሽት',
  ),
  HourData(
    id: 5,
    eth: 'ሌሊት ሰዓት',
    en: 'Compline',
    time: '9:00 PM',
    icon: '🌙',
    ge: 'ሌሊት',
  ),
  HourData(
    id: 6,
    eth: 'እኩለ ሌሊት ሰዓት',
    en: 'Midnight',
    time: '12:00 AM',
    icon: '⭐',
    ge: 'እኩለ ሌሊት',
  ),
];
