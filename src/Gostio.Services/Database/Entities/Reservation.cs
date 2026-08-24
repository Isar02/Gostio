namespace Gostio.Services.Database.Entities;

public class Reservation
{
    public int Id { get; set; }

    public int UserId { get; set; }

    public User User { get; set; } = null!;

    public int? AccommodationId { get; set; }

    public Accommodation? Accommodation { get; set; }

    public int? ExperienceSlotId { get; set; }

    public ExperienceSlot? ExperienceSlot { get; set; }

    public DateOnly? CheckInDate { get; set; }

    public DateOnly? CheckOutDate { get; set; }

    public int GuestCount { get; set; }

    public int ReservationStatusId { get; set; }

    public ReservationStatus ReservationStatus { get; set; } = null!;

    public DateTime ExpiresAt { get; set; }

    public decimal? AccommodationTotal { get; set; }

    public decimal? CleaningFee { get; set; }

    public decimal? PricePerPerson { get; set; }

    public decimal TotalPrice { get; set; }

    public DateTime CreatedAt { get; set; }

    public ICollection<ReservationStatusHistory> StatusHistory { get; set; } = [];

    public ICollection<Payment> Payments { get; set; } = [];
}
