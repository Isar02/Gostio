using Gostio.Model.Enums;
using Gostio.Model.Exceptions;
using Gostio.Services.Reservations;

namespace Gostio.Tests.Reservations;

public class ReservationStateMachineTests
{
    private static readonly ReservationStatusCode[] Statuses =
        Enum.GetValues<ReservationStatusCode>();

    private static readonly (ReservationStatusCode From, ReservationStatusCode To)[] TheFourMoves =
    [
        (ReservationStatusCode.Pending, ReservationStatusCode.Confirmed),
        (ReservationStatusCode.Pending, ReservationStatusCode.Cancelled),
        (ReservationStatusCode.Confirmed, ReservationStatusCode.Cancelled),
        (ReservationStatusCode.Confirmed, ReservationStatusCode.Completed),
    ];

    [Fact]
    public void TheFourMovesAreTheOnlyOnesAllowed()
    {
        var allowed =
            from origin in Statuses
            from target in Statuses
            where ReservationStateMachine.IsAllowed(origin, target)
            select (From: origin, To: target);

        Assert.Equal(TheFourMoves.Order(), allowed.Order());
    }

    [Theory]
    [InlineData(ReservationStatusCode.Cancelled)]
    [InlineData(ReservationStatusCode.Completed)]
    public void ATerminalStatusLeadsNowhere(ReservationStatusCode terminal)
    {
        Assert.All(
            Statuses,
            target => Assert.False(ReservationStateMachine.IsAllowed(terminal, target)));
    }

    [Fact]
    public void AStatusNeverMovesToItself()
    {
        Assert.All(
            Statuses,
            status => Assert.False(ReservationStateMachine.IsAllowed(status, status)));
    }

    [Fact]
    public void APendingReservationIsNeverCompletedWithoutBeingConfirmed() =>
        Assert.False(ReservationStateMachine.IsAllowed(
            ReservationStatusCode.Pending, ReservationStatusCode.Completed));

    [Fact]
    public void AConfirmedReservationNeverGoesBackToAHold() =>
        Assert.False(ReservationStateMachine.IsAllowed(
            ReservationStatusCode.Confirmed, ReservationStatusCode.Pending));

    [Fact]
    public void ARefusedMoveNamesBothStatuses()
    {
        var refused = Assert.Throws<BusinessException>(() => ReservationStateMachine.RequireAllowed(
            ReservationStatusCode.Cancelled, ReservationStatusCode.Confirmed));

        Assert.Contains("Cancelled", refused.Message);
        Assert.Contains("Confirmed", refused.Message);
    }

    [Fact]
    public void AnAllowedMovePassesSilently() => ReservationStateMachine.RequireAllowed(
        ReservationStatusCode.Pending, ReservationStatusCode.Confirmed);

    [Fact]
    public void ANewReservationStartsPending() =>
        Assert.Equal(ReservationStatusCode.Pending, ReservationStateMachine.Created);

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData("\t\r\n ")]
    public void ACancellationWithoutWordsIsRefused(string? reason) =>
        Assert.Throws<ValidationException>(() => ReservationStateMachine.RequireReason(
            ReservationStatusCode.Cancelled, reason));

    [Fact]
    public void ACancellationKeepsItsReasonTrimmed() => Assert.Equal(
        "The guest asked for it",
        ReservationStateMachine.RequireReason(
            ReservationStatusCode.Cancelled, "  The guest asked for it \n"));

    [Theory]
    [InlineData(ReservationStatusCode.Confirmed)]
    [InlineData(ReservationStatusCode.Completed)]
    public void EveryOtherMoveMayCarryNoReason(ReservationStatusCode target) =>
        Assert.Null(ReservationStateMachine.RequireReason(target, null));

    [Fact]
    public void ABlankReasonIsStoredAsNothingRatherThanAsSpaces() => Assert.Null(
        ReservationStateMachine.RequireReason(ReservationStatusCode.Confirmed, "   "));

    [Fact]
    public void AReasonGivenWhereNoneIsNeededIsKept() => Assert.Equal(
        "The payment cleared",
        ReservationStateMachine.RequireReason(
            ReservationStatusCode.Confirmed, " The payment cleared "));

    [Theory]
    [InlineData(1, ReservationStatusCode.Pending)]
    [InlineData(2, ReservationStatusCode.Confirmed)]
    [InlineData(3, ReservationStatusCode.Cancelled)]
    [InlineData(4, ReservationStatusCode.Completed)]
    public void TheSeededIdsAreTheOnesTheMachineReads(int id, ReservationStatusCode expected) =>
        Assert.Equal(expected, ReservationStateMachine.RequireKnown(id));

    [Theory]
    [InlineData(0)]
    [InlineData(5)]
    [InlineData(-1)]
    public void AStatusAnAdministratorAddedIsNotOneTheMachineMovesBetween(int id) =>
        Assert.Throws<BusinessException>(() => ReservationStateMachine.RequireKnown(id));
}
