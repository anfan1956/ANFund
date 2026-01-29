namespace fanfanTrader.Models
{
    public class Trade
    {
        public int Id { get; set; }
        public string Symbol { get; set; } = string.Empty;
        public decimal Quantity { get; set; }
        public decimal Price { get; set; }
        public string Side { get; set; } = string.Empty;
        public string Status { get; set; } = string.Empty;
        public DateTime Timestamp { get; set; } = DateTime.UtcNow;
        
        // Добавляем эти поля
        public decimal? StopLossPercent { get; set; }
        public decimal? TakeProfitPercent { get; set; }
    }
}