class AppConstants {
  static const String appName = '个人助手';
  static const String backupVersion = '2.0';
  static const String backupEncryption = 'AES-256-GCM';

  static const List<String> defaultCategories = [
    '社交',
    '工作',
    '金融',
    '游戏',
    '开发',
    '购物',
    '其他',
  ];

  static const List<String> wardrobeCategories = [
    '上衣',
    '裤装',
    '裙装',
    '外套',
    '鞋履',
    '配饰',
    '其他',
  ];

  static const List<String> wardrobeSeasons = ['春', '夏', '秋', '冬'];

  static const List<int> autoLockOptions = [0, 1, 5, 10, 30];

  static const Map<int, String> autoLockLabels = {
    0: '立即锁定',
    1: '1 分钟',
    5: '5 分钟',
    10: '10 分钟',
    30: '30 分钟',
  };
}
