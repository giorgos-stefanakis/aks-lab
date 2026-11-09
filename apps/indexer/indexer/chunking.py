"""Mock document chunking."""


def split_text(text: str, size: int, overlap: int) -> list[str]:
    """Split text into fixed-size chunks that overlap.

    Args:
        text: Document text.
        size: Maximum characters per chunk. Must be positive.
        overlap: Characters shared by neighbouring chunks. Must be smaller than size.

    Returns:
        The chunks in order. Empty when the text is empty.

    Raises:
        ValueError: If size or overlap is out of range.
    """
    if size <= 0 or not 0 <= overlap < size:
        raise ValueError("size must be positive and overlap must be in [0, size)")
    step = size - overlap
    chunks = []
    start = 0
    while start < len(text):
        chunks.append(text[start : start + size])
        if start + size >= len(text):
            break
        start += step
    return chunks
