namespace StockLab.Services.Implementations
{
    using System.Collections.Concurrent;

    public class ConnectionManager
    {
        // Хранит: UserId -> Время последнего успешного опроса
        // Если пользователя нет в словаре - он офлайн
        private readonly ConcurrentDictionary<int, DateTime> _onlineUsers = new();

        public void UserConnected(int userId)
        {
            // Когда юзер зашел, начинаем искать уведомления с "прямо сейчас"
            _onlineUsers.TryAdd(userId, DateTime.UtcNow);
        }

        public void UserDisconnected(int userId)
        {
            _onlineUsers.TryRemove(userId, out _);
        }

        public IEnumerable<int> GetOnlineUserIds() => _onlineUsers.Keys;

        public DateTime GetLastCheckTime(int userId)
        {
            return _onlineUsers.TryGetValue(userId, out var time) ? time : DateTime.UtcNow;
        }

        public void UpdateLastCheckTime(int userId, DateTime newTime)
        {
            if (_onlineUsers.ContainsKey(userId))
            {
                _onlineUsers[userId] = newTime;
            }
        }
    }
}
