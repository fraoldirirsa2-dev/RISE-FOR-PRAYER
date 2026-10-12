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
    eth: 'ነግህ ሰዓት',
    en: 'Prime',
    time: '6:00 AM',
    icon: '🌅',
    ge: 'ነግህ',
  ),
  HourData(
    id: 1,
    eth: 'ሠለስት ሰዓት',
    en: 'Terce',
    time: '9:00 AM',
    icon: '☀️',
    ge: 'ሠለስት',
  ),
  HourData(
    id: 2,
    eth: 'ቀትር ሰዓት',
    en: 'Sext',
    time: '12:00 PM',
    icon: '🌞',
    ge: 'ቀትር',
  ),
  HourData(
    id: 3,
    eth: 'ተሰዓት ሰዓት',
    en: 'Nones',
    time: '3:00 PM',
    icon: '🕐',
    ge: 'ተሰዓት',
  ),
  HourData(
    id: 4,
    eth: 'ሠርክ ሰዓት',
    en: 'Vespers',
    time: '5:00 PM',
    icon: '🌇',
    ge: 'ሠርክ',
  ),
  HourData(
    id: 5,
    eth: 'ንዋም ሰዓት',
    en: 'Compline',
    time: '9:00 PM',
    icon: '🌙',
    ge: 'ንዋም',
  ),
  HourData(
    id: 6,
    eth: 'መንፈቀ ሌሊት ሰዓት',
    en: 'Midnight',
    time: '12:00 AM',
    icon: '⭐',
    ge: 'መንፈቀ ሌሊት',
  ),
];
