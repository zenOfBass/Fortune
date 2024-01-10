from __future__ import annotations
from abc import ABC, abstractmethod


class Subject(ABC):
    @abstractmethod
    def Attach(self, observer: Observer) -> None:
        pass

    @abstractmethod
    def Detach(self, observer: Observer) -> None:
        pass

    @abstractmethod
    def Notify(self) -> None:
        pass

class Observer(ABC):
    @abstractmethod
    def Update(self, gamePhase: str) -> None:
        pass