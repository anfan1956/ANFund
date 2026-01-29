using Microsoft.EntityFrameworkCore;
using fanfanTrader.Models;

namespace fanfanTrader.Data
{
    public class ApplicationDbContext : DbContext
    {
        public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options)
            : base(options)
        {
        }

        public DbSet<Trade> Trades { get; set; }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);
            
            // Конфигурация для Trade
            modelBuilder.Entity<Trade>(entity =>
            {
                entity.HasKey(e => e.Id);
                entity.Property(e => e.Symbol).IsRequired().HasMaxLength(10);
                entity.Property(e => e.Quantity).HasColumnType("decimal(18,2)");
                entity.Property(e => e.Price).HasColumnType("decimal(18,2)");
                entity.Property(e => e.Side).HasMaxLength(10);
                entity.Property(e => e.Status).HasMaxLength(20);
                entity.Property(e => e.Timestamp).HasDefaultValueSql("GETUTCDATE()");
            });
        }
    }
}
