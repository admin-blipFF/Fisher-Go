/// Announcement data model.
class AnnouncementData {
  final String title;
  final String body;
  final int coinReward;

  const AnnouncementData({
    required this.title,
    required this.body,
    required this.coinReward,
  });

  static AnnouncementData get todays => const AnnouncementData(
        title: '🎣 歡迎回來！',
        body: '每日查看公告可獲得金幣獎勵！\n\n圖鑑內有多種香港魚類，等你慢慢發掘。',
        coinReward: 50,
      );
}
