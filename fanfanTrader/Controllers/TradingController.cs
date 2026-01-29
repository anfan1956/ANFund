using fanfanTrader.Models;  // Добавьте эту строку в начале файла
using Microsoft.AspNetCore.Mvc;
using System.Collections.Generic;

namespace fanfanTrader.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class TradingController : ControllerBase
    {
        private static List<Trade> _trades = new List<Trade>
        {
            new Trade { Id = 1, Symbol = "AAPL", Quantity = 10, Price = 175.50m, Side = "BUY", Status = "OPEN" },
            new Trade { Id = 2, Symbol = "MSFT", Quantity = 5, Price = 375.25m, Side = "SELL", Status = "CLOSED" }
        };

        [HttpGet]
        public IActionResult GetTrades()
        {
            return Ok(_trades);
        }

        [HttpGet("{id}")]
        public IActionResult GetTrade(int id)
        {
            var trade = _trades.Find(t => t.Id == id);
            if (trade == null) return NotFound();
            return Ok(trade);
        }

        [HttpPost]
        public IActionResult CreateTrade([FromBody] Trade trade)
        {
            trade.Id = _trades.Count + 1;
            _trades.Add(trade);
            return CreatedAtAction(nameof(GetTrade), new { id = trade.Id }, trade);
        }
    }

    public class Trade
    {
        public int Id { get; set; }
        public string Symbol { get; set; } = string.Empty;
        public decimal Quantity { get; set; }
        public decimal Price { get; set; }
        public string Side { get; set; } = string.Empty;
        public string Status { get; set; } = string.Empty;
    }
}
