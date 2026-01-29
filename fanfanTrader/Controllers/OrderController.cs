using Microsoft.AspNetCore.Mvc;
using fanfanTrader.Models;
using Microsoft.EntityFrameworkCore;

namespace fanfanTrader.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class OrderController : ControllerBase
    {
        private readonly ApplicationDbContext _context;
        private readonly ILogger<OrderController> _logger;

        public OrderController(ApplicationDbContext context, ILogger<OrderController> logger)
        {
            _context = context;
            _logger = logger;
        }

        // ТОЛЬКО ОДИН МЕТОД: Принять JSON с данными ордера
        [HttpPost("receive")]
        public async Task<IActionResult> ReceiveOrder([FromBody] Trade orderData)
        {
            try
            {
                // Логируем, что пришло
                _logger.LogInformation($"Received order: {System.Text.Json.JsonSerializer.Serialize(orderData)}");

                // Проверяем обязательные поля
                if (string.IsNullOrEmpty(orderData.Symbol))
                {
                    return BadRequest(new { Success = false, Message = "Symbol is required" });
                }

                // Убеждаемся, что Timestamp текущий
                orderData.Timestamp = DateTime.UtcNow;

                // Если статус не указан, ставим PENDING
                if (string.IsNullOrEmpty(orderData.Status))
                {
                    orderData.Status = "PENDING";
                }

                // Сохраняем в базу
                _context.Trades.Add(orderData);
                await _context.SaveChangesAsync();

                // Отправляем подтверждение
                return Ok(new
                {
                    Success = true,
                    Message = "Order received successfully",
                    OrderId = orderData.Id,
                    ReceivedData = orderData  // Возвращаем то, что получили
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error receiving order");
                return StatusCode(500, new
                {
                    Success = false,
                    Message = $"Error: {ex.Message}"
                });
            }
        }
    }
}