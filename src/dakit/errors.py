"""Public exception hierarchy."""


class DeviantArtError(Exception):
    """Base exception raised by the SDK."""


class TransportError(DeviantArtError):
    """The remote service could not be reached."""


class ApiError(DeviantArtError):
    """The service returned an unsuccessful response."""

    def __init__(self, message: str, *, status_code: int | None = None) -> None:
        super().__init__(message)
        self.status_code = status_code


class AuthenticationError(ApiError):
    """Authentication is required or no longer valid."""


class ParseError(ApiError):
    """A payload did not match the expected shape."""


class DownloadError(DeviantArtError):
    """An asset could not be resolved or persisted."""
