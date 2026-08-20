"""Errors exposed by the stable core API."""


class DAKitError(Exception):
    """Base error for the client kernel."""


class TransportError(DAKitError):
    """The remote service could not be reached."""


class RemoteError(DAKitError):
    """A remote endpoint returned an unsuccessful response."""

    def __init__(self, message: str, *, status: int | None = None) -> None:
        super().__init__(message)
        self.status = status


class AuthenticationError(RemoteError):
    """Authorization is missing, expired, or rejected."""


class SchemaChangedError(RemoteError):
    """A remote payload no longer satisfies an adapter contract."""

    def __init__(self, adapter: str, detail: str) -> None:
        super().__init__(f"{adapter} schema changed: {detail}")
        self.adapter = adapter
        self.detail = detail
