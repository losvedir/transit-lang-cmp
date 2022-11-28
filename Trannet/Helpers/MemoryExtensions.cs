namespace Trannet.Helpers;

//The C# runtime doesn't support this yet, being tracked here: https://github.com/dotnet/corefx/issues/26528
//This is the candidate code for the PR https://gist.github.com/bbartels/87c7daae28d4905c60ae77724a401b20

public static partial class MemoryExtensions
{
  public static SpanSplitEnumerator<char> Split(this ReadOnlySpan<char> span)
          => new SpanSplitEnumerator<char>(span, ' ');

  public static SpanSplitEnumerator<char> Split(this ReadOnlySpan<char> span, char separator)
      => new SpanSplitEnumerator<char>(span, separator);
}

public ref struct SpanSplitEnumerator<T> where T : IEquatable<T>
{
  private readonly ReadOnlySpan<T> _sequence;
  private readonly T _separator;
  private int _offset;
  private int _index;

  public SpanSplitEnumerator<T> GetEnumerator() => this;

  internal SpanSplitEnumerator(ReadOnlySpan<T> span, T separator)
  {
    _sequence = span;
    _separator = separator;
    _index = 0;
    _offset = 0;
  }

  public Range Current => new Range(_offset, _offset + _index - 1);

  public ReadOnlySpan<T> CurrentValue => _sequence.Slice(_offset, _index - 1);
  public bool MoveNext()
  {
    if (_sequence.Length - _offset < _index) { return false; }
    var slice = _sequence.Slice(_offset += _index);

    var nextIdx = slice.IndexOf(_separator);
    _index = (nextIdx != -1 ? nextIdx : slice.Length) + 1;
    return true;
  }
}
