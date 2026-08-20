"""Discovery and search APIs."""

from ..models import Artwork, Page
from ..parser import parse_initial_state, parse_page, parse_state_deviations
from ..session import ClientSession


class BrowseService:
    def __init__(self, session: ClientSession) -> None:
        self.session = session

    async def search(
        self, query: str, *, username: str | None = None, cursor: str | None = None, limit: int = 24
    ) -> Page[Artwork]:
        if username:
            token = await self.session.csrf_token(username)
            response = await self.session.request(
                "GET",
                "/_puppy/dashared/gallection/search",
                params={
                    "username": username,
                    "type": "gallery",
                    "q": query,
                    "limit": limit,
                    "offset": cursor or 0,
                    "csrf_token": token,
                },
            )
            return parse_page(response.json())
        response = await self.session.request("GET", "/search", params={"q": query})
        return Page(parse_state_deviations(parse_initial_state(response.text))[:limit])
