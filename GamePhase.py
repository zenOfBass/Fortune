from dataclasses import dataclass


@dataclass
class GamePhase:
    phases = {"ANTE", "DEALING", "BETTING", "DRAW", "SHOWDOWN", "NULL"}