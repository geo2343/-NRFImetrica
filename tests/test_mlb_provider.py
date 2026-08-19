import unittest

from providers.mlb import normalize_schedule


class MLBProviderTest(unittest.TestCase):
    def test_normalizes_pregame_schedule(self):
        raw = {
            "dates": [{
                "games": [{
                    "gamePk": 123,
                    "gameDate": "2026-08-19T23:10:00Z",
                    "status": {"abstractGameState": "Preview", "detailedState": "Scheduled", "codedGameState": "S"},
                    "venue": {"name": "Example Park"},
                    "teams": {
                        "away": {"team": {"name": "Away"}, "probablePitcher": {"id": 1, "fullName": "Away SP"}},
                        "home": {"team": {"name": "Home"}, "probablePitcher": {"id": 2, "fullName": "Home SP"}},
                    },
                }]
            }]
        }
        games = normalize_schedule(raw, cutoff_minutes_before=5)
        self.assertEqual(len(games), 1)
        self.assertEqual(games[0]["game_id"], "123")
        self.assertEqual(games[0]["status"], "READY")
        self.assertEqual(games[0]["probable_pitchers"]["away"]["name"], "Away SP")
        self.assertTrue(games[0]["cutoff_at"].endswith("+00:00"))

    def test_live_game_is_audit_only(self):
        raw = {
            "dates": [{
                "games": [{
                    "gamePk": 456,
                    "gameDate": "2026-08-19T18:00:00Z",
                    "status": {"abstractGameState": "Live", "detailedState": "In Progress"},
                    "teams": {"away": {"team": {"name": "A"}}, "home": {"team": {"name": "B"}}},
                }]
            }]
        }
        self.assertEqual(normalize_schedule(raw)[0]["status"], "AUDIT_ONLY")


if __name__ == "__main__":
    unittest.main()
