namespace Gostio.Model.Responses;

// A created row answers with its own address, and the controller that builds
// that address knows the response only as a type argument.
public interface IIdentified
{
    int Id { get; }
}
